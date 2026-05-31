import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_constants.dart';

/// WebView容器组件
class WebViewContainer extends StatefulWidget {
  final Function(bool, List<String>) onLoginSuccess;

  const WebViewContainer({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    // 初始化 WebView 控制器
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (urlChange) async {
            // 检查URL是否包含目标域名
            if (urlChange.url != null && 
                urlChange.url!.contains(AppConstants.successDomain)) {
              try {
                // 通过JavaScript获取所有Cookie
                final cookies = await _controller.runJavaScriptReturningResult('document.cookie') as String;
                print('获取到的Cookies字符串: $cookies');
                
                // 解析Cookie字符串为列表
                final cookieList = cookies.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                
                // 通知父组件登录成功并传递Cookie
                widget.onLoginSuccess(true, cookieList);
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
