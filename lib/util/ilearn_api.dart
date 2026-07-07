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
    await _ready;
    var res = await _dio.get<Map<String, dynamic>>(
      AppConstants.httpsPrefix + AppConstants.mainDomain + '/coursecenter/liveAndRecord/getLiveAndRecordInfoList',
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
    await _ready;
    var res = await _dio.get<Map<String, dynamic>>(
      AppConstants.httpsPrefix + AppConstants.resourceDomain + '/resource-center/videoclass/videoClassInfo',
      queryParameters: {'resourceId': resourceId},
    );
    return res.data!;
  }
}