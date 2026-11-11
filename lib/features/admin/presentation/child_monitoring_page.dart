import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../attendance/domain/attendance_model.dart';
import '../../eccd_evaluation/domain/evaluation_model.dart';
import '../../parent/domain/parent_feedback_model.dart';
import '../../triangulation/domain/triangulation_model.dart';
import '../../../shared/widgets/brand_widgets.dart';

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
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();
  String _searchQuery = '';
  String _selectedGenderFilter = 'All';
  String _selectedSectionFilter = 'All Sections';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);

    if (kIsWeb) {
      final snapshot = await _firestore.collection('children').get();
      _children = snapshot.docs
          .map((doc) => ChildModel.fromMap(doc.data()))
          .toList();
    } else {
      _children = await DatabaseHelper.instance.getAllChildren();
    }

    _applyFilterAndSort();
    setState(() => _isLoading = false);
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredChildren = _children.where((child) {
        final matchesSearch =
            child.firstName.toLowerCase().contains(q) ||
            child.lastName.toLowerCase().contains(q) ||
            child.childId.toLowerCase().contains(q) ||
            child.teacherName.toLowerCase().contains(q) ||
            child.parentName.toLowerCase().contains(q);

        final matchesGender =
            _selectedGenderFilter == 'All' ||
            child.gender.toLowerCase() == _selectedGenderFilter.toLowerCase();
        final matchesSection =
            _selectedSectionFilter == 'All Sections' ||
            child.section.label == _selectedSectionFilter;

        return matchesSearch && matchesGender && matchesSection;
      }).toList();

      if (_sortColumnIndex != null) {
        _filteredChildren.sort((a, b) {
          int result = 0;
          switch (_sortColumnIndex) {
            case 0:
              final nameA = "${a.firstName} ${a.lastName}".toLowerCase();
              final nameB = "${b.firstName} ${b.lastName}".toLowerCase();
              result = nameA.compareTo(nameB);
              break;
            case 1:
              result = a.childId.toLowerCase().compareTo(
                b.childId.toLowerCase(),
              );
              break;
            case 2:
              result = a.age.compareTo(b.age);
              break;
            case 3:
              result = a.section.label.compareTo(b.section.label);
              break;
            case 4:
              result = a.gender.compareTo(b.gender);
              break;
            case 5:
              result = a.teacherName.toLowerCase().compareTo(
                b.teacherName.toLowerCase(),
              );
              break;
            case 6:
              result = a.parentName.toLowerCase().compareTo(
                b.parentName.toLowerCase(),
              );
              break;
          }
          return _sortAscending ? result : -result;
        });
      }
    });
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyFilterAndSort();
    });
  }

  void _viewChildDetails(ChildModel child) {
    showDialog(
      context: context,
      builder: (context) => _ChildDetailDialog(child: child),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;
    final isPhone = MediaQuery.sizeOf(context).width < 700;
    final totalItems = _filteredChildren.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final paginatedChildren = _filteredChildren
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    if (isPhone) {
      return Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
                      child: _buildChildHero(),
                    ),
                    _buildSearchAndFilterBar(),
                    if (_filteredChildren.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No matching child records found.'),
                      )
                    else ...[
                      _buildResponsiveList(paginatedChildren, false),
                      _buildPaginationControls(totalItems, totalPages),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
              28,
              MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
              10,
            ),
            child: _buildChildHero(),
          ),
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChildren.isEmpty
                ? const Center(child: Text('No matching child records found.'))
                : Column(
                    children: [
                      Expanded(
                        child: _buildResponsiveList(paginatedChildren, isWide),
                      ),
                      _buildPaginationControls(totalItems, totalPages),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildHero() {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final icon = Container(
      width: compact ? 58 : 68,
      height: compact ? 58 : 68,
      decoration: BoxDecoration(
        color: const Color(0xFF168CF0),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
      ),
      child: Icon(
        Icons.child_friendly_rounded,
        color: Colors.white,
        size: compact ? 34 : 40,
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Child Monitoring & Case Review (Admin)',
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: const Color(0xFF0D1A5B),
            fontSize: compact ? 28 : 30,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Monitor children\'s profiles and review their cases and development status.',
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
      height: compact ? 258 : 164,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE1F2FF), Color(0xFFF7FCFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -65,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                color: BrandColors.sky.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (!compact)
            Positioned(
              right: 62,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    color: BrandColors.green.withValues(alpha: .78),
                    size: 100,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.child_care_rounded,
                    color: Colors.orange.shade200,
                    size: 105,
                  ),
                  Icon(
                    Icons.person_rounded,
                    color: Colors.blue.shade300,
                    size: 118,
                  ),
                ],
              ),
            ),
          Positioned(
            left: compact ? 24 : 30,
            top: compact ? 24 : 36,
            right: compact ? 24 : 410,
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

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = SearchBar(
            controller: _searchController,
            hintText: 'Search by name, child ID, teacher, or parent...',
            leading: const Icon(
              Icons.search_rounded,
              color: BrandColors.navy,
              size: 25,
            ),
            onChanged: (val) {
              _searchQuery = val;
              _currentPage = 0;
              _applyFilterAndSort();
            },
          );
          final filter = DropdownButtonFormField<String>(
            initialValue: _selectedGenderFilter,
            decoration: const InputDecoration(
              labelText: 'Filter gender',
              prefixIcon: Icon(Icons.filter_list),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All genders')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGenderFilter = value ?? 'All';
                _currentPage = 0;
              });
              _applyFilterAndSort();
            },
          );
          final sectionFilter = DropdownButtonFormField<String>(
            initialValue: _selectedSectionFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter section',
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
            onChanged: (value) {
              setState(() {
                _selectedSectionFilter = value ?? 'All Sections';
                _currentPage = 0;
              });
              _applyFilterAndSort();
            },
          );
          if (constraints.maxWidth < 680) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                filter,
                const SizedBox(height: 10),
                sectionFilter,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              SizedBox(width: 180, child: filter),
              const SizedBox(width: 12),
              SizedBox(width: 265, child: sectionFilter),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResponsiveList(List<ChildModel> paginatedChildren, bool isWide) {
    final embedded = MediaQuery.sizeOf(context).width < 700;
    if (isWide && kIsWeb) {
      return LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: const EdgeInsets.all(24),
          child: Scrollbar(
            controller: _tableVerticalController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.vertical,
            child: SingleChildScrollView(
              controller: _tableVerticalController,
              child: Scrollbar(
                controller: _tableHorizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _tableHorizontalController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 1120
                          ? 1120
                          : constraints.maxWidth,
                    ),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DataTable(
                        horizontalMargin: 16,
                        columnSpacing: 16,
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        columns: [
                          DataColumn(
                            label: const SizedBox(
                              width: 180,
                              child: Text(
                                'Child Name',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          DataColumn(
                            label: const SizedBox(
                              width: 130,
                              child: Text(
                                'Child ID',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          DataColumn(
                            label: const SizedBox(
                              width: 50,
                              child: Text(
                                'Age',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          DataColumn(
                            label: const SizedBox(
                              width: 100,
                              child: Text(
                                'Section',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          DataColumn(
                            label: const SizedBox(
                              width: 70,
                              child: Text(
                                'Gender',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          DataColumn(
                            label: const SizedBox(
                              width: 145,
                              child: Text(
                                'Teacher',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          DataColumn(
                            label: const SizedBox(
                              width: 165,
                              child: Text(
                                'Parent/Guardian',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSort: (index, ascending) =>
                                _sort(index, ascending),
                          ),
                          const DataColumn(
                            label: SizedBox(
                              width: 50,
                              child: Text(
                                'Action',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                        rows: paginatedChildren.map((child) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        child: Text(
                                          child.firstName[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${child.firstName} ${child.lastName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    child.childId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 50,
                                  child: Text('${child.age} yrs'),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    child.section.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    child.gender,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 145,
                                  child: Text(
                                    child.teacherName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 165,
                                  child: Text(
                                    child.parentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.analytics_outlined,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _viewChildDetails(child),
                                  tooltip: 'View Full Record & Case Assessment',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      itemCount: paginatedChildren.length,
      itemBuilder: (context, index) {
        final child = paginatedChildren[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(child.firstName[0].toUpperCase()),
            ),
            title: Text(
              '${child.firstName} ${child.lastName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'ID: ${child.childId} | ${child.section.label}\nTeacher: ${child.teacherName}',
            ),
            trailing: const Icon(Icons.analytics_outlined, color: Colors.blue),
            onTap: () => _viewChildDetails(child),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (_currentPage * _itemsPerPage) + 1;
    final endItem = ((_currentPage + 1) * _itemsPerPage) > totalItems
        ? totalItems
        : (_currentPage + 1) * _itemsPerPage;
    final displayTotalPages = totalPages == 0 ? 1 : totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem - $endItem of $totalItems children',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous Page',
              ),
              Text(
                'Page ${_currentPage + 1} of $displayTotalPages',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage + 1 < displayTotalPages
                    ? () => setState(() => _currentPage++)
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
  String? _loadWarning;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final String cid = widget.child.childId;

    if (kIsWeb) {
      final warnings = <String>[];
      var attendance = <AttendanceModel>[];
      var evaluations = <EvaluationModel>[];
      var feedback = <ParentFeedbackModel>[];
      TriangulationModel? triangulation;

      // Attendance is stored in attendance_events. Fetch every source
      // independently so one inaccessible or empty source cannot keep the
      // full-record screen loading forever.
      try {
        final snapshot = await _firestore
            .collection('attendance_events')
            .where('child_id', isEqualTo: cid)
            .get();
        attendance = snapshot.docs
            .map((document) => AttendanceModel.fromMap(document.data()))
            .toList();
      } catch (_) {
        warnings.add('attendance');
      }
      try {
        final snapshot = await _firestore
            .collection('evaluations')
            .where('child_id', isEqualTo: cid)
            .get();
        evaluations = snapshot.docs
            .map((document) => EvaluationModel.fromMap(document.data()))
            .toList();
      } catch (_) {
        warnings.add('evaluations');
      }
      try {
        final snapshot = await _firestore
            .collection('parent_feedback')
            .where('child_id', isEqualTo: cid)
            .get();
        feedback = snapshot.docs
            .map((document) => ParentFeedbackModel.fromMap(document.data()))
            .toList();
      } catch (_) {
        warnings.add('parent feedback');
      }
      try {
        final snapshot = await _firestore
            .collection('triangulations')
            .where('child_id', isEqualTo: cid)
            .get();
        final records =
            snapshot.docs
                .map((document) => TriangulationModel.fromMap(document.data()))
                .toList()
              ..sort((a, b) => b.generatedDate.compareTo(a.generatedDate));
        if (records.isNotEmpty) triangulation = records.first;
      } catch (_) {
        warnings.add('triangulation');
      }

      if (!mounted) return;
      setState(() {
        _attendance = attendance;
        _evaluations = evaluations;
        _feedback = feedback;
        _latestTriangulation = triangulation;
        _loadWarning = warnings.isEmpty
            ? null
            : 'Some records could not be loaded: ${warnings.join(', ')}.';
        _isLoading = false;
      });
    } else {
      try {
        final db = DatabaseHelper.instance;
        final attendanceData = await db.getChildAttendanceHistory(cid);
        final evaluationData = await db.getChildEvaluationHistory(cid);
        final feedbackData = await db.getFeedbackByChild(cid);
        final triangulationData = await db.getTriangulationHistory(cid);
        if (!mounted) return;
        setState(() {
          _attendance = attendanceData
              .map((item) => AttendanceModel.fromMap(item))
              .toList();
          _evaluations = evaluationData
              .map((item) => EvaluationModel.fromMap(item))
              .toList();
          _feedback = feedbackData
              .map((item) => ParentFeedbackModel.fromMap(item))
              .toList();
          if (triangulationData.isNotEmpty) {
            _latestTriangulation = TriangulationModel.fromMap(
              triangulationData.first,
            );
          }
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadWarning = 'Child records could not be loaded on this device.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Record: ${widget.child.firstName} ${widget.child.lastName}',
          ),
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
                    if (_loadWarning != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _loadWarning!,
                          style: const TextStyle(color: Colors.deepOrange),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildSectionHeader('Profile Information', Icons.person),
                    _buildProfileInfo(),
                    const SizedBox(height: 32),

                    _buildSectionHeader(
                      'Latest Triangulation Status',
                      Icons.psychology,
                    ),
                    _buildTriangulationSummary(),
                    const SizedBox(height: 32),

                    DefaultTabController(
                      length: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(
                                text: 'Attendance',
                                icon: Icon(Icons.calendar_month),
                              ),
                              Tab(
                                text: 'Evaluations',
                                icon: Icon(Icons.assignment),
                              ),
                              Tab(
                                text: 'Parent Feedback',
                                icon: Icon(Icons.family_restroom),
                              ),
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
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No triangulation analysis performed yet.'),
        ),
      );
    }
    final status = _latestTriangulation!.developmentStatus;
    Color color = Colors.green;
    if (status == 'Needs Monitoring') color = Colors.orange;
    if (status == 'Needs Intervention') color = Colors.red;

    return Card(
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Overall Status: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Date: ${_latestTriangulation!.generatedDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'Summary Analysis:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_latestTriangulation!.triangulatedSummary),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_attendance.isEmpty)
      return const Center(child: Text('No attendance records found.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _attendance.length,
      itemBuilder: (context, index) {
        final item = _attendance[index];
        final isPresent = item.status == 'Present';
        return ListTile(
          leading: Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            color: isPresent ? Colors.green : Colors.red,
          ),
          title: Text(item.attendanceDate),
          subtitle: Text('Time: ${item.attendanceTime}'),
          trailing: Text(
            item.status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPresent ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvaluationList() {
    if (_evaluations.isEmpty)
      return const Center(child: Text('No evaluation records found.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _evaluations.length,
      itemBuilder: (context, index) {
        final item = _evaluations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              item.domain,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Score: ${item.score} pts | ${item.remarks}'),
            trailing: Text(item.evaluationDate),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackList() {
    if (_feedback.isEmpty)
      return const Center(child: Text('No parent feedback found.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _feedback.length,
      itemBuilder: (context, index) {
        final item = _feedback[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('Observation: ${item.parentObservation}'),
            subtitle: Text(
              'Assistance: ${item.assistanceLevel}\nNotes: ${item.notes}',
            ),
            isThreeLine: true,
            trailing: Text(
              item.submissionDate,
              style: const TextStyle(fontSize: 10),
            ),
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
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
