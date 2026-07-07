import 'package:flutter/material.dart';
import 'package:ilearn/util/ilearn_api.dart';
import 'video_player_page.dart';

class VideoListPage extends StatefulWidget {
  final String teachClassId;
  final String termId;
  final String courseName;

  const VideoListPage({
    super.key,
    required this.teachClassId,
    required this.termId,
    required this.courseName,
  });

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  final IlearnApi _api = IlearnApi();
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _api.liveAndRecordList(
        widget.teachClassId,
        widget.termId,
      );
      final dataList = result['data']['dataList'] as List;
      setState(() {
        _videos = dataList.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载视频列表失败';
        _isLoading = false;
      });
    }
  }

  String _formatDuration(dynamic seconds) {
    final value = int.tryParse(seconds?.toString() ?? '');
    if (value == null || value <= 0) return '--:--';
    final h = value ~/ 3600;
    final m = (value % 3600) ~/ 60;
    final s = value % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getWeekDayName(dynamic day) {
    final value = int.tryParse(day?.toString() ?? '');
    if (value == null) return '';
    switch (value) {
      case 1:
        return '周一';
      case 2:
        return '周二';
      case 3:
        return '周三';
      case 4:
        return '周四';
      case 5:
        return '周五';
      case 6:
        return '周六';
      case 7:
        return '周日';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.courseName)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadVideos, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('暂无录播视频'));
    }
    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _videos.length,
        itemBuilder: (context, index) => _buildVideoCard(_videos[index]),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final liveRecordName = video['liveRecordName'] ?? '';
    final currentDate = video['currentDate'] ?? '';
    final weekDay = _getWeekDayName(video['currentDay']);
    final timeRange = video['timeRange'] ?? '';
    final section = video['section']?.toString() ?? '';
    final roomName = video['roomName'] ?? '';
    final buildingName = video['buildingName'] ?? '';
    final videoTimes = video['videoTimes'];
    final liveStatus = video['liveStatus']?.toString();
    final videoClassMap = video['videoClassMap'] as List?;

    final isLive = liveStatus == '2';
    final isFinished = liveStatus == '3';

    Color statusColor;
    String statusText;
    if (isLive) {
      statusColor = Colors.red;
      statusText = '直播中';
    } else if (isFinished) {
      statusColor = Colors.green;
      statusText = '可回看';
    } else {
      statusColor = Colors.orange;
      statusText = '未开始';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    liveRecordName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor, width: 0.5),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildInfoChip(Icons.calendar_today, '$currentDate $weekDay'),
                if (timeRange.isNotEmpty) _buildInfoChip(Icons.access_time, timeRange),
                if (section.isNotEmpty) _buildInfoChip(Icons.format_list_numbered, '第$section节'),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (roomName.isNotEmpty || buildingName.isNotEmpty)
                  _buildInfoChip(Icons.room, '$buildingName $roomName'.trim()),
                if (_formatDuration(videoTimes) != '--:--')
                  _buildInfoChip(Icons.timer, _formatDuration(videoTimes)),
              ],
            ),
            if (videoClassMap != null && videoClassMap.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: videoClassMap.cast<Map<String, dynamic>>().map((vc) {
                  return Chip(
                    label: Text(
                      vc['videoName'] ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isFinished ? () => _onWatchVideo(video) : null,
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: Text(isLive ? '直播中' : (isFinished ? '观看录播' : '暂未开始')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  void _onWatchVideo(Map<String, dynamic> video) {
    final resourceId = video['resourceId']?.toString() ?? '';
    final liveRecordName = video['liveRecordName']?.toString() ?? '';
    if (resourceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取资源信息')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          resourceId: resourceId,
          resourceName: liveRecordName,
        ),
      ),
    );
  }
}