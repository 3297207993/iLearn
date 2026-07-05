import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:ilearn/constants/app_constants.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';

class IlearnApi {
  late final Dio _dio;
  final _cookieManager = WebviewCookieManager();
  late final Future<void> _ready;

  IlearnApi() {
    _ready = _setup();
  }

  Future<void> _setup() async {
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
    String mainUrl = AppConstants.httpsPrefix + AppConstants.mainDomain;
    await cookieJar.saveFromResponse(
      Uri.parse(mainUrl),
      await _cookieManager.getCookies(mainUrl),
    );
    String ilearnUrl = AppConstants.httpsPrefix + AppConstants.ilearnDomain;
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
    await _ready;
    var res = await _dio.get<Map<String, dynamic>>(
      AppConstants.httpsPrefix + AppConstants.mainDomain + '/studycenter/platform/classroom/myClassroom',
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
    await _ready;
    var res = await _dio.get<Map<String, dynamic>>(
      AppConstants.httpsPrefix + AppConstants.mainDomain + '/studycenter/platform/common/termList',
    );
    return res.data!;
  }
}