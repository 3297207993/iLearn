import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ilearn/util/ilearn_api.dart';
import '../constants/app_constants.dart';

/// 登录成功页面
class SuccessPage extends StatelessWidget {
  IlearnApi ?_api;
  SuccessPage({super.key}){
    _api = IlearnApi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100.0,
            ),
            const SizedBox(height: 20),
            const Text(
              '登录成功！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '欢迎使用 ${AppConstants.appTitle}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
