/// 坚果云连接凭证
///
/// `appPassword` 是**应用密码**（第三方应用专用），不是坚果云登录密码。
/// 在 https://www.jianguoyun.com/d/account#safe 生成。
///
/// 该对象整体存入 `flutter_secure_storage`（设备本地加密），
/// **绝不写入同步到云端的 config.yaml**。
class NutstoreCredentials {
  /// 坚果云注册邮箱
  final String email;

  /// 应用密码
  final String appPassword;

  /// WebDAV 服务地址，一般无需修改
  final String baseUrl;

  const NutstoreCredentials({
    required this.email,
    required this.appPassword,
    this.baseUrl = defaultBaseUrl,
  });

  /// 坚果云官方 WebDAV 端点
  static const String defaultBaseUrl = 'https://dav.jianguoyun.com/dav/';

  /// 是否填写完整
  bool get isComplete =>
      email.trim().isNotEmpty && appPassword.trim().isNotEmpty;

  /// 邮箱是否形似合法（只做基本形态校验，不追求 RFC 完备）
  bool get looksLikeEmail {
    final e = email.trim();
    return e.contains('@') && e.indexOf('@') > 0 && e.indexOf('@') < e.length - 1;
  }

  /// 校验并返回问题描述，合法时返回 null
  String? validate() {
    if (email.trim().isEmpty) return '请填写坚果云注册邮箱';
    if (!looksLikeEmail) return '邮箱格式不正确';
    if (appPassword.trim().isEmpty) return '请填写应用密码';
    if (appPassword.trim().length < 6) {
      return '应用密码长度不足 —— 确认用的不是登录密码？';
    }
    return null;
  }

  /// 邮箱的脱敏展示，如 `ab***@example.com`
  String get maskedEmail {
    final e = email.trim();
    final at = e.indexOf('@');
    if (at <= 2) return e;
    return '${e.substring(0, 2)}***${e.substring(at)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutstoreCredentials &&
          other.email == email &&
          other.appPassword == appPassword &&
          other.baseUrl == baseUrl;

  @override
  int get hashCode => Object.hash(email, appPassword, baseUrl);

  @override
  String toString() => 'NutstoreCredentials($maskedEmail)';
}
