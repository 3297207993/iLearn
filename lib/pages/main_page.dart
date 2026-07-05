import 'package:flutter/material.dart';
import 'package:ilearn/util/ilearn_api.dart';
import '../constants/app_constants.dart';
import 'video_list_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final IlearnApi _api = IlearnApi();
  List<Map<String, dynamic>> _terms = [];
  String? _selectedTermId;
  Map<String, dynamic>? _selectedTerm;
  List<Map<String, dynamic>> _courses = [];
  bool _isLoadingTerms = true;
  bool _isLoadingCourses = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final result = await _api.termList();
      final dataList = result['data']['dataList'] as List;
      final terms = dataList.cast<Map<String, dynamic>>();
      final defaultTerm = terms.firstWhere(
        (t) => t['selected'] == '1',
        orElse: () => terms.first,
      );
      setState(() {
        _terms = terms;
        _selectedTerm = defaultTerm;
        _selectedTermId = defaultTerm['id'];
        _isLoadingTerms = false;
      });
      await _loadCourses();
    } catch (e) {
      setState(() {
        _error = '加载学期列表失败';
        _isLoadingTerms = false;
      });
    }
  }

  Future<void> _loadCourses() async {
    if (_selectedTerm == null) return;
    setState(() {
      _isLoadingCourses = true;
      _error = null;
    });
    try {
      final termYear = int.parse(_selectedTerm!['year'].toString());
      final term = int.parse(_selectedTerm!['num'].toString());
      final result = await _api.classList(termYear, term);
      final dataList = result['data']['dataList'] as List;
      setState(() {
        _courses = dataList.cast<Map<String, dynamic>>();
        _isLoadingCourses = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载课程列表失败';
        _isLoadingCourses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appTitle)),
      body: _isLoadingTerms
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTermSelector(),
                Expanded(child: _buildCourseList()),
              ],
            ),
    );
  }

  Widget _buildTermSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.school, size: 20),
          const SizedBox(width: 8),
          const Text('学期:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedTermId,
              isExpanded: true,
              items: _terms.map((term) {
                return DropdownMenuItem<String>(
                  value: term['id'] as String,
                  child: Text('${term['year']} ${term['name']}'),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null && id != _selectedTermId) {
                  setState(() {
                    _selectedTermId = id;
                    _selectedTerm = _terms.firstWhere((t) => t['id'] == id);
                  });
                  _loadCourses();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    if (_isLoadingCourses) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadCourses, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_courses.isEmpty) {
      return const Center(child: Text('该学期暂无课程'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _courses.length,
      itemBuilder: (context, index) => _buildCourseCard(_courses[index]),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final statusName = course['statusName'] ?? '';
    final statusColor = statusName == '进行中'
        ? Colors.green
        : statusName == '已结束'
            ? Colors.grey
            : Colors.orange;
    return GestureDetector(
      onTap: () => _navigateToVideoList(course),
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Image.network(
              course['cover']?.toString().trim() ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.book, size: 48, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['courseName'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        course['teacherName'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor, width: 0.5),
                      ),
                      child: Text(statusName, style: TextStyle(fontSize: 10, color: statusColor)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      course['typeName'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _navigateToVideoList(Map<String, dynamic> course) {
    final teachClassId = course['id']?.toString() ?? '';
    final termId = course['termId']?.toString() ?? '';
    final courseName = course['courseName'] ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoListPage(
          teachClassId: teachClassId,
          termId: termId,
          courseName: courseName,
        ),
      ),
    );
  }
}