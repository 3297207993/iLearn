import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import '../constants/app_constants.dart';

/// WebView容器组件
class WebViewContainer extends StatefulWidget {
  final Function(bool) onLoginSuccess;

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
          onPageFinished: (url) async {
            if (url.contains(AppConstants.mainDomain)) {
              await Future.delayed(const Duration(seconds: 2));
              widget.onLoginSuccess(true);
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