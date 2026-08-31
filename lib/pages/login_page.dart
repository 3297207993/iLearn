import 'package:flutter/material.dart';
import '../util/app_log.dart';
import '../util/ilearn_api.dart';
import '../widgets/webview_container.dart';
import 'main_page.dart';

/// 登录主页
///
/// 浏览器只负责 CAS 登录。一旦浏览器准备跳转到 jwcidentity 跳板页，
/// 便由 [IlearnApi.completeSsoLogin] 用 Dio 接管后续请求，从而把包括
/// HTTP-only 在内的完整会话 Cookie 收集起来。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  IlearnApi? _api;
  bool _isLoggingIn = false;
  bool _isLoggedIn = false;
  String? _error;
  int _sessionKey = 0;

  Future<void> _handleSsoRelay(String relayUrl) async {
    if (_isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
      _error = null;
    });

    try {
      final api = IlearnApi();
      final ok = await api.completeSsoLogin(relayUrl);
      if (!mounted) return;
      if (!ok) {
        log.w('SSO: completeSsoLogin returned false');
        setState(() {
          _isLoggingIn = false;
          _error = '登录失败，请重试';
        });
        return;
      }
      setState(() {
        _isLoggedIn = true;
        _isLoggingIn = false;
        _api = api;
      });
    } catch (e, s) {
      log.e('SSO: completeSsoLogin error: $e\n$s');
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _error = '登录失败，请重试';
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _sessionKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return MainPage(api: _api!);
    }
    return Stack(
      children: [
        if (_error == null)
          WebViewContainer(
            key: ValueKey(_sessionKey),
            onSsoRelay: _handleSsoRelay,
          ),
        if (_isLoggingIn)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          ColoredBox(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _retry, child: const Text('重新登录')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
