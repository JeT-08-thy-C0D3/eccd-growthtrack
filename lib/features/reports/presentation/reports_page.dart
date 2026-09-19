import 'package:flutter/material.dart';
import 'package:eccd_growthtrack/shared/models/child_model.dart';
import 'package:eccd_growthtrack/core/database/database_helper.dart';
import '../data/reports_repository.dart';
import '../domain/reports_model.dart';
import 'widgets/attendance_report.dart';
import 'widgets/evaluation_report.dart';
import 'widgets/referral_report.dart';
import 'widgets/child_progress_report.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportsRepository _repository = ReportsRepositoryImpl();
  DashboardStats? _stats;
  List<AttendanceReportItem> _attendanceItems = [];
  List<EvaluationReportItem> _evaluationItems = [];
  List<ReferralReportItem> _referralItems = [];
  List<ChildProgressReportItem> _progressItems = [];
  
  List<ChildModel> _allChildren = [];
  ChildModel? _selectedFilterChild;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _allChildren = await DatabaseHelper.instance.getAllChildren();
    final stats = await _repository.getDashboardStats();
    
    await _applyFilters();

    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _applyFilters() async {
    final attendance = await _repository.getAttendanceReport();
    final evaluations = await _repository.getEvaluationReport();
    final referrals = await _repository.getReferralReport();
    final progress = await _repository.getChildProgressReport();

    setState(() {
      if (_selectedFilterChild != null) {
        _attendanceItems = attendance.where((item) => item.childId == _selectedFilterChild!.childId).toList();
        _evaluationItems = evaluations.where((item) => item.childId == _selectedFilterChild!.childId).toList();
        _referralItems = referrals.where((item) => item.childId == _selectedFilterChild!.childId).toList();
        _progressItems = progress.where((item) => item.childId == _selectedFilterChild!.childId).toList();
      } else {
        _attendanceItems = attendance;
        _evaluationItems = evaluations;
        _referralItems = referrals;
        _progressItems = progress;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Progress'),
              Tab(text: 'Attendance'),
              Tab(text: 'Evaluations'),
              Tab(text: 'Referrals'),
            ],
          ),
          actions: [
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDashboard(),
                  _buildReportTab('Progress Summary', ChildProgressReportTable(items: _progressItems)),
                  _buildReportTab('Attendance Summary', AttendanceReportTable(items: _attendanceItems)),
                  _buildReportTab('Evaluation Summary', EvaluationReportTable(items: _evaluationItems)),
                  _buildReportTab('Referral Summary', ReferralReportTable(items: _referralItems)),
                ],
              ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Key Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard('Total Children', _stats?.totalChildren.toString() ?? '0', Icons.people, Colors.blue),
              _buildStatCard('Present Today', _stats?.presentToday.toString() ?? '0', Icons.check_circle, Colors.green),
              _buildStatCard('Absent Today', _stats?.absentToday.toString() ?? '0', Icons.cancel, Colors.red),
              _buildStatCard('Evaluations', _stats?.completedEvaluations.toString() ?? '0', Icons.assignment, Colors.orange),
              _buildStatCard('Pending Referrals', _stats?.pendingReferrals.toString() ?? '0', Icons.warning, Colors.purple),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Quick Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<ChildModel?>(
            value: _selectedFilterChild,
            decoration: const InputDecoration(labelText: 'Filter by Child', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Children')),
              ..._allChildren.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName}"))),
            ],
            onChanged: (val) {
              setState(() => _selectedFilterChild = val);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(child: content),
        ],
      ),
    );
  }
}
