import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../attendance/domain/attendance_model.dart';
import '../../eccd_evaluation/domain/evaluation_model.dart';
import '../../parent/domain/parent_feedback_model.dart';
import '../../triangulation/domain/triangulation_model.dart';

class ChildMonitoringPage extends StatefulWidget {
  const ChildMonitoringPage({super.key});

  @override
  State<ChildMonitoringPage> createState() => _ChildMonitoringPageState();
}

class _ChildMonitoringPageState extends State<ChildMonitoringPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ChildModel> _children = [];
  List<ChildModel> _filteredChildren = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    
    if (kIsWeb) {
      final snapshot = await _firestore.collection('children').get();
      _children = snapshot.docs.map((doc) => ChildModel.fromMap(doc.data())).toList();
    } else {
      _children = await DatabaseHelper.instance.getAllChildren();
    }

    setState(() {
      _filteredChildren = _children;
      _isLoading = false;
    });
  }

  void _filterChildren(String query) {
    setState(() {
      _filteredChildren = _children
          .where((child) =>
              child.firstName.toLowerCase().contains(query.toLowerCase()) ||
              child.lastName.toLowerCase().contains(query.toLowerCase()) ||
              child.childId.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _viewChildDetails(ChildModel child) {
    showDialog(
      context: context,
      builder: (context) => _ChildDetailDialog(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Monitoring (Admin)'),
        actions: [
          IconButton(onPressed: _loadChildren, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by Name or Child ID...',
              leading: const Icon(Icons.search),
              onChanged: _filterChildren,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChildren.isEmpty
                    ? const Center(child: Text('No matching child records found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredChildren.length,
                        itemBuilder: (context, index) {
                          final child = _filteredChildren[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(child.firstName[0].toUpperCase()),
                              ),
                              title: Text('${child.firstName} ${child.lastName}', 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('ID: ${child.childId} | Teacher: ${child.teacherName}'),
                              trailing: const Icon(Icons.analytics_outlined, color: Colors.blue),
                              onTap: () => _viewChildDetails(child),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChildDetailDialog extends StatefulWidget {
  final ChildModel child;
  const _ChildDetailDialog({required this.child});

  @override
  State<_ChildDetailDialog> createState() => _ChildDetailDialogState();
}

class _ChildDetailDialogState extends State<_ChildDetailDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<AttendanceModel> _attendance = [];
  List<EvaluationModel> _evaluations = [];
  List<ParentFeedbackModel> _feedback = [];
  TriangulationModel? _latestTriangulation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final String cid = widget.child.childId;

    if (kIsWeb) {
      final attSnap = await _firestore.collection('attendance').where('child_id', isEqualTo: cid).get();
      final evalSnap = await _firestore.collection('evaluations').where('child_id', isEqualTo: cid).get();
      final feedSnap = await _firestore.collection('parent_feedback').where('child_id', isEqualTo: cid).get();
      final triSnap = await _firestore.collection('triangulations').where('child_id', isEqualTo: cid).get();

      setState(() {
        _attendance = attSnap.docs.map((d) => AttendanceModel.fromMap(d.data())).toList();
        _evaluations = evalSnap.docs.map((d) => EvaluationModel.fromMap(d.data())).toList();
        _feedback = feedSnap.docs.map((d) => ParentFeedbackModel.fromMap(d.data())).toList();
        if (triSnap.docs.isNotEmpty) {
          _latestTriangulation = TriangulationModel.fromMap(triSnap.docs.first.data());
        }
        _isLoading = false;
      });
    } else {
      final db = DatabaseHelper.instance;
      final attendanceData = await db.getChildAttendanceHistory(cid);
      final evaluationData = await db.getChildEvaluationHistory(cid);
      final feedbackData = await db.getFeedbackByChild(cid);
      final triangulationData = await db.getTriangulationHistory(cid);

      setState(() {
        _attendance = attendanceData.map((e) => AttendanceModel.fromMap(e)).toList();
        _evaluations = evaluationData.map((e) => EvaluationModel.fromMap(e)).toList();
        _feedback = feedbackData.map((e) => ParentFeedbackModel.fromMap(e)).toList();
        if (triangulationData.isNotEmpty) {
          _latestTriangulation = TriangulationModel.fromMap(triangulationData.first);
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Record: ${widget.child.firstName} ${widget.child.lastName}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Profile Information', Icons.person),
                    _buildProfileInfo(),
                    const SizedBox(height: 32),
                    
                    _buildSectionHeader('Latest Triangulation Status', Icons.psychology),
                    _buildTriangulationSummary(),
                    const SizedBox(height: 32),

                    DefaultTabController(
                      length: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Attendance', icon: Icon(Icons.calendar_month)),
                              Tab(text: 'Evaluations', icon: Icon(Icons.assignment)),
                              Tab(text: 'Parent Feedback', icon: Icon(Icons.family_restroom)),
                            ],
                          ),
                          SizedBox(
                            height: 400,
                            child: TabBarView(
                              children: [
                                _buildAttendanceList(),
                                _buildEvaluationList(),
                                _buildFeedbackList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 40,
          runSpacing: 16,
          children: [
            _infoItem('Child ID', widget.child.childId),
            _infoItem('Gender', widget.child.gender),
            _infoItem('Age', '${widget.child.age} yrs old'),
            _infoItem('Birthday', widget.child.birthDate),
            _infoItem('Teacher', widget.child.teacherName),
            _infoItem('Parent', widget.child.parentName),
            _infoItem('Address', widget.child.address),
          ],
        ),
      ),
    );
  }

  Widget _buildTriangulationSummary() {
    if (_latestTriangulation == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No triangulation analysis performed yet.')));
    }
    final status = _latestTriangulation!.developmentStatus;
    Color color = Colors.green;
    if (status == 'Needs Monitoring') color = Colors.orange;
    if (status == 'Needs Intervention') color = Colors.red;

    return Card(
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(side: BorderSide(color: color.withOpacity(0.2)), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Overall Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Date: ${_latestTriangulation!.generatedDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Divider(),
            const Text('Summary Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_latestTriangulation!.triangulatedSummary),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_attendance.isEmpty) return const Center(child: Text('No attendance records found.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _attendance.length,
      itemBuilder: (context, index) {
        final item = _attendance[index];
        final isPresent = item.status == 'Present';
        return ListTile(
          leading: Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? Colors.green : Colors.red),
          title: Text(item.attendanceDate),
          subtitle: Text('Time: ${item.attendanceTime}'),
          trailing: Text(item.status, style: TextStyle(fontWeight: FontWeight.bold, color: isPresent ? Colors.green : Colors.red)),
        );
      },
    );
  }

  Widget _buildEvaluationList() {
    if (_evaluations.isEmpty) return const Center(child: Text('No evaluation records found.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _evaluations.length,
      itemBuilder: (context, index) {
        final item = _evaluations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.domain, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Score: ${item.score} pts | ${item.remarks}'),
            trailing: Text(item.evaluationDate),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackList() {
    if (_feedback.isEmpty) return const Center(child: Text('No parent feedback found.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _feedback.length,
      itemBuilder: (context, index) {
        final item = _feedback[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('Observation: ${item.parentObservation}'),
            subtitle: Text('Assistance: ${item.assistanceLevel}\nNotes: ${item.notes}'),
            isThreeLine: true,
            trailing: Text(item.submissionDate, style: const TextStyle(fontSize: 10)),
          ),
        );
      },
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
