import 'dart:convert';

/// 薇拉跨端便携备份（MVP 计划 §5，schemaVersion 固定为 1）。
///
/// 只携带收藏、追番、历史与白名单设置；凭据、代理、插件 Header、
/// 下载、缓存、本机路径与完整媒体 URL 一律不出现在格式中。
class WeilaPortableBackupV1 {
  const WeilaPortableBackupV1({
    required this.exportedAtUtc,
    required this.appVersion,
    required this.favorites,
    required this.history,
    required this.following,
    required this.safeSettings,
  });

  static const int schemaVersion = 1;
  static const int maximumEntriesPerList = 10000;

  final DateTime exportedAtUtc;
  final String appVersion;
  final List<Map<String, Object?>> favorites;
  final List<Map<String, Object?>> history;
  final List<Map<String, Object?>> following;
  final Map<String, Object?> safeSettings;

  /// 白名单设置键：只有这些设置允许进入备份并在导入时写回。
  static const Set<String> safeSettingKeys = {
    'isDarkMode',
    'showAdultCatalog',
  };

  String encodeJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAtUtc': exportedAtUtc.toUtc().toIso8601String(),
        'appVersion': appVersion,
        'favorites': favorites,
        'history': history,
        'following': following,
        'safeSettings': safeSettings,
      };

  /// 解析并完整校验；任何格式问题都会抛 [PortableBackupFormatException]，
  /// 调用方在写入任何本地数据前必须先完成解析。
  factory WeilaPortableBackupV1.decodeJson(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (error) {
      throw PortableBackupFormatException('备份文件不是有效的 JSON：$error');
    }
    return WeilaPortableBackupV1.fromDecoded(decoded);
  }

  factory WeilaPortableBackupV1.fromDecoded(Object? decoded) {
    if (decoded is! Map) {
      throw const PortableBackupFormatException('备份根节点必须是对象。');
    }
    final version = decoded['schemaVersion'];
    if (version is! int || version is bool) {
      throw const PortableBackupFormatException('schemaVersion 必须是整数。');
    }
    if (version != schemaVersion) {
      throw PortableBackupFormatException(
        '不支持的备份版本：${decoded['schemaVersion']}（当前支持 $schemaVersion）。',
      );
    }
    final exportedAt = _parseDate(decoded, 'exportedAtUtc');
    final appVersion = _requiredString(decoded, 'appVersion');

    return WeilaPortableBackupV1(
      exportedAtUtc: exportedAt,
      appVersion: appVersion,
      favorites: _parseEntries(decoded, 'favorites', _favoriteFields),
      history: _parseEntries(decoded, 'history', _historyFields),
      following: _parseEntries(decoded, 'following', _followingFields),
      safeSettings: _parseSafeSettings(decoded['safeSettings']),
    );
  }
}

class PortableBackupFormatException implements Exception {
  const PortableBackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ─── 字段白名单 ────────────────────────────────────────────────────────────

const _favoriteFields = <String, _FieldSpec>{
  'contentId': _FieldSpec.optionalString,
  'animeUrl': _FieldSpec.requiredString,
  'animeName': _FieldSpec.requiredString,
  'sourcePlugin': _FieldSpec.requiredString,
  'cover': _FieldSpec.optionalString,
  'description': _FieldSpec.optionalString,
  'collectedAt': _FieldSpec.requiredDate,
};

const _historyFields = <String, _FieldSpec>{
  'contentId': _FieldSpec.optionalString,
  'animeUrl': _FieldSpec.requiredString,
  'animeName': _FieldSpec.requiredString,
  'episodeName': _FieldSpec.requiredString,
  'episodeUrl': _FieldSpec.requiredString,
  'sourcePlugin': _FieldSpec.requiredString,
  'cover': _FieldSpec.optionalString,
  'positionMs': _FieldSpec.optionalNonNegativeInt,
  'durationMs': _FieldSpec.optionalNonNegativeInt,
  'watchedAt': _FieldSpec.requiredDate,
};

const _followingFields = <String, _FieldSpec>{
  'contentId': _FieldSpec.optionalString,
  'animeUrl': _FieldSpec.requiredString,
  'animeName': _FieldSpec.requiredString,
  'sourcePlugin': _FieldSpec.requiredString,
  'cover': _FieldSpec.optionalString,
  'status': _FieldSpec.optionalString,
  'totalEpisodes': _FieldSpec.optionalNonNegativeInt,
  'watchedEpisodes': _FieldSpec.optionalNonNegativeInt,
  'trackedAt': _FieldSpec.requiredDate,
};

class _FieldSpec {
  const _FieldSpec._(this.required, this.kind);

  static const requiredString = _FieldSpec._(true, 'string');
  static const optionalString = _FieldSpec._(false, 'string');
  static const requiredDate = _FieldSpec._(true, 'date');
  static const optionalNonNegativeInt = _FieldSpec._(false, 'nonNegativeInt');

  final bool required;
  final String kind;
}

// ─── 校验辅助 ──────────────────────────────────────────────────────────────

List<Map<String, Object?>> _parseEntries(
  Map<dynamic, dynamic> decoded,
  String key,
  Map<String, _FieldSpec> specs,
) {
  final raw = decoded[key];
  if (raw is! List) {
    throw PortableBackupFormatException('备份缺少有效的 $key 列表。');
  }
  if (raw.length > WeilaPortableBackupV1.maximumEntriesPerList) {
    throw PortableBackupFormatException(
      '$key 条目数 ${raw.length} 超过上限 '
      '${WeilaPortableBackupV1.maximumEntriesPerList}。',
    );
  }
  final entries = <Map<String, Object?>>[];
  for (var index = 0; index < raw.length; index++) {
    final entry = raw[index];
    if (entry is! Map) {
      throw PortableBackupFormatException('$key 第 $index 条不是对象。');
    }
    final validated = <String, Object?>{};
    for (final spec in specs.entries) {
      final value = entry[spec.key];
      if (value == null) {
        if (spec.value.required) {
          throw PortableBackupFormatException(
            '$key 第 $index 条缺少必填字段 ${spec.key}。',
          );
        }
        continue;
      }
      switch (spec.value.kind) {
        case 'string':
          if (value is! String || value.trim().isEmpty) {
            throw PortableBackupFormatException(
              '$key 第 $index 条字段 ${spec.key} 必须是非空字符串。',
            );
          }
        case 'date':
          if (value is! String || DateTime.tryParse(value) == null) {
            throw PortableBackupFormatException(
              '$key 第 $index 条字段 ${spec.key} 必须是 ISO8601 时间。',
            );
          }
        case 'nonNegativeInt':
          if (value is! int || value < 0) {
            throw PortableBackupFormatException(
              '$key 第 $index 条字段 ${spec.key} 必须是非负整数。',
            );
          }
      }
      validated[spec.key] = value;
    }
    entries.add(validated);
  }
  return entries;
}

Map<String, Object?> _parseSafeSettings(Object? raw) {
  if (raw is! Map) {
    throw const PortableBackupFormatException('safeSettings 必须是对象。');
  }
  final result = <String, Object?>{};
  for (final key in WeilaPortableBackupV1.safeSettingKeys) {
    final value = raw[key];
    if (value == null) continue;
    if (value is! bool) {
      throw PortableBackupFormatException('设置 $key 必须是布尔值。');
    }
    result[key] = value;
  }
  return result;
}

DateTime _parseDate(Map<dynamic, dynamic> decoded, String key) {
  final value = decoded[key];
  if (value is! String) {
    throw PortableBackupFormatException('$key 必须是 ISO8601 时间字符串。');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw PortableBackupFormatException('$key 不是有效时间。');
  }
  return parsed.toUtc();
}

String _requiredString(Map<dynamic, dynamic> decoded, String key) {
  final value = decoded[key];
  if (value is! String || value.trim().isEmpty) {
    throw PortableBackupFormatException('$key 必须是非空字符串。');
  }
  return value;
}

// ─── 幂等合并 ──────────────────────────────────────────────────────────────

/// 条目身份键：contentId 优先，旧记录回退 animeUrl（MVP 计划 §5）。
String portableEntryIdentity(Map<String, Object?> entry) {
  final contentId = entry['contentId'];
  if (contentId is String && contentId.trim().isNotEmpty) {
    return 'cid:$contentId';
  }
  return 'url:${entry['animeUrl'] as String}';
}

/// 历史合并：保留最新观看时间的记录，进度取两者中较大的有效值。
Map<String, Object?> mergeHistoryEntry(
  Map<String, Object?> existing,
  Map<String, Object?> incoming,
) {
  final existingTime = DateTime.parse(existing['watchedAt'] as String);
  final incomingTime = DateTime.parse(incoming['watchedAt'] as String);
  final newer = incomingTime.isAfter(existingTime) ? incoming : existing;
  final older = identical(newer, incoming) ? existing : incoming;
  final merged = Map<String, Object?>.from(newer);
  final newerPosition = (newer['positionMs'] as int?) ?? 0;
  final olderPosition = (older['positionMs'] as int?) ?? 0;
  if (olderPosition > newerPosition) {
    merged['positionMs'] = olderPosition;
    merged['durationMs'] = older['durationMs'];
  }
  return merged;
}

/// 收藏/追番合并：较新的用户状态胜出。
Map<String, Object?> mergeByTimestamp(
  Map<String, Object?> existing,
  Map<String, Object?> incoming,
  String timestampField,
) {
  final existingTime = DateTime.parse(existing[timestampField] as String);
  final incomingTime = DateTime.parse(incoming[timestampField] as String);
  return incomingTime.isAfter(existingTime) ||
          incomingTime.isAtSameMomentAs(existingTime)
      ? incoming
      : existing;
}
