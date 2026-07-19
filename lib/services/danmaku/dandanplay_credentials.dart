class DandanplayCredentials {
  const DandanplayCredentials({
    required this.appId,
    required this.appSecret,
  });

  final String appId;
  final String appSecret;

  bool get isValid => appId.trim().isNotEmpty && appSecret.trim().isNotEmpty;

  @override
  String toString() {
    return 'DandanplayCredentials(appId: configured, appSecret: redacted)';
  }
}
