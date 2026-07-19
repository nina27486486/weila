class DanmakuCredentialDraft {
  const DanmakuCredentialDraft({
    required this.storedAppId,
    required this.storedAppSecret,
  });

  final String storedAppId;
  final String storedAppSecret;

  String get initialAppId => storedAppId;

  /// 密钥不回填到可编辑控件，避免被截图或辅助功能读取。
  String get initialSecret => '';

  String get secretHint =>
      storedAppSecret.isEmpty ? '输入弹弹play应用密钥' : '密钥已保存；留空表示不更换';

  String resolveSecret(String editedSecret) {
    final value = editedSecret.trim();
    return value.isEmpty ? storedAppSecret.trim() : value;
  }
}
