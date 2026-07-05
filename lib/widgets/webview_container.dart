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
  bool _hasTriggeredLogin = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains(AppConstants.mainDomain) && !_hasTriggeredLogin) {
              _hasTriggeredLogin = true;
              await _waitForCookiesReady();
              widget.onLoginSuccess(true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(AppConstants.loginUrl));
  }

  Future<void> _waitForCookiesReady() async {
    final targetUrl = '${AppConstants.httpsPrefix}${AppConstants.mainDomain}';
    const maxAttempts = 20;
    const interval = Duration(milliseconds: 500);

    for (int i = 0; i < maxAttempts; i++) {
      final cookies = await _cookieManager.getCookies(targetUrl);
      print(cookies);
      if (cookies.length >= 2) {
        await Future.delayed(Duration(milliseconds: 5000));
        return;
      }
      await Future.delayed(interval);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}