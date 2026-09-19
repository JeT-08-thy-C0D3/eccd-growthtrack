import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/reports_model.dart';
import '../../reports/presentation/widgets/attendance_report.dart';
import '../../reports/presentation/widgets/evaluation_report.dart';
import '../../reports/presentation/widgets/referral_report.dart';
import '../../reports/presentation/widgets/child_progress_report.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
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

  void _exportReport(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparing $type Report for export...')),
    );
    // In a real implementation, this would generate PDF or CSV
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Municipal Reports & Analytics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard_customize)),
              Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
              Tab(text: 'Attendance', icon: Icon(Icons.calendar_month)),
              Tab(text: 'Evaluations', icon: Icon(Icons.assignment)),
              Tab(text: 'Referrals', icon: Icon(Icons.assignment_late)),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _exportReport('Complete Statistical'),
              icon: const Icon(Icons.download),
              label: const Text('Export Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
            const SizedBox(width: 12),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildOverviewTab(),
                  _buildReportTab('Longitudinal Progress', ChildProgressReportTable(items: _progressItems), 'Progress'),
                  _buildReportTab('Attendance Analysis', AttendanceReportTable(items: _attendanceItems), 'Attendance'),
                  _buildReportTab('Evaluation Data', EvaluationReportTable(items: _evaluationItems), 'Evaluation'),
                  _buildReportTab('Referral Monitoring', ReferralReportTable(items: _referralItems), 'Referral'),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterPanel(),
          const SizedBox(height: 32),
          Text(
            'System Statistics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStatsCards(),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Progress Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _exportReport('Summary'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Print PDF Summary'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ChildProgressReportTable(items: _progressItems),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined, color: Colors.blue),
            const SizedBox(width: 12),
            const Text('Filter Reports:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 24),
            Expanded(
              child: DropdownButtonFormField<ChildModel?>(
                value: _selectedFilterChild,
                decoration: const InputDecoration(
                  labelText: 'Filter by Specific Child',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Show All Municipal Records')),
                  ..._allChildren.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName} (${c.childId})"))),
                ],
                onChanged: (val) {
                  setState(() => _selectedFilterChild = val);
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _selectedFilterChild = null);
                _applyFilters();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 2,
      children: [
        _buildStatCard('Total Children', _stats?.totalChildren.toString() ?? '0', Icons.people, Colors.blue),
        _buildStatCard('Present Today', _stats?.presentToday.toString() ?? '0', Icons.check_circle, Colors.green),
        _buildStatCard('Pending Referrals', _stats?.pendingReferrals.toString() ?? '0', Icons.warning, Colors.red),
        _buildStatCard('Completed Evaluations', _stats?.completedEvaluations.toString() ?? '0', Icons.assignment, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab(String title, Widget content, String exportType) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () => _exportReport(exportType),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: Card(child: content)),
        ],
      ),
    );
  }
}
