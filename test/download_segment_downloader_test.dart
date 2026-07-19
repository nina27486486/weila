import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/download/segment_downloader.dart';

void main() {
  test('retries a failed segment before writing it', () async {
    var attempts = 0;
    final writes = <int, List<int>>{};
    final downloader = DownloadSegmentDownloader(
      retryDelay: Duration.zero,
      fetcher: (request) async {
        attempts++;
        if (attempts < 3) {
          throw DioException(
            requestOptions: RequestOptions(path: request.url),
            type: DioExceptionType.connectionError,
          );
        }
        return [request.index, 7];
      },
    );

    final results = await downloader.downloadAll(
      urls: const ['https://cdn.example.com/seg-0.ts'],
      referer: 'https://example.com/',
      cancelToken: CancelToken(),
      concurrency: 1,
      retries: 2,
      exists: (_) async => false,
      write: (index, bytes) async => writes[index] = bytes,
    );

    expect(attempts, 3);
    expect(writes, {
      0: [0, 7],
    });
    expect(results.single.attempts, 3);
  });

  test('limits in-flight segment requests to configured concurrency', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final downloader = DownloadSegmentDownloader(
      retryDelay: Duration.zero,
      fetcher: (request) async {
        inFlight++;
        maxInFlight = maxInFlight < inFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        inFlight--;
        return [request.index];
      },
    );

    await downloader.downloadAll(
      urls: List.generate(8, (index) => 'https://cdn.example.com/$index.ts'),
      referer: null,
      cancelToken: CancelToken(),
      concurrency: 2,
      retries: 0,
      exists: (_) async => false,
      write: (_, __) async {},
    );

    expect(maxInFlight, 2);
  });

  test('reports the failed segment and retry count when all attempts fail',
      () async {
    final downloader = DownloadSegmentDownloader(
      retryDelay: Duration.zero,
      fetcher: (request) async {
        throw DioException(
          requestOptions: RequestOptions(path: request.url),
          type: DioExceptionType.receiveTimeout,
        );
      },
    );

    await expectLater(
      downloader.downloadAll(
        urls: const ['https://cdn.example.com/seg-7.ts'],
        referer: null,
        cancelToken: CancelToken(),
        concurrency: 1,
        retries: 3,
        exists: (_) async => false,
        write: (_, __) async {},
      ),
      throwsA(
        isA<SegmentDownloadException>()
            .having((error) => error.index, 'index', 0)
            .having((error) => error.attempts, 'attempts', 4)
            .having(
              (error) => error.userMessage,
              'userMessage',
              contains('segment 1'),
            ),
      ),
    );
  });
}
