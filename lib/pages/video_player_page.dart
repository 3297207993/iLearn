import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ilearn/util/ilearn_api.dart';

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

  late final Player _player1;
  late final Player _player2;
  late final VideoController _controller1;
  late final VideoController _controller2;

  List<Map<String, dynamic>> _videoList = [];
  bool _isLoading = true;
  String? _error;

  bool _isPlaying = false;
  bool _isSeeking = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _showControls = true;
  int _viewMode = 0;

  Timer? _syncTimer;
  Timer? _controlsTimer;
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player1 = Player();
    _player2 = Player();
    _controller1 = VideoController(_player1);
    _controller2 = VideoController(_player2);

    _player2.setVolume(0);

    _loadVideoInfo();
  }

  String _cleanUrl(String? url) {
    if (url == null) return '';
    return url.trim().replaceAll('`', '');
  }

  Future<void> _loadVideoInfo() async {
    try {
      final result = await IlearnApi.instance.videoClassInfo(widget.resourceId);
      final data = result['data'] as Map<String, dynamic>;
      final videoList =
          (data['videoList'] as List).cast<Map<String, dynamic>>();

      setState(() {
        _videoList = videoList;
        _isLoading = false;
      });

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
      _resetControlsTimer();
    } catch (e) {
      setState(() {
        _error = '加载视频信息失败';
        _isLoading = false;
      });
    }
  }

  void _setupListeners() {
    _playingSub = _player1.stream.playing.listen((playing) {
      if (mounted && !_isSeeking) {
        setState(() => _isPlaying = playing);
        if (playing) _resetControlsTimer();
      }
    });
    _durationSub = _player1.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _positionSub = _player1.stream.position.listen((position) {
      if (mounted && !_isSeeking) setState(() => _position = position);
    });
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!_isPlaying) return;
      final pos1 = _player1.state.position;
      final pos2 = _player2.state.position;
      if ((pos1 - pos2).abs() > const Duration(milliseconds: 500)) {
        _player2.seek(pos1);
      }
    });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player1.pause();
      _player2.pause();
    } else {
      _player1.play();
      _player2.play();
    }
  }

  void _seekTo(Duration position) {
    _player1.seek(position);
    _player2.seek(position);
    setState(() => _position = position);
  }

  void _seekRelative(Duration offset) {
    final newMs = (_position.inMilliseconds + offset.inMilliseconds)
        .clamp(0, _duration.inMilliseconds);
    _seekTo(Duration(milliseconds: newMs));
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
    _syncTimer?.cancel();
    _controlsTimer?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _player1.dispose();
    _player2.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: _buildVideoArea(),
          ),
          if (!_isPlaying && !_isLoading && _error == null)
            Center(
              child: IconButton(
                icon: const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 64),
                onPressed: _togglePlayPause,
              ),
            ),
          if (_showControls) ...[
            _buildTopBar(),
            _buildBottomControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildLabeledVideo(VideoController controller, String label) {
    return Stack(
      children: [
        Positioned.fill(child: Video(controller: controller)),
        if (_showControls)
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

  Widget _buildVideoArea() {
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

    if (_videoList.length == 1) {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildLabeledVideo(
              _controller1, _videoList[0]['videoName'] ?? ''),
        ),
      );
    }

    final label1 = _videoList[0]['videoName'] ?? '视频1';
    final label2 = _videoList[1]['videoName'] ?? '视频2';

    switch (_viewMode) {
      case 1:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildLabeledVideo(_controller1, label1),
          ),
        );
      case 2:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildLabeledVideo(_controller2, label2),
          ),
        );
      default:
        return Row(
          children: [
            Expanded(child: _buildLabeledVideo(_controller1, label1)),
            Container(width: 1, color: Colors.white24),
            Expanded(child: _buildLabeledVideo(_controller2, label2)),
          ],
        );
    }
  }

  Widget _buildTopBar() {
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

  Widget _buildBottomControls() {
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
                  _formatDuration(_position),
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
                      value: _duration.inMilliseconds > 0
                          ? (_position.inMilliseconds /
                                  _duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0,
                      onChanged: (value) {
                        setState(() {
                          _isSeeking = true;
                          _position = Duration(
                            milliseconds:
                                (_duration.inMilliseconds * value).round(),
                          );
                        });
                      },
                      onChangeEnd: (value) {
                        _seekTo(Duration(
                          milliseconds:
                              (_duration.inMilliseconds * value).round(),
                        ));
                        _isSeeking = false;
                        _resetControlsTimer();
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_duration),
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
                      _seekRelative(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 44,
                  ),
                  onPressed: _togglePlayPause,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.forward_10,
                      color: Colors.white, size: 28),
                  onPressed: () =>
                      _seekRelative(const Duration(seconds: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}