import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/webview_container.dart';
import 'success_page.dart';

/// 登录主页
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoggedIn = false;
  List<Cookie> _cookies = [];

  void _handleLoginSuccess(bool success, List<Cookie> cookies) {
    if (success) {
      setState(() {
        _isLoggedIn = true;
        _cookies = cookies;
      });
      
      // 打印Cookie信息用于调试
      print('登录成功，获取到 ${cookies.length} 个Cookie');
      for (var cookie in cookies) {
        print('Cookie: $cookie');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return SuccessPage(cookies: _cookies);
    } else {
      return WebViewContainer(onLoginSuccess: _handleLoginSuccess);
    }
  }
}
