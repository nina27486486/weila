import 'package:flutter/foundation.dart';

const bool _requestedByDefine = bool.fromEnvironment(
  'DANMAKU_DEBUG_MODE',
  defaultValue: false,
);

bool resolveDanmakuDebugMode({
  required bool releaseMode,
  required bool requestedByDefine,
}) {
  return !releaseMode || requestedByDefine;
}

final bool danmakuDebugModeEnabled = resolveDanmakuDebugMode(
  releaseMode: kReleaseMode,
  requestedByDefine: _requestedByDefine,
);
