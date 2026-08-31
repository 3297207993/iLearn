# 学在吉大（iLearn 第三方客户端）

> ⚠️ **非官方声明**：本项目是**个人开发的非官方第三方客户端**，与吉林大学及其 iLearn 平台（学在吉大）**没有任何官方关系**，未获得校方或平台方的授权、认可或支持。

一个使用 Flutter 开发的吉林大学 iLearn 在线教学平台的第三方移动端客户端，支持 Android / iOS。

## 基本功能

- **统一身份认证登录**：使用校园网统一身份认证账号登录，即可同步登录 iLearn 平台，无需额外操作。
- **课程列表**：按学期展示我的课程，支持学期切换；课程卡片展示封面、课程名、授课教师、课程状态（进行中 / 已结束）及课程类型。
- **直播 / 录播列表**：进入课程查看该课程的直播与录播记录，展示上课日期、星期、节次、时间范围、教室、视频时长以及视频机位（教师机位 / HDMI 等），并标注「直播中 / 可回看 / 未开始」状态。
- **原生视频播放**：
  - 基于 `media_kit` 的原生播放器，支持教师机位 + HDMI（PPT）双视频**同步播放**；
  - 双视频支持并排、单画面全屏、切换机位三种视图模式；
  - 支持播放 / 暂停、前后快退快进 10 秒、进度条拖动，播放时自动隐藏控制栏。

## 项目结构

```
lib/
├── main.dart                  # 应用入口
├── app.dart                   # 应用根组件
├── constants/
│   └── app_constants.dart     # URL 等常量配置
├── pages/
│   ├── login_page.dart        # 登录页（WebView + SSO 接管）
│   ├── main_page.dart         # 主页面（学期 + 课程列表）
│   ├── video_list_page.dart   # 直播 / 录播列表页
│   └── video_player_page.dart # 双视频同步播放页
├── util/
│   ├── ilearn_api.dart        # 网络层（Dio + Cookie 管理）
│   └── app_log.dart           # 日志工具
└── widgets/
    └── webview_container.dart # CAS 登录 WebView 容器
```

## 环境要求

- Flutter SDK（Dart SDK `^3.11.0`）
- Android 或 iOS 设备 / 模拟器

## 使用方法

1. 克隆项目并安装依赖：
   ```bash
   git clone <仓库地址>
   cd iLearn
   flutter pub get
   ```
2. 运行应用：
   ```bash
   flutter run
   ```
3. 使用吉林大学校园网账号（统一身份认证账号密码）登录，登录成功后即可查看课程、回看录播视频。

> 注：登录过程需连接可访问校园网 CAS 服务（cas.jlu.edu.cn）的网络环境。

## 技术栈

- **Flutter / Dart**：跨平台 UI 框架
- **webview\_flutter**：CAS 登录用的 WebView 容器
- **Dio + dio\_cookie\_manager + cookie\_jar**：网络请求与会话 Cookie 管理
- **media\_kit / media\_kit\_video**：原生视频播放

## 免责声明

1. 本项目仅用于个人学习与交流，请遵守校方及平台的相关规定，勿将本项目用于任何商业用途或违反校规校纪的行为。
2. 登录所需的账号密码仅用于完成平台自身的统一身份认证流程，仅在本地使用，不会上传至任何第三方服务器。
3. iLearn 平台接口可能随时变更，本应用不保证长期可用；使用过程中如遇问题，请以官方平台为准。
4. 使用本项目产生的任何后果（包括但不限于账号异常、数据丢失等）由使用者自行承担，作者不承担任何责任。

