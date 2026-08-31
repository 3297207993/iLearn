/// 应用常量定义
class AppConstants {
  // 登录相关URL（统一认证 CAS 登录页，由浏览器 WebView 处理）
  static const String casBase = 'https://cas.jlu.edu.cn/tpass';

  // 教务统一身份认证（jwcidentity）的第三方登录服务地址，也是页面包含转发凭据的跳板页
  static const String casService =
      'https://jwcidentity.jlu.edu.cn/iplat-pass-jlu/thirdLogin/jlu/login';

  static final String loginUrl =
      '$casBase/login?service=${Uri.encodeQueryComponent(casService)}';

  // 拦截时机：WebView 只有在跳转到「教务统一身份认证跳板页」（携带 CAS ticket）时才被接管。
  // 用「域名 + 精确路径」而非仅域名匹配，避免误拦截该域名下的其他加载/子框架导航。
  static const String jwcIdentityRelayHost = 'jwcidentity.jlu.edu.cn';

  static const String jwcIdentityRelayPath =
      '/iplat-pass-jlu/thirdLogin/jlu/login';

  // iLearn 自有 CAS 平台（用于把跳板凭据换成 iLearn 的 ticket）
  static const String casServer = 'https://ilearn.jlu.edu.cn/cas-server';

  // iLearn 平台 SSO 服务地址，用于用 ticket 换取真正的登录会话 Cookie
  static const String iplat = 'https://ilearn.jlu.edu.cn/iplat';

  static const String ilearntec = 'https://ilearntec.jlu.edu.cn';

  static const String ilearntecService = 'https://ilearntec.jlu.edu.cn/';

  // 登录成功的目标域名
  static const String mainDomain = 'ilearntec.jlu.edu.cn';

  static const String ilearnDomain = 'ilearn.jlu.edu.cn';

  static const String resourceDomain = 'ilearnres.jlu.edu.cn';

  static const String httpsPrefix = 'https://';

  // 应用标题
  static const String appTitle = '学在吉大';
}
