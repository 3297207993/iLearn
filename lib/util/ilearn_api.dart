import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:ilearn/constants/app_constants.dart';

class IlearnApi {
  late final Dio _dio;
  final CookieJar _cookieJar = CookieJar();

  /// 与参考实现一致：这些教育网域名使用不受系统信任的证书，需要跳过 TLS 证书校验。
  static IOHttpClientAdapter _insecureAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        client.badCertificateCallback = (_, _, _) => true;
        return client;
      },
    );
  }

  IlearnApi() {
    _dio = Dio(
      BaseOptions(
        headers: {
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
    _dio.httpClientAdapter = _insecureAdapter();
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  /// 在浏览器 CAS 登录成功后，接管后续的 iLearn 登录流程。
  ///
  /// [jwcRelayUrl] 是浏览器被拦截时准备跳转的跳板页地址（携带 CAS ticket），
  /// 形如 `https://jwcidentity.jlu.edu.cn/iplat-pass-jlu/thirdLogin/jlu/login?ticket=ST-...`。
  ///
  /// 本方法完全使用 Dio（而非浏览器）完成请求，因此能把 HTTP-only 的
  /// 会话 Cookie（如 `iplat/ssoservice` 下发）一并写入共享的 [_cookieJar]。
  Future<bool> completeSsoLogin(String jwcRelayUrl) async {
    final authDio = Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (_) => true,
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36 Edg/148.0.0.0',
        },
      ),
    );
    authDio.httpClientAdapter = _insecureAdapter();
    authDio.interceptors.add(CookieManager(_cookieJar));
    authDio.interceptors.add(
      LogInterceptor(request: true, responseBody: false, error: true),
    );

    // 1. 跟随跳板页，解析出用于登录 iLearn CAS 的转发凭据
    final jwcResp = await _requestWithRedirects(authDio, jwcRelayUrl);
    final jwcHtml = jwcResp.data ?? '';
    debugPrint('SSO: relay status=${jwcResp.statusCode} html=${jwcHtml.length}');
    final username = _extractInputValue(jwcHtml, 'id', 'username');
    final password = _extractInputValue(jwcHtml, 'id', 'password');
    if (username == null || password == null) {
      debugPrint('SSO: relay credentials not found');
      return false;
    }

    // 2. 获取 iLearn CAS 动态字段 lt / execution
    final ts0 = DateTime.now().millisecondsSinceEpoch;
    final nonceUrl =
        '${AppConstants.casServer}/login?'
        'service=${Uri.encodeComponent(AppConstants.ilearntecService)}'
        '&get-lt=true&callback=jsonpcallback&n=${ts0 + 1}&_=$ts0';
    final nonceResp = await _requestWithRedirects(authDio, nonceUrl);
    final nonceJson = _parseJsonp(nonceResp.data ?? '');
    final lt = nonceJson['lt'] as String? ?? '';
    final execution = nonceJson['execution'] as String? ?? '';
    if (lt.isEmpty || execution.isEmpty) return false;

    // 3. 用转发凭据登录 iLearn CAS，换取 ticket
    final passwordBase64 = base64Encode(utf8.encode(password));
    final ts = DateTime.now().millisecondsSinceEpoch;
    final loginUrl =
        '${AppConstants.casServer}/login?'
        'service=${Uri.encodeComponent(AppConstants.ilearntecService)}'
        '&username=${Uri.encodeComponent(username)}'
        '&password=${Uri.encodeComponent(passwordBase64)}'
        '&isajax=true&isframe=true&_eventId=submit'
        '&lt=${Uri.encodeComponent(lt)}'
        '&execution=${Uri.encodeComponent(execution)}'
        '&type=pwd&callback=logincallback&n=${ts + 1}&_=$ts';
    final loginResp = await _requestWithRedirects(authDio, loginUrl);
    final loginJson = _parseJsonp(loginResp.data ?? '');

    if (loginJson['login'] == 'fails') return false;

    final ticket = loginJson['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) return false;
    debugPrint('SSO: got ticket=$ticket');

    // 4. 用 ticket 走 SSO（与参考实现一致，其返回结果被忽略，仅用于触发会话）
    await _requestWithRedirects(
      authDio,
      '${AppConstants.iplat}/ssoservice?'
      'ssoservice=${Uri.encodeComponent(AppConstants.ilearntecService)}'
      '&ticket=${Uri.encodeComponent(ticket)}',
    );
    // 5. 建立 ilearntec 平台的真实会话。
    //    实测 /coursecenter/main/index 这条 CAS 链能走通并返回 200、下发有效 SESSION；
    //    而 /studycenter/platform/main/index?ticket 校验会 500，故不采用它。
    final homeResp = await _requestWithRedirects(
      authDio,
      '${AppConstants.ilearntec}/coursecenter/main/index',
    );
    debugPrint('SSO: homepage warmup status=${homeResp.statusCode}');

    final cookies = await _cookieJar.loadForRequest(
      Uri.parse(AppConstants.ilearntecService),
    );
    debugPrint('SSO: collected ${cookies.length} cookies for ilearntec: '
        '${cookies.map((c) => c.name).join(',')}');

    return true;
  }

  /// 手动跟随重定向，确保每一步响应的 Set-Cookie 都被 [CookieJar] 记录
  /// （Dio 自动跟随重定向会丢弃中间跳转 Set-Cookie）。
  Future<Response<String>> _requestWithRedirects(Dio dio, String url) async {
    var current = url;
    for (var i = 0; i < 10; i++) {
      final resp = await dio.get<String>(current);
      final status = resp.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = resp.headers.value('location');
        if (location == null || location.isEmpty) {
          throw DioException.badResponse(
            statusCode: status,
            requestOptions: resp.requestOptions,
            response: resp,
          );
        }
        current = resp.requestOptions.uri.resolve(location).toString();
        continue;
      }
      return resp;
    }
    throw StateError('Too many redirects for $url');
  }

  /// 从 HTML 中找到形如 `<input id/name="attrValue" ... value="...">` 的输入框并返回其 value。
  String? _extractInputValue(String html, String attrName, String attrValue) {
    final tagReg = RegExp(r'<input\b[^>]*>', caseSensitive: false);
    final attrReg = RegExp(
      '\\b$attrName\\s*=\\s*["\']${RegExp.escape(attrValue)}["\']',
      caseSensitive: false,
    );
    final valueReg = RegExp(
      '\\bvalue\\s*=\\s*["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    for (final match in tagReg.allMatches(html)) {
      final tag = match.group(0);
      if (tag == null) continue;
      if (!attrReg.hasMatch(tag)) continue;
      final valueMatch = valueReg.firstMatch(tag);
      if (valueMatch != null) return valueMatch.group(1);
    }
    return null;
  }

  /// 解析形如 `callback({...})` 的 JSONP 响应文本。
  Map<String, dynamic> _parseJsonp(String text) {
    final start = text.indexOf('(');
    final end = text.lastIndexOf(')');
    if (start < 0 || end < 0 || end <= start) {
      throw FormatException('Invalid JSONP response: $text');
    }
    final body = text.substring(start + 1, end);
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  /// 获取课程列表
  ///
  /// [termYear] 学年，如 2025
  /// [term] 学期编号，1 表示第一学期，2 表示第二学期
  ///
  /// 返回值结构：
  /// ```
  /// {
  ///   "code": "1000",
  ///   "status": "1",
  ///   "message": "查询成功",
  ///   "data": {
  ///     "pageConfig": { "totalPage", "pageSize", "page", "totalCount" },
  ///     "dataList": [
  ///       {
  ///         "id": 课堂ID,
  ///         "name": 课堂名称,
  ///         "courseId": 课程ID,
  ///         "courseName": 课程名称,
  ///         "cover": 封面图URL,
  ///         "teacherId": 教师ID,
  ///         "teacherName": 教师姓名,
  ///         "status": 状态码,
  ///         "statusName": 状态名称（进行中/已结束）,
  ///         "termYear": 学年,
  ///         "term": 学期,
  ///         "code": 课程代码,
  ///         "weekTime": 上课时间,
  ///         "studentCount": 学生人数,
  ///         "codePath": 代码路径,
  ///         "teaImg": 教师头像,
  ///         "classId": 班级ID,
  ///         "classroomId": 教室ID,
  ///         "className": 班级名称,
  ///         "teacherUsername": 教师用户名,
  ///         "schoolId": 学校ID,
  ///         "studentId": 学生ID,
  ///         "type": 类型码,
  ///         "typeName": 类型名称（公开课等）,
  ///         "termId": 学期ID,
  ///         "mirrorTeachClassId": 镜像教学班ID,
  ///         "schoolName": 学校名称,
  ///         "isAreaCourse": 是否区域课程,
  ///         "openCourseId": 开放课程ID,
  ///         "openType": 开放类型,
  ///         "areaSchoolNames": 区域学校名称
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> classList(int termYear, int term) async {
    var res = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.httpsPrefix}${AppConstants.mainDomain}/studycenter/platform/classroom/myClassroom',
      queryParameters: {'termYear': termYear, 'term': term},
    );
    return res.data!;
  }

  /// 获取学期列表
  ///
  /// 返回值结构：
  /// ```
  /// {
  ///   "code": "1000",
  ///   "status": "1",
  ///   "message": "查询成功",
  ///   "data": {
  ///     "dataList": [
  ///       {
  ///         "id": 学期ID,
  ///         "year": 学年，如 "2025",
  ///         "num": 学期编号，"1" 或 "2",
  ///         "name": 学期名称，如 "第二学期",
  ///         "startDate": 开始日期,
  ///         "endDate": 结束日期,
  ///         "selected": 是否当前选中（"1"/"0"）
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> termList() async {
    var res = await _dio.post<Map<String, dynamic>>(
      '${AppConstants.httpsPrefix}${AppConstants.mainDomain}/studycenter/platform/common/termList',
      data: '',
    );
    return res.data!;
  }

  /// 获取直播与录播列表
  ///
  /// [teachClassId] 教学班ID
  /// [termId] 学期ID
  ///
  /// 返回值结构：
  /// ```
  /// {
  ///   "code": "1000",
  ///   "status": "1",
  ///   "message": "操作成功",
  ///   "data": {
  ///     "dataList": [
  ///       {
  ///         "id": 录播记录ID,
  ///         "resourceId": 资源ID,
  ///         "liveRecordName": 录播名称,
  ///         "buildingName": 教学楼名称,
  ///         "currentWeek": 当前周次,
  ///         "currentDay": 当前星期,
  ///         "currentDate": 当前日期,
  ///         "roomName": 教室名称,
  ///         "roomId": 教室ID,
  ///         "isAllowDownload": 是否允许下载,
  ///         "isNowPlay": 是否正在播放,
  ///         "teacherName": 教师姓名,
  ///         "courseId": 课程ID,
  ///         "courseName": 课程名称,
  ///         "classIds": 班级ID,
  ///         "classNames": 班级名称,
  ///         "section": 节次,
  ///         "timeRange": 时间范围,
  ///         "isOpen": 是否开放,
  ///         "isAction": 是否进行中,
  ///         "liveStatus": 直播状态（1=未开始, 3=已结束）,
  ///         "schImgUrl": 课程封面URL,
  ///         "videoTimes": 视频时长（秒）,
  ///         "videoSubTime": 视频子时长,
  ///         "classType": 课堂类型,
  ///         "videoPath": 视频路径,
  ///         "videoClassMap": [
  ///           {
  ///             "videoClassId": 视频分类ID,
  ///             "videoName": 视频分类名称（教师机位/HDMI）
  ///           }
  ///         ],
  ///         "resourceFileType": 资源文件类型,
  ///         "livePath": 直播路径,
  ///         "roomType": 教室类型,
  ///         "scheduleTimeStart": 计划开始时间,
  ///         "scheduleTimeEnd": 计划结束时间
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  /// 响应中的videoClassMap通常是两个元素，一个元素是教师机位，另一个元素是HDMI（教室视频和PPT视频）
  Future<Map<String, dynamic>> liveAndRecordList(
    String teachClassId,
    String termId,
  ) async {
    var res = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.httpsPrefix}${AppConstants.mainDomain}/coursecenter/liveAndRecord/getLiveAndRecordInfoList',
      queryParameters: {
        'memberId': '',
        'roomType': '0',
        'identity': '2',
        'liveStatus': '0',
        'submitStatus': '0',
        'weekNum': '',
        'dayNum': '',
        'timeRange': '',
        'teachClassId': teachClassId,
        'termId': termId,
      },
    );
    return res.data!;
  }

  /// 获取录播课视频详情
  ///
  /// [resourceId] 资源ID
  ///
  /// 返回值结构：
  /// ```
  /// {
  ///   "status": "1",
  ///   "message": "",
  ///   "success": true,
  ///   "data": {
  ///     "detectKnowledgeStatus": 知识点检测状态,
  ///     "liveRecordId": 录播记录ID,
  ///     "enableWater": 是否启用水印,
  ///     "teacherList": ["教师姓名"],
  ///     "classNames": 班级名称,
  ///     "videoList": [
  ///       {
  ///         "id": 视频ID,
  ///         "videoCode": 视频编号,
  ///         "videoName": 视频名称（教师机位/HDMI）,
  ///         "videoPath": 视频播放地址,
  ///         "videoSize": 视频文件大小
  ///       }
  ///     ],
  ///     "transPhaseStatus": 转写阶段状态,
  ///     "company": 公司标识,
  ///     "courseId": 课程ID,
  ///     "videoCutStatus": 视频裁剪状态,
  ///     "scheduleId": 排课ID,
  ///     "resourceCover": 资源封面图URL,
  ///     "phaseUrl": 字幕文件URL,
  ///     "teacherName": 教师姓名,
  ///     "teacherIds": 教师ID,
  ///     "resourceName": 资源名称,
  ///     "isPublish": 是否发布,
  ///     "parentId": 父级ID,
  ///     "roomName": 教室名称,
  ///     "audioPath": 音频播放地址,
  ///     "commentStatus": 评论状态,
  ///     "buildingName": 教学楼名称,
  ///     "createId": 创建者ID,
  ///     "classType": 课堂类型,
  ///     "silenceList": [],
  ///     "resourceType": 资源类型
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> videoClassInfo(String resourceId) async {
    // 先在资源域建立会话（与参考实现一致），否则直接请求 videoClassInfo 会返回“获取录播课信息失败”。
    await _dio.get(
      '${AppConstants.httpsPrefix}${AppConstants.resourceDomain}/resource-center/zhwk/selectLanguageExists',
      queryParameters: {'resourceId': resourceId},
    );
    var res = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.httpsPrefix}${AppConstants.resourceDomain}/resource-center/videoclass/videoClassInfo',
      queryParameters: {'resourceId': resourceId},
    );
    return res.data!;
  }
}
