import 'dart:async';

import 'package:dio/dio.dart';

typedef SegmentFetcher = Future<List<int>> Function(
  SegmentDownloadRequest request,
);

typedef SegmentExists = Future<bool> Function(int index);
typedef SegmentWriter = Future<void> Function(int index, List<int> bytes);
typedef SegmentProgress = FutureOr<void> Function(int completedSegments);

class SegmentDownloadRequest {
  final int index;
  final String url;
  final String? referer;
  final CancelToken cancelToken;

  const SegmentDownloadRequest({
    required this.index,
    required this.url,
    required this.referer,
    required this.cancelToken,
  });
}

class SegmentDownloadResult {
  final int index;
  final int attempts;
  final bool skipped;

  const SegmentDownloadResult({
    required this.index,
    required this.attempts,
    required this.skipped,
  });
}

class SegmentDownloadException implements Exception {
  final int index;
  final String url;
  final int attempts;
  final Object cause;
  final StackTrace stackTrace;

  const SegmentDownloadException({
    required this.index,
    required this.url,
    required this.attempts,
    required this.cause,
    required this.stackTrace,
  });

  int get retries => attempts <= 0 ? 0 : attempts - 1;

  String get userMessage =>
      'segment ${index + 1} failed after $retries retries: ${_describe(cause)}';

  static String _describe(Object cause) {
    if (cause is DioException) {
      return switch (cause.type) {
        DioExceptionType.connectionTimeout => 'connection timeout',
        DioExceptionType.sendTimeout => 'send timeout',
        DioExceptionType.receiveTimeout => 'receive timeout',
        DioExceptionType.badCertificate => 'bad certificate',
        DioExceptionType.badResponse =>
          'bad response ${cause.response?.statusCode ?? ''}'.trim(),
        DioExceptionType.cancel => 'request cancelled',
        DioExceptionType.connectionError => 'connection error',
        DioExceptionType.unknown => cause.message ?? 'network error',
        _ => cause.message ?? 'network error',
      };
    }
    return cause.toString();
  }

  @override
  String toString() => userMessage;
}

class DownloadSegmentDownloader {
  final SegmentFetcher fetcher;
  final Duration retryDelay;

  const DownloadSegmentDownloader({
    required this.fetcher,
    this.retryDelay = const Duration(milliseconds: 300),
  });

  Future<List<SegmentDownloadResult>> downloadAll({
    required List<String> urls,
    required String? referer,
    required CancelToken cancelToken,
    required int concurrency,
    required int retries,
    required SegmentExists exists,
    required SegmentWriter write,
    SegmentProgress? onProgress,
  }) async {
    if (urls.isEmpty) return const [];

    final safeConcurrency = concurrency.clamp(1, urls.length).toInt();
    final safeRetries = retries.clamp(0, 5).toInt();
    final completed = <int>{};
    final missing = <int>[];
    final results = <SegmentDownloadResult>[];

    for (var index = 0; index < urls.length; index++) {
      if (cancelToken.isCancelled) return results;
      if (await exists(index)) {
        completed.add(index);
        results.add(
          SegmentDownloadResult(index: index, attempts: 0, skipped: true),
        );
        await onProgress?.call(completed.length);
      } else {
        missing.add(index);
      }
    }

    var cursor = 0;
    final workers = List.generate(safeConcurrency, (_) async {
      while (!cancelToken.isCancelled) {
        final queueIndex = cursor++;
        if (queueIndex >= missing.length) break;

        final index = missing[queueIndex];
        final attempts = await _fetchWriteWithRetry(
          index: index,
          url: urls[index],
          referer: referer,
          cancelToken: cancelToken,
          retries: safeRetries,
          write: write,
        );
        if (cancelToken.isCancelled) break;
        completed.add(index);
        results.add(
          SegmentDownloadResult(
            index: index,
            attempts: attempts,
            skipped: false,
          ),
        );
        await onProgress?.call(completed.length);
      }
    });

    await Future.wait(workers);
    results.sort((a, b) => a.index.compareTo(b.index));
    return results;
  }

  Future<int> _fetchWriteWithRetry({
    required int index,
    required String url,
    required String? referer,
    required CancelToken cancelToken,
    required int retries,
    required SegmentWriter write,
  }) async {
    var attempts = 0;
    while (true) {
      attempts++;
      try {
        final bytes = await fetcher(
          SegmentDownloadRequest(
            index: index,
            url: url,
            referer: referer,
            cancelToken: cancelToken,
          ),
        );
        if (cancelToken.isCancelled) return attempts;
        await write(index, bytes);
        return attempts;
      } catch (error, stackTrace) {
        if (_isCancellation(error) || cancelToken.isCancelled) rethrow;
        if (attempts > retries) {
          throw SegmentDownloadException(
            index: index,
            url: url,
            attempts: attempts,
            cause: error,
            stackTrace: stackTrace,
          );
        }
        final delay = Duration(
          milliseconds: retryDelay.inMilliseconds * attempts,
        );
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }
  }

  bool _isCancellation(Object error) {
    return error is DioException && error.type == DioExceptionType.cancel;
  }
}
