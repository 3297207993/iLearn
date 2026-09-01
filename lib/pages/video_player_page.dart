import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ilearn/util/ilearn_api.dart';
import 'package:ilearn/widgets/double_video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String resourceId;
  final String resourceName;

  const VideoPlayerPage({
    super.key,
    required this.resourceId,
    this.resourceName = '',
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  List<Map<String, dynamic>> _videoList = [];
  bool _isLoading = true;
  String? _error;

  DoubleVideoController? _controller;

  int _viewMode = 0;
  bool _showControls = true;
  bool _isSeeking = false;
  Duration _dragPosition = Duration.zero;

  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadVideoInfo();
  }

  Future<void> _loadVideoInfo() async {
    try {
      final result = await IlearnApi.instance.videoClassInfo(widget.resourceId);
      final data = result['data'] as Map<String, dynamic>;
      final videoList =
          (data['videoList'] as List).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _videoList = videoList;
        _isLoading = false;
      });

      _initController();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载视频信息失败';
          _isLoading = false;
        });
      }
    }
  }

  void _initController() {
    final controller =
        DoubleVideoController(videoList: _videoList);
    controller.state.addListener(_onStateChanged);
    _controller = controller;
    controller.initialize();
    _resetControlsTimer();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    final isPlaying = _controller?.state.value.isPlaying ?? false;
    if (isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller?.state.removeListener(_onStateChanged);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  List<String> get _labels => _videoList
      .map((e) => (e['videoName'] as String?) ?? '')
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadVideoInfo, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_videoList.isEmpty) {
      return const Center(
          child: Text('暂无视频', style: TextStyle(color: Colors.white)));
    }
    if (_controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final controller = _controller!;
    final state = controller.state.value;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: DoubleVideoPlayer(
            controller: controller,
            viewMode: _viewMode,
            labels: _labels,
          ),
        ),
        if (!state.isPlaying && !state.buffering)
          Center(
            child: IconButton(
              icon: const Icon(Icons.play_circle_fill,
                  color: Colors.white70, size: 64),
              onPressed: controller.togglePlayPause,
            ),
          ),
        if (state.buffering)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        if (_showControls) ...[
          _buildTopBar(controller),
          _buildBottomControls(controller, state),
        ],
      ],
    );
  }

  Widget _buildTopBar(DoubleVideoController controller) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.transparent, Colors.black54],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 16,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                widget.resourceName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_videoList.length > 1) ...[
              IconButton(
                icon: Icon(
                  _viewMode == 0
                      ? Icons.fullscreen
                      : Icons.view_column_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _viewMode = _viewMode == 0 ? 1 : 0);
                  _resetControlsTimer();
                },
                tooltip: _viewMode == 0 ? '全屏' : '并排',
              ),
              if (_viewMode != 0)
                IconButton(
                  icon: const Icon(Icons.swap_horiz,
                      color: Colors.white, size: 22),
                  onPressed: () {
                    setState(() => _viewMode = _viewMode == 1 ? 2 : 1);
                    _resetControlsTimer();
                  },
                  tooltip: '切换视频',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(
      DoubleVideoController controller, DoubleVideoState state) {
    final position = _isSeeking ? _dragPosition : state.position;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54],
          ),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 2,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: state.duration.inMilliseconds > 0
                          ? (position.inMilliseconds /
                                  state.duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0,
                      onChanged: (value) {
                        setState(() {
                          _isSeeking = true;
                          _dragPosition = Duration(
                            milliseconds:
                                (state.duration.inMilliseconds * value).round(),
                          );
                        });
                      },
                      onChangeEnd: (value) {
                        controller.seekTo(Duration(
                          milliseconds:
                              (state.duration.inMilliseconds * value).round(),
                        ));
                        setState(() {
                          _isSeeking = false;
                          _dragPosition = Duration.zero;
                        });
                        _resetControlsTimer();
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10,
                      color: Colors.white, size: 28),
                  onPressed: () =>
                      controller.seekRelative(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 44,
                  ),
                  onPressed: controller.togglePlayPause,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.forward_10,
                      color: Colors.white, size: 28),
                  onPressed: () =>
                      controller.seekRelative(const Duration(seconds: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
