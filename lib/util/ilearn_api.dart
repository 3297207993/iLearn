import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:ilearn/constants/app_constants.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';

class IlearnApi {
  var _dio;
  final _cookieManager = WebviewCookieManager();
  IlearnApi() {
    _dioInit();
  }

  void _dioInit() async {
    _dio = Dio(
      BaseOptions(
        headers: {
          "Host": "ilearntec.jlu.edu.cn",
          "Origin": "https://ilearntec.jlu.edu.cn",
          "Referer": "https://ilearntec.jlu.edu.cn/studycenter-web/course",
          "sec-ch-ua":
              "\"Chromium\";v=\"148\", \"Microsoft Edge\";v=\"148\", \"Not/A)Brand\";v=\"99\"",
          "Sec-Fetch-Dest": "empty",
          "Sec-Fetch-Mode": "cors",
          "Sec-Fetch-Site": "same-origin",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36 Edg/148.0.0.0",
          "Visit-Type": "web",
        },
      ),
    );
    var cookieJar = CookieJar();
    String mainUrl = AppConstants.httpsPrefix+ AppConstants.mainDomain;
    await cookieJar.saveFromResponse(
      Uri.parse(mainUrl),
      await _cookieManager.getCookies(mainUrl),
    );
    String ilearnUrl = AppConstants.httpsPrefix+ AppConstants.ilearnDomain;
    await cookieJar.saveFromResponse(
      Uri.parse(ilearnUrl),
      await _cookieManager.getCookies(ilearnUrl),
    );
    _dio.interceptors.add(CookieManager(cookieJar));
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
    _dio
      // ..get("https://ilearn.jlu.edu.cn/iplat/ssoservice")
      ..get("https://ilearntec.jlu.edu.cn/courselibrary-web/index?isLocation=1");
    print(await termList());
  }

  Future<Map<String, dynamic>> classList(int termYear, int term) async {
    var res = await _dio.get<Map<String, dynamic>>(
      AppConstants.httpsPrefix + AppConstants.mainDomain + '/studycenter/platform/classroom/myClassroom',
      queryParameters: {termYear: termYear, term: term},
    );
    return res.data;
  }

  Future<Map<String, dynamic>> termList() async {
    var res = await _dio.get<Map<String, dynamic>>(
      AppConstants.httpsPrefix + AppConstants.mainDomain + '/studycenter/platform/common/termList',
    );
    return res.data;
  }
}
