import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../data/repositories/audit_repository.dart';
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
  final TextEditingController _searchController = TextEditingController();
  DashboardStats? _stats;
  List<AttendanceReportItem> _attendanceItems = [];
  List<EvaluationReportItem> _evaluationItems = [];
  List<ReferralReportItem> _referralItems = [];
  List<ChildProgressReportItem> _progressItems = [];
  
  List<ChildModel> _allChildren = [];
  ChildModel? _selectedFilterChild;
  String _searchQuery = '';
  bool _isLoading = true;

  static const int _itemsPerPage = 10;
  int _progressPage = 0;
  int _attendancePage = 0;
  int _evaluationPage = 0;
  int _referralPage = 0;

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

    final q = _searchQuery.toLowerCase();

    setState(() {
      _attendanceItems = attendance.where((item) {
        final matchesChild = _selectedFilterChild == null || item.childId == _selectedFilterChild!.childId;
        final matchesQuery = q.isEmpty || item.childName.toLowerCase().contains(q) || item.childId.toLowerCase().contains(q);
        return matchesChild && matchesQuery;
      }).toList();

      _evaluationItems = evaluations.where((item) {
        final matchesChild = _selectedFilterChild == null || item.childId == _selectedFilterChild!.childId;
        final matchesQuery = q.isEmpty || item.childName.toLowerCase().contains(q) || item.domain.toLowerCase().contains(q);
        return matchesChild && matchesQuery;
      }).toList();

      _referralItems = referrals.where((item) {
        final matchesChild = _selectedFilterChild == null || item.childId == _selectedFilterChild!.childId;
        final matchesQuery = q.isEmpty || item.childName.toLowerCase().contains(q) || item.concern.toLowerCase().contains(q) || item.status.toLowerCase().contains(q);
        return matchesChild && matchesQuery;
      }).toList();

      _progressItems = progress.where((item) {
        final matchesChild = _selectedFilterChild == null || item.childId == _selectedFilterChild!.childId;
        final matchesQuery = q.isEmpty || item.childName.toLowerCase().contains(q) || item.domain.toLowerCase().contains(q);
        return matchesChild && matchesQuery;
      }).toList();

      _progressPage = 0;
      _attendancePage = 0;
      _evaluationPage = 0;
      _referralPage = 0;
    });
  }

  void _exportReport(String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparing $type Report for export...')),
    );
    await AuditRepository().logAction(
      action: 'Report Generated',
      targetRecord: '$type Report',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Municipal Reports & Analytics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
              Tab(text: 'Attendance', icon: Icon(Icons.calendar_month)),
              Tab(text: 'Evaluations', icon: Icon(Icons.assignment)),
              Tab(text: 'Referrals', icon: Icon(Icons.assignment_late)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildProgressTab(),
                  _buildAttendanceTab(),
                  _buildEvaluationTab(),
                  _buildReferralTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final paginatedProgress = _progressItems.skip(0).take(_itemsPerPage).toList();

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                'Recent Progress Summary (Top 10)',
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
          ChildProgressReportTable(items: paginatedProgress),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    final totalItems = _progressItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final paginatedItems = _progressItems.skip(_progressPage * _itemsPerPage).take(_itemsPerPage).toList();

    return _buildReportTabWrapper(
      title: 'Longitudinal Progress',
      exportType: 'Progress',
      content: ChildProgressReportTable(items: paginatedItems),
      currentPage: _progressPage,
      totalPages: totalPages,
      totalItems: totalItems,
      alwaysShowPagination: true,
      onPageChanged: (newPage) => setState(() => _progressPage = newPage),
    );
  }

  Widget _buildAttendanceTab() {
    final totalItems = _attendanceItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final paginatedItems = _attendanceItems.skip(_attendancePage * _itemsPerPage).take(_itemsPerPage).toList();

    return _buildReportTabWrapper(
      title: 'Attendance Analysis',
      exportType: 'Attendance',
      content: AttendanceReportTable(items: paginatedItems),
      currentPage: _attendancePage,
      totalPages: totalPages,
      totalItems: totalItems,
      onPageChanged: (newPage) => setState(() => _attendancePage = newPage),
    );
  }

  Widget _buildEvaluationTab() {
    final totalItems = _evaluationItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final paginatedItems = _evaluationItems.skip(_evaluationPage * _itemsPerPage).take(_itemsPerPage).toList();

    return _buildReportTabWrapper(
      title: 'Evaluation Data',
      exportType: 'Evaluation',
      content: EvaluationReportTable(items: paginatedItems),
      currentPage: _evaluationPage,
      totalPages: totalPages,
      totalItems: totalItems,
      onPageChanged: (newPage) => setState(() => _evaluationPage = newPage),
    );
  }

  Widget _buildReferralTab() {
    final totalItems = _referralItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final paginatedItems = _referralItems.skip(_referralPage * _itemsPerPage).take(_itemsPerPage).toList();

    return _buildReportTabWrapper(
      title: 'Referral Monitoring',
      exportType: 'Referral',
      content: ReferralReportTable(items: paginatedItems),
      currentPage: _referralPage,
      totalPages: totalPages,
      totalItems: totalItems,
      onPageChanged: (newPage) => setState(() => _referralPage = newPage),
    );
  }

  Widget _buildReportTabWrapper({
    required String title,
    required String exportType,
    required Widget content,
    required int currentPage,
    required int totalPages,
    required int totalItems,
    bool alwaysShowPagination = false,
    required ValueChanged<int> onPageChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(child: content),
                  _buildPaginationBar(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    totalItems: totalItems,
                    onPageChanged: onPageChanged,
                    alwaysShow: alwaysShowPagination,
                  ),
                ],
              ),
            ),
          ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = SearchBar(
              controller: _searchController,
              hintText: 'Search report data by child name, ID, or domain...',
              leading: const Icon(Icons.search),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
            );
            final filter = DropdownButtonFormField<ChildModel?>(
              initialValue: _selectedFilterChild,
              decoration: const InputDecoration(
                labelText: 'Filter child',
                prefixIcon: Icon(Icons.filter_alt_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All children')),
                ..._allChildren.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName} (${c.childId})"))),
              ],
              onChanged: (val) {
                setState(() => _selectedFilterChild = val);
                _applyFilters();
              },
            );
            final reset = IconButton(
              tooltip: 'Reset filters',
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                setState(() => _selectedFilterChild = null);
                _applyFilters();
              },
              icon: const Icon(Icons.clear_all),
            );
            if (constraints.maxWidth < 760) {
              return Column(children: [search, const SizedBox(height: 10), Row(children: [Expanded(child: filter), reset])]);
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 16), SizedBox(width: 280, child: filter), reset]);
          },
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

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required ValueChanged<int> onPageChanged,
    bool alwaysShow = false,
  }) {
    if (totalItems == 0 && !alwaysShow) return const SizedBox.shrink();

    final startItem = totalItems == 0 ? 0 : (currentPage * _itemsPerPage) + 1;
    final endItem = ((currentPage + 1) * _itemsPerPage) > totalItems
        ? totalItems
        : (currentPage + 1) * _itemsPerPage;
    final displayTotalPages = totalPages == 0 ? 1 : totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            'Showing $startItem - $endItem of $totalItems report items',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                tooltip: 'Previous Page',
              ),
              Text(
                'Page ${currentPage + 1} of $displayTotalPages',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage + 1 < displayTotalPages ? () => onPageChanged(currentPage + 1) : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
