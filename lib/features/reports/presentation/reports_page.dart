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
  /// When embedded, this renders only the report content so it can live in a
  /// role dashboard instead of creating a second page/app bar.
  final bool embedded;
  final ChildModel? initialFilterChild;
  final bool showReferrals;

  const ReportsPage({
    super.key,
    this.embedded = false,
    this.initialFilterChild,
    this.showReferrals = true,
  });

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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedFilterChild = widget.initialFilterChild;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getAllChildren(),
        _repository.getDashboardStats(),
        _repository.getAttendanceReport(),
        _repository.getEvaluationReport(),
        _repository.getReferralReport(),
        _repository.getChildProgressReport(),
      ]);
      if (!mounted) return;
      _allChildren = results[0] as List<ChildModel>;
      _setReportItems(
        results[2] as List<AttendanceReportItem>,
        results[3] as List<EvaluationReportItem>,
        results[4] as List<ReferralReportItem>,
        results[5] as List<ChildProgressReportItem>,
      );
      setState(() {
        _stats = results[1] as DashboardStats;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'Unable to load reports. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applyFilters() async {
    final reports = await Future.wait([
      _repository.getAttendanceReport(),
      _repository.getEvaluationReport(),
      _repository.getReferralReport(),
      _repository.getChildProgressReport(),
    ]);
    if (!mounted) return;
    _setReportItems(
      reports[0] as List<AttendanceReportItem>,
      reports[1] as List<EvaluationReportItem>,
      reports[2] as List<ReferralReportItem>,
      reports[3] as List<ChildProgressReportItem>,
    );
  }

  void _setReportItems(
    List<AttendanceReportItem> attendance,
    List<EvaluationReportItem> evaluations,
    List<ReferralReportItem> referrals,
    List<ChildProgressReportItem> progress,
  ) {
    setState(() {
      if (_selectedFilterChild != null) {
        _attendanceItems = attendance
            .where((item) => item.childId == _selectedFilterChild!.childId)
            .toList();
        _evaluationItems = evaluations
            .where((item) => item.childId == _selectedFilterChild!.childId)
            .toList();
        _referralItems = referrals
            .where((item) => item.childId == _selectedFilterChild!.childId)
            .toList();
        _progressItems = progress
            .where((item) => item.childId == _selectedFilterChild!.childId)
            .toList();
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
    final tabs = <Tab>[
      const Tab(text: 'Progress'),
      const Tab(text: 'Attendance'),
      const Tab(text: 'Evaluations'),
      if (widget.showReferrals) const Tab(text: 'Referrals'),
    ];
    final reports = <Widget>[
      _buildReportTab(
        'Progress Summary',
        'Progress',
        ChildProgressReportTable(items: _progressItems),
      ),
      _buildReportTab(
        'Attendance Summary',
        'Attendance',
        AttendanceReportTable(items: _attendanceItems),
      ),
      _buildReportTab(
        'Evaluation Summary',
        'Evaluation',
        EvaluationReportTable(items: _evaluationItems),
      ),
      if (widget.showReferrals)
        _buildReportTab(
          'Referral Summary',
          'Referral',
          ReferralReportTable(items: _referralItems),
        ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: widget.embedded
          ? Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                TabBar(isScrollable: true, tabs: tabs),
                Expanded(child: _buildReportContent(reports)),
              ],
            )
          : Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Reports & Analytics'),
                bottom: TabBar(isScrollable: true, tabs: tabs),
              ),
              body: _buildReportContent(reports),
            ),
    );
  }

  Widget _buildReportContent(List<Widget> reports) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    return TabBarView(children: reports);
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Statistics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                'Total Children',
                _stats?.totalChildren.toString() ?? '0',
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                'Present Today',
                _stats?.presentToday.toString() ?? '0',
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatCard(
                'Absent Today',
                _stats?.absentToday.toString() ?? '0',
                Icons.cancel,
                Colors.red,
              ),
              _buildStatCard(
                'Evaluations',
                _stats?.completedEvaluations.toString() ?? '0',
                Icons.assignment,
                Colors.orange,
              ),
              _buildStatCard(
                'Pending Referrals',
                _stats?.pendingReferrals.toString() ?? '0',
                Icons.warning,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Quick Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ChildModel?>(
            initialValue: _selectedFilterChild,
            decoration: const InputDecoration(
              labelText: 'Filter by Child',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Children')),
              ..._allChildren.map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text("${c.firstName} ${c.lastName}"),
                ),
              ),
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _exportReport(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparing $type report for export...')),
    );
  }

  Widget _buildReportTab(String title, String exportType, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (MediaQuery.sizeOf(context).width < 520)
                IconButton(
                  tooltip: 'Export CSV',
                  onPressed: () => _exportReport(exportType),
                  icon: const Icon(Icons.download_rounded),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _exportReport(exportType),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export CSV'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(clipBehavior: Clip.antiAlias, child: content),
          ),
        ],
      ),
    );
  }
}
