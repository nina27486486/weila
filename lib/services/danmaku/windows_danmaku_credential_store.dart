import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:win32/win32.dart';

import 'danmaku_credential_store.dart';
import 'dandanplay_credentials.dart';

class WindowsDanmakuCredentialStore implements DanmakuCredentialStore {
  WindowsDanmakuCredentialStore({
    this.targetName = defaultTargetName,
  });

  static const defaultTargetName = 'Weila/Dandanplay';
  static const _maximumCredentialBlobSize = 512;

  final String targetName;

  @override
  Future<DandanplayCredentials?> read() async {
    _requireWindows();
    final heap = _processHeap();
    final target = targetName.toPcwstr();
    final output = _allocate<Pointer<CREDENTIAL>>(
      heap,
      sizeOf<Pointer<CREDENTIAL>>(),
    );
    try {
      final result = CredRead(target, CRED_TYPE_GENERIC, output);
      if (!result.value) {
        if (result.error == ERROR_NOT_FOUND) return null;
        throw WindowsException(result.error.toHRESULT());
      }

      final pointer = output.value;
      if (pointer.isNull) {
        throw StateError('Windows 凭据读取成功但未返回数据。');
      }
      try {
        final credential = pointer.ref;
        final secret = utf8.decode(
          credential.CredentialBlob.asTypedList(
            credential.CredentialBlobSize,
          ),
        );
        final credentials = DandanplayCredentials(
          appId: credential.UserName.toDartString(),
          appSecret: secret,
        );
        return credentials.isValid ? credentials : null;
      } finally {
        CredFree(pointer);
      }
    } finally {
      free(target);
      _release(heap, output);
    }
  }

  @override
  Future<void> write(DandanplayCredentials credentials) async {
    _requireWindows();
    if (!credentials.isValid) {
      throw ArgumentError('弹弹play AppId 与 AppSecret 均不能为空。');
    }

    final secretBytes = utf8.encode(credentials.appSecret);
    if (secretBytes.length > _maximumCredentialBlobSize) {
      throw ArgumentError('弹弹play AppSecret 超出 Windows 凭据长度限制。');
    }

    final heap = _processHeap();
    final target = targetName.toPwstr();
    final username = credentials.appId.toPwstr();
    final secret = Uint8List.fromList(secretBytes).toNative();
    final credential = _allocate<CREDENTIAL>(heap, sizeOf<CREDENTIAL>());
    try {
      credential.ref
        ..Type = CRED_TYPE_GENERIC
        ..TargetName = target
        ..Persist = CRED_PERSIST_LOCAL_MACHINE
        ..UserName = username
        ..CredentialBlob = secret
        ..CredentialBlobSize = secretBytes.length;
      final result = CredWrite(credential, 0);
      if (!result.value) {
        throw WindowsException(result.error.toHRESULT());
      }
    } finally {
      free(target);
      free(username);
      free(secret);
      _release(heap, credential);
    }
  }

  @override
  Future<void> clear() async {
    _requireWindows();
    final target = targetName.toPcwstr();
    try {
      final result = CredDelete(target, CRED_TYPE_GENERIC);
      if (!result.value && result.error != ERROR_NOT_FOUND) {
        throw WindowsException(result.error.toHRESULT());
      }
    } finally {
      free(target);
    }
  }

  static void _requireWindows() {
    if (!Platform.isWindows) {
      throw UnsupportedError('弹弹play安全凭据仅支持 Windows。');
    }
  }

  static HANDLE _processHeap() {
    final result = GetProcessHeap();
    if (result.value.isNull) {
      throw WindowsException(result.error.toHRESULT());
    }
    return result.value;
  }

  static Pointer<T> _allocate<T extends NativeType>(
    HANDLE heap,
    int size,
  ) {
    final pointer = HeapAlloc(heap, HEAP_ZERO_MEMORY, size).cast<T>();
    if (pointer.isNull) {
      throw StateError('无法分配 Windows 凭据所需内存。');
    }
    return pointer;
  }

  static void _release(HANDLE heap, Pointer pointer) {
    final result = HeapFree(heap, HEAP_FLAGS(0), pointer);
    if (!result.value) {
      throw WindowsException(result.error.toHRESULT());
    }
  }
}
