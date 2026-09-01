import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 双视频播放的运行时状态。
class DoubleVideoState {
  final bool isPlaying;
  final bool isSeeking;
  final bool buffering;
  final Duration position;
  final Duration duration;

  const DoubleVideoState({
    this.isPlaying = false,
    this.isSeeking = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  DoubleVideoState copyWith({
    bool? isPlaying,
    bool? isSeeking,
    bool? buffering,
    Duration? position,
    Duration? duration,
  }) {
    return DoubleVideoState(
      isPlaying: isPlaying ?? this.isPlaying,
      isSeeking: isSeeking ?? this.isSeeking,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

/// 双视频播放器的核心逻辑：两个 [Player] 的加载、主从同步、缓冲等待、
/// 播放/暂停/跳转。状态通过 [state] 暴露，方法可直接调用。
class DoubleVideoController {
  DoubleVideoController({required this.videoList}) {
    _player1 = Player();
    _player2 = Player();
    controller1 = VideoController(_player1);
    controller2 = VideoController(_player2);
    _player2.setVolume(0);
    state = ValueNotifier(_readState());
  }

  final List<Map<String, dynamic>> videoList;
  late final Player _player1;
  late final Player _player2;
  late final VideoController controller1;
  late final VideoController controller2;

  late final ValueNotifier<DoubleVideoState> state;

  bool _wantPlay = false;

  Timer? _syncTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  String _cleanUrl(String? url) {
    if (url == null) return '';
    return url.trim().replaceAll('`', '');
  }

  /// 打开两个视频并建立监听。在 widget 挂载后调用（一般 initState）。
  Future<void> initialize() async {
    if (videoList.isNotEmpty) {
      await _player1.open(Media(_cleanUrl(videoList[0]['videoPath'])),
          play: false);
    }
    if (videoList.length > 1) {
      await _player2.open(Media(_cleanUrl(videoList[1]['videoPath'])),
          play: false);
    }

    _setupListeners();
    _startSyncTimer();
  }

  void _setupListeners() {
    _subs.add(_player1.stream.playing.listen((_) => _publishState()));
    _subs.add(_player1.stream.duration.listen((_) => _publishState()));
    _subs.add(_player1.stream.position.listen((_) => _publishState()));
    _subs.add(_player1.stream.buffering.listen((_) => _handleBuffering()));
    _subs.add(_player2.stream.buffering.listen((_) => _handleBuffering()));
  }

  DoubleVideoState _readState() {
    final p1 = _player1.state;
    return DoubleVideoState(
      isPlaying: p1.playing,
      position: p1.position,
      duration: p1.duration,
      buffering: p1.buffering || _player2.state.buffering,
    );
  }

  void _publishState() {
    state.value = _readState();
  }

  void _handleBuffering() {
    // 状态来源直接用下游 player.state，避免手动累积布尔标志。
    final b1 = _player1.state.buffering;
    final b2 = _player2.state.buffering;
    _publishState();
    if (b1 || b2) {
      // 正在缓冲的那路 mpv 已通过 paused-for-cache 自行暂停，不要去 pause 它，
      // 只暂停未缓冲的另一路，让两者同步等待；之后缓冲结束一起恢复。
      if (!b1) _player1.pause();
      if (!b2) _player2.pause();
    } else if (_wantPlay) {
      _player1.play();
      _player2.play();
    }
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!state.value.isPlaying) return;
      final pos1 = _player1.state.position;
      final pos2 = _player2.state.position;
      if ((pos1 - pos2).abs() > const Duration(milliseconds: 500)) {
        _player2.seek(pos1);
      }
    });
  }

  void play() {
    _wantPlay = true;
    _player1.play();
    _player2.play();
  }

  void pause() {
    _wantPlay = false;
    _player1.pause();
    _player2.pause();
  }

  void togglePlayPause() {
    if (state.value.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seekTo(Duration position) {
    _player1.seek(position);
    _player2.seek(position);
    state.value = state.value.copyWith(position: position);
  }

  void seekRelative(Duration offset) {
    final total = state.value.duration.inMilliseconds;
    final clamped = (state.value.position.inMilliseconds + offset.inMilliseconds)
        .clamp(0, total);
    seekTo(Duration(milliseconds: clamped));
  }

  void dispose() {
    _syncTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    state.dispose();
    _player1.dispose();
    _player2.dispose();
  }
}

/// 只负责渲染两个视频画面的基础组件（类比 media_kit 的 [Video]）。
/// 不含控制栏、顶部栏、加载指示等 UI；布局和交互由外部提供。
class DoubleVideoPlayer extends StatelessWidget {
  final DoubleVideoController controller;

  /// 0 = 并排双屏；1 = 只看视频1；2 = 只看视频2。
  final int viewMode;
  final List<String> labels;

  const DoubleVideoPlayer({
    super.key,
    required this.controller,
    this.viewMode = 0,
    this.labels = const [],
  });

  List<String> get _effectiveLabels {
    if (labels.length >= controller.videoList.length) return labels;
    final result = List<String>.from(labels);
    while (result.length < controller.videoList.length) {
      result.add('');
    }
    return result;
  }

  Widget _render(VideoController videoController, String label) {
    return Stack(
      children: [
        Positioned.fill(
          child: Video(controller: videoController, controls: NoVideoControls),
        ),
        if (label.isNotEmpty)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = controller.videoList;
    final effectiveLabels = _effectiveLabels;

    if (list.length == 1) {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _render(controller.controller1, effectiveLabels[0]),
        ),
      );
    }

    final label1 = effectiveLabels[0];
    final label2 = effectiveLabels[1];

    switch (viewMode) {
      case 1:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _render(controller.controller1, label1),
          ),
        );
      case 2:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _render(controller.controller2, label2),
          ),
        );
      default:
        return Row(
          children: [
            Expanded(child: _render(controller.controller1, label1)),
            Container(width: 1, color: Colors.white24),
            Expanded(child: _render(controller.controller2, label2)),
          ],
        );
    }
  }
}
