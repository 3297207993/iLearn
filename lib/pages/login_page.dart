import 'package:flutter/material.dart';
import '../widgets/webview_container.dart';
import 'main_page.dart';

/// 登录主页
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoggedIn = false;

  void _handleLoginSuccess(bool success) {
    if (success) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return MainPage();
    } else {
      return WebViewContainer(onLoginSuccess: _handleLoginSuccess);
    }
  }
}
