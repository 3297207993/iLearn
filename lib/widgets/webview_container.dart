import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_constants.dart';

/// WebView容器组件
///
/// 仅负责浏览器部分的 CAS 登录。当浏览器登录成功、准备跳转到教务统一身份认证
/// （jwcidentity）跳板页（携带 CAS ticket）时，通过 [onSsoRelay] 把该跳板地址
/// 上报出去，并由上层用 Dio 接管后续请求。
class WebViewContainer extends StatefulWidget {
  /// 浏览器被拦截时回调，参数为携带 ticket 的跳板页地址。
  final ValueChanged<String> onSsoRelay;

  const WebViewContainer({
    super.key,
    required this.onSsoRelay,
  });

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late WebViewController _controller;
  bool _handled = false;

  bool _isRelayUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host == AppConstants.jwcIdentityRelayHost &&
        uri.path.startsWith(AppConstants.jwcIdentityRelayPath);
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url.toString();
            if (!_handled && _isRelayUrl(url)) {
              _handled = true;
              widget.onSsoRelay(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            // 兜底：若上方拦截未触发（个别平台依赖其加载完再回调），
            // 则仍以跳板页地址为准，交由上层接管。
            if (!_handled && _isRelayUrl(url)) {
              _handled = true;
              widget.onSsoRelay(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(AppConstants.loginUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
