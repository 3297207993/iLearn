import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import '../constants/app_constants.dart';

/// WebView容器组件
class WebViewContainer extends StatefulWidget {
  final Function(bool, List<Cookie>) onLoginSuccess;

  const WebViewContainer({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late WebViewController _controller;
  final WebviewCookieManager _cookieManager = WebviewCookieManager();

  @override
  void initState() {
    super.initState();
    
    // 初始化 WebView 控制器
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange) async {
            // 检查URL是否包含目标域名
            if (UrlChange.url!.contains(AppConstants.successDomain)) {
              try {
                // 使用CookieManager获取所有Cookie（包括HttpOnly）
                final cookies = await _cookieManager.getCookies(UrlChange.url!);
                
                // 通知父组件登录成功并传递Cookie
                widget.onLoginSuccess(true, cookies);
              } catch (e) {
                print('获取Cookie失败: $e');
                // 即使获取Cookie失败也通知登录成功
                widget.onLoginSuccess(true, []);
              }
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
