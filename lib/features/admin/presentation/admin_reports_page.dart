import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/csv_downloader.dart';
import '../../../shared/widgets/brand_widgets.dart';
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
  List<AttendanceReportItem> _allAttendanceItems = [];
  List<EvaluationReportItem> _allEvaluationItems = [];
  List<ReferralReportItem> _allReferralItems = [];
  List<ChildProgressReportItem> _allProgressItems = [];

  List<ChildModel> _allChildren = [];
  ChildModel? _selectedFilterChild;
  String _selectedSectionFilter = 'All Sections';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _loadError;

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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final initialData = await Future.wait([
        _loadOrFallback(
          () => DatabaseHelper.instance.getAllChildren(),
          <ChildModel>[],
        ),
        _loadOrFallback(
          _repository.getDashboardStats,
          DashboardStats(
            totalChildren: 0,
            totalTeachers: 0,
            totalParents: 0,
            presentToday: 0,
            absentToday: 0,
            completedEvaluations: 0,
            pendingReferrals: 0,
          ),
        ),
      ]);
      if (!mounted) return;
      _allChildren = initialData[0] as List<ChildModel>;
      _stats = initialData[1] as DashboardStats;
      final reports = await Future.wait([
        _loadOrFallback(
          _repository.getAttendanceReport,
          <AttendanceReportItem>[],
        ),
        _loadOrFallback(
          _repository.getEvaluationReport,
          <EvaluationReportItem>[],
        ),
        _loadOrFallback(_repository.getReferralReport, <ReferralReportItem>[]),
        _loadOrFallback(
          _repository.getChildProgressReport,
          <ChildProgressReportItem>[],
        ),
      ]);
      if (!mounted) return;
      _allAttendanceItems = reports[0] as List<AttendanceReportItem>;
      _allEvaluationItems = reports[1] as List<EvaluationReportItem>;
      _allReferralItems = reports[2] as List<ReferralReportItem>;
      _allProgressItems = reports[3] as List<ChildProgressReportItem>;
      _applyFilters();
      if (mounted) setState(() => _isLoading = false);
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

  void _applyFilters() {
    final q = _searchQuery.toLowerCase();
    final sectionChildIds = _selectedSectionFilter == 'All Sections'
        ? null
        : _allChildren
              .where((child) => child.section.label == _selectedSectionFilter)
              .map((child) => child.childId)
              .toSet();

    bool matchesSelectedSection(String childId) =>
        sectionChildIds == null || sectionChildIds.contains(childId);

    setState(() {
      _attendanceItems = _allAttendanceItems.where((item) {
        final matchesChild =
            _selectedFilterChild == null ||
            item.childId == _selectedFilterChild!.childId;
        final matchesQuery =
            q.isEmpty ||
            item.childName.toLowerCase().contains(q) ||
            item.childId.toLowerCase().contains(q);
        return matchesChild &&
            matchesQuery &&
            matchesSelectedSection(item.childId);
      }).toList();

      _evaluationItems = _allEvaluationItems.where((item) {
        final matchesChild =
            _selectedFilterChild == null ||
            item.childId == _selectedFilterChild!.childId;
        final matchesQuery =
            q.isEmpty ||
            item.childName.toLowerCase().contains(q) ||
            item.domain.toLowerCase().contains(q);
        return matchesChild &&
            matchesQuery &&
            matchesSelectedSection(item.childId);
      }).toList();

      _referralItems = _allReferralItems.where((item) {
        final matchesChild =
            _selectedFilterChild == null ||
            item.childId == _selectedFilterChild!.childId;
        final matchesQuery =
            q.isEmpty ||
            item.childName.toLowerCase().contains(q) ||
            item.concern.toLowerCase().contains(q) ||
            item.status.toLowerCase().contains(q);
        return matchesChild &&
            matchesQuery &&
            matchesSelectedSection(item.childId);
      }).toList();

      _progressItems = _allProgressItems.where((item) {
        final matchesChild =
            _selectedFilterChild == null ||
            item.childId == _selectedFilterChild!.childId;
        final matchesQuery =
            q.isEmpty ||
            item.childName.toLowerCase().contains(q) ||
            item.domain.toLowerCase().contains(q);
        return matchesChild &&
            matchesQuery &&
            matchesSelectedSection(item.childId);
      }).toList();

      _progressPage = 0;
      _attendancePage = 0;
      _evaluationPage = 0;
      _referralPage = 0;
    });
  }

  Future<T> _loadOrFallback<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _exportReport(String type) async {
    final child = _selectedFilterChild;
    if (child == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select one child first. CSV exports are per child.'),
        ),
      );
      return;
    }

    final rows = _csvRowsFor(type, child.childId);
    if (rows.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No $type records found for ${child.firstName}.'),
        ),
      );
      return;
    }

    final contents = rows.map(_csvLine).join('\r\n');
    final childFileName =
        '${child.firstName}_${child.lastName}_${child.childId}'.replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );
    final fileName = '${type.toLowerCase()}_$childFileName.csv';

    try {
      await downloadCsv(fileName: fileName, contents: contents);
      try {
        await AuditRepository().logAction(
          action: 'Report Exported',
          targetRecord: '$type Report: ${child.childId}',
        );
      } catch (_) {
        // A successful download remains valid if audit logging is temporarily
        // unavailable.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type CSV downloaded for ${child.firstName}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV download could not be started.')),
      );
    }
  }

  List<List<String>> _csvRowsFor(String type, String childId) {
    switch (type) {
      case 'Progress':
        final progressItems = _allProgressItems
            .where((item) => item.childId == childId)
            .toList();
        final summaryChunks = _summaryChunks(
          progressItems
              .map((item) => item.triangulatedSummary)
              .firstWhere(
                (summary) => summary?.trim().isNotEmpty ?? false,
                orElse: () => null,
              ),
        );
        final rowCount = progressItems.length > summaryChunks.length
            ? progressItems.length
            : summaryChunks.length;
        return [
          [
            'Child ID',
            'Child Name',
            'Domain',
            'Previous Score',
            'Current Score',
            'Max Score',
            'Development Status',
            'Triangulated Summary (continued by row)',
          ],
          ...List.generate(rowCount, (index) {
            final item = index < progressItems.length
                ? progressItems[index]
                : null;
            return [
              item?.childId ?? '',
              item?.childName ?? '',
              item?.domain ?? '',
              item?.previousScore?.toString() ?? '',
              item?.currentScore.toString() ?? '',
              item?.maxScore.toString() ?? '',
              item?.developmentStatus ?? '',
              index < summaryChunks.length ? summaryChunks[index] : '',
            ];
          }),
        ];
      case 'Attendance':
        return [
          ['Child ID', 'Child Name', 'Present', 'Absent', 'Attendance Rate'],
          ..._allAttendanceItems
              .where((item) => item.childId == childId)
              .map(
                (item) => [
                  item.childId,
                  item.childName,
                  item.present.toString(),
                  item.absent.toString(),
                  '${item.attendanceRate.toStringAsFixed(1)}%',
                ],
              ),
        ];
      case 'Evaluation':
        return [
          ['Child ID', 'Child Name', 'Domain', 'Score', 'Date', 'Remarks'],
          ..._allEvaluationItems
              .where((item) => item.childId == childId)
              .map(
                (item) => [
                  item.childId,
                  item.childName,
                  item.domain,
                  item.score.toString(),
                  item.date,
                  item.remarks,
                ],
              ),
        ];
      case 'Referral':
        return [
          [
            'Child ID',
            'Child Name',
            'Concern',
            'Referral Date',
            'Follow-Up Date',
            'Status',
          ],
          ..._allReferralItems
              .where((item) => item.childId == childId)
              .map(
                (item) => [
                  item.childId,
                  item.childName,
                  item.concern,
                  item.referralDate,
                  item.followUpDate,
                  item.status,
                ],
              ),
        ];
      default:
        return const [];
    }
  }

  String _csvLine(List<String> values) =>
      values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');

  List<String> _summaryChunks(String? summary) {
    final normalized = summary?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (normalized.isEmpty) return const [];

    // Keep each spreadsheet cell readable while retaining every word.
    const maximumCharactersPerRow = 80;
    final chunks = <String>[];
    var current = '';

    for (var word in normalized.split(' ')) {
      while (word.length > maximumCharactersPerRow) {
        if (current.isNotEmpty) {
          chunks.add(current);
          current = '';
        }
        chunks.add(word.substring(0, maximumCharactersPerRow));
        word = word.substring(maximumCharactersPerRow);
      }

      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > maximumCharactersPerRow && current.isNotEmpty) {
        chunks.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }

    if (current.isNotEmpty) chunks.add(current);
    return chunks;
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
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                28,
                MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                0,
              ),
              child: _buildReportsHero(),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
                Tab(text: 'Attendance', icon: Icon(Icons.calendar_month)),
                Tab(text: 'Evaluations', icon: Icon(Icons.assignment)),
                Tab(text: 'Referrals', icon: Icon(Icons.assignment_late)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: _buildFilterPanel(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color: Colors.orange,
                          ),
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
                    )
                  : TabBarView(
                      children: [
                        _buildProgressTab(),
                        _buildAttendanceTab(),
                        _buildEvaluationTab(),
                        _buildReferralTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsHero() {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final icon = Container(
      width: compact ? 58 : 68,
      height: compact ? 58 : 68,
      decoration: BoxDecoration(
        color: const Color(0xFF168CF0),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
      ),
      child: Icon(
        Icons.bar_chart_rounded,
        color: Colors.white,
        size: compact ? 34 : 40,
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Municipal Reports & Analytics',
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: const Color(0xFF0D1A5B),
            fontSize: compact ? 28 : 32,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Track progress, attendance, evaluation results, and referrals across the municipality.',
          maxLines: compact ? 3 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: const Color(0xFF386296),
            fontSize: compact ? 14 : 15,
            height: 1.35,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      height: compact ? 258 : 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE1F2FF), Color(0xFFF7FCFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          if (!compact)
            Positioned(
              right: 42,
              bottom: 16,
              child: Container(
                width: 224,
                height: 106,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .56),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Color(0x143A82B8), blurRadius: 18),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.show_chart_rounded,
                      color: BrandColors.sky,
                      size: 62,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _reportBar(32, const Color(0xFF83D6E7)),
                            _reportBar(54, BrandColors.sky),
                            _reportBar(42, const Color(0xFF59CBA2)),
                            _reportBar(68, BrandColors.sunshine),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: compact ? 24 : 30,
            top: compact ? 24 : 30,
            right: compact ? 24 : 250,
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [icon, const SizedBox(height: 14), text],
                  )
                : Row(
                    children: [
                      icon,
                      const SizedBox(width: 22),
                      Expanded(child: text),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _reportBar(double height, Color color) => Container(
    width: 12,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Retained for the existing overview route, which can be enabled separately
  // from the four report tabs without changing its report layout.
  // ignore: unused_element
  Widget _buildOverviewTab() {
    final paginatedProgress = _progressItems
        .skip(0)
        .take(_itemsPerPage)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterPanel(),
          const SizedBox(height: 32),
          Text(
            'System Statistics',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
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
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
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
    final paginatedItems = _progressItems
        .skip(_progressPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return _buildReportTabWrapper(
      title: 'Longitudinal Progress',
      exportType: 'Progress',
      content: ChildProgressReportTable(
        items: paginatedItems,
        showScrollbars: true,
      ),
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
    final paginatedItems = _attendanceItems
        .skip(_attendancePage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return _buildReportTabWrapper(
      title: 'Attendance Analysis',
      exportType: 'Attendance',
      content: AttendanceReportTable(
        items: paginatedItems,
        showScrollbars: true,
      ),
      currentPage: _attendancePage,
      totalPages: totalPages,
      totalItems: totalItems,
      onPageChanged: (newPage) => setState(() => _attendancePage = newPage),
    );
  }

  Widget _buildEvaluationTab() {
    final totalItems = _evaluationItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final paginatedItems = _evaluationItems
        .skip(_evaluationPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return _buildReportTabWrapper(
      title: 'Evaluation Data',
      exportType: 'Evaluation',
      content: EvaluationReportTable(
        items: paginatedItems,
        showScrollbars: true,
      ),
      currentPage: _evaluationPage,
      totalPages: totalPages,
      totalItems: totalItems,
      onPageChanged: (newPage) => setState(() => _evaluationPage = newPage),
    );
  }

  Widget _buildReferralTab() {
    final totalItems = _referralItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final paginatedItems = _referralItems
        .skip(_referralPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return _buildReportTabWrapper(
      title: 'Referral Monitoring',
      exportType: 'Referral',
      content: ReferralReportTable(items: paginatedItems, showScrollbars: true),
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
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final canExport = _selectedFilterChild != null;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        if (MediaQuery.sizeOf(context).width < 520)
          IconButton(
            tooltip: 'Export CSV',
            onPressed: canExport ? () => _exportReport(exportType) : null,
            icon: const Icon(Icons.download_rounded),
          )
        else
          OutlinedButton.icon(
            onPressed: canExport ? () => _exportReport(exportType) : null,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export CSV'),
          ),
      ],
    );
    final reportCard = LayoutBuilder(
      builder: (context, constraints) => FractionallySizedBox(
        widthFactor: constraints.maxWidth >= 900 ? .82 : 1,
        heightFactor: 1,
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
    );

    // The hero and filters use most of a phone's height.  Let this area
    // scroll instead of forcing the report card into the remaining space.
    if (isCompact) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            SizedBox(height: 360, child: reportCard),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 24),
          Expanded(child: Center(child: reportCard)),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final selectableChildren = _selectedSectionFilter == 'All Sections'
                ? _allChildren
                : _allChildren
                      .where(
                        (child) =>
                            child.section.label == _selectedSectionFilter,
                      )
                      .toList();
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
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter child',
                prefixIcon: Icon(Icons.filter_alt_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All children'),
                ),
                ...selectableChildren.map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text("${c.firstName} ${c.lastName} (${c.childId})"),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedFilterChild = val);
                _applyFilters();
              },
            );
            final sectionFilter = DropdownButtonFormField<String>(
              initialValue: _selectedSectionFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Section category',
                prefixIcon: Icon(Icons.groups_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: 'All Sections',
                  child: Text('All sections'),
                ),
                ...ChildSection.values.map(
                  (section) => DropdownMenuItem(
                    value: section.label,
                    child: Text('${section.label} (${section.ageRange})'),
                  ),
                ),
              ],
              onChanged: (val) {
                final section = val ?? 'All Sections';
                setState(() {
                  _selectedSectionFilter = section;
                  final selectedChild = _selectedFilterChild;
                  if (selectedChild != null &&
                      section != 'All Sections' &&
                      selectedChild.section.label != section) {
                    _selectedFilterChild = null;
                  }
                });
                _applyFilters();
              },
            );
            final reset = IconButton(
              tooltip: 'Reset filters',
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                setState(() {
                  _selectedFilterChild = null;
                  _selectedSectionFilter = 'All Sections';
                });
                _applyFilters();
              },
              icon: const Icon(Icons.clear_all),
            );
            // Keep the controls from competing for horizontal space.  The
            // dropdowns have long section/child labels, so stack them before
            // the row becomes cramped instead of allowing a RenderFlex
            // overflow.
            if (constraints.maxWidth < 1040) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: filter),
                      const SizedBox(width: 10),
                      reset,
                    ],
                  ),
                  const SizedBox(height: 10),
                  sectionFilter,
                  const SizedBox(height: 8),
                  _buildPerChildExportHint(),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 16),
                SizedBox(width: 270, child: sectionFilter),
                const SizedBox(width: 12),
                SizedBox(
                  width: 280,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [filter, _buildPerChildExportHint()],
                  ),
                ),
                reset,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPerChildExportHint() => Text(
    _selectedFilterChild == null
        ? 'Select a child to enable per-child CSV export.'
        : 'CSV exports include only the selected child.',
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 2,
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
          'Pending Referrals',
          _stats?.pendingReferrals.toString() ?? '0',
          Icons.warning,
          Colors.red,
        ),
        _buildStatCard(
          'Completed Evaluations',
          _stats?.completedEvaluations.toString() ?? '0',
          Icons.assignment,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            'Showing $startItem - $endItem of $totalItems report items',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'Previous Page',
              ),
              Text(
                'Page ${currentPage + 1} of $displayTotalPages',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage + 1 < displayTotalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
