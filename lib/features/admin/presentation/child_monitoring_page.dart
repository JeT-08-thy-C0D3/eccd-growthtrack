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
  String _searchQuery = '';
  String _selectedGenderFilter = 'All';
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

        return matchesSearch && matchesGender;
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
              result = a.gender.compareTo(b.gender);
              break;
            case 4:
              result = a.teacherName.toLowerCase().compareTo(
                b.teacherName.toLowerCase(),
              );
              break;
            case 5:
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;
    final totalItems = _filteredChildren.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final paginatedChildren = _filteredChildren
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 10),
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

  Widget _buildChildHero() => Container(
    width: double.infinity,
    height: 164,
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
          left: 30,
          top: 36,
          right: 410,
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF168CF0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.child_friendly_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(width: 22),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Child Monitoring & Case Review (Admin)',
                      style: TextStyle(
                        color: Color(0xFF0D1A5B),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Monitor children\'s profiles and review their cases and development status.',
                      style: TextStyle(
                        color: Color(0xFF386296),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = SearchBar(
            controller: _searchController,
            hintText: 'Search by name, child ID, teacher, or parent...',
            leading: const Icon(Icons.search),
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
          if (constraints.maxWidth < 680) {
            return Column(
              children: [search, const SizedBox(height: 10), filter],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              SizedBox(width: 210, child: filter),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResponsiveList(List<ChildModel> paginatedChildren, bool isWide) {
    if (isWide && kIsWeb) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 1200,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainer,
                ),
                columns: [
                  DataColumn(
                    label: const Text(
                      'Child Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) => _sort(index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Child ID',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) => _sort(index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Age',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) => _sort(index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Gender',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) => _sort(index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Teacher',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) => _sort(index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Parent/Guardian',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) => _sort(index, ascending),
                  ),
                  const DataColumn(
                    label: Text(
                      'Action',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: paginatedChildren.map((child) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              child: Text(
                                child.firstName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${child.firstName} ${child.lastName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(child.childId)),
                      DataCell(Text('${child.age} yrs')),
                      DataCell(Text(child.gender)),
                      DataCell(Text(child.teacherName)),
                      DataCell(Text(child.parentName)),
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
              'ID: ${child.childId} | Teacher: ${child.teacherName}',
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final String cid = widget.child.childId;

    if (kIsWeb) {
      final attSnap = await _firestore
          .collection('attendance')
          .where('child_id', isEqualTo: cid)
          .get();
      final evalSnap = await _firestore
          .collection('evaluations')
          .where('child_id', isEqualTo: cid)
          .get();
      final feedSnap = await _firestore
          .collection('parent_feedback')
          .where('child_id', isEqualTo: cid)
          .get();
      final triSnap = await _firestore
          .collection('triangulations')
          .where('child_id', isEqualTo: cid)
          .get();

      setState(() {
        _attendance = attSnap.docs
            .map((d) => AttendanceModel.fromMap(d.data()))
            .toList();
        _evaluations = evalSnap.docs
            .map((d) => EvaluationModel.fromMap(d.data()))
            .toList();
        _feedback = feedSnap.docs
            .map((d) => ParentFeedbackModel.fromMap(d.data()))
            .toList();
        if (triSnap.docs.isNotEmpty) {
          _latestTriangulation = TriangulationModel.fromMap(
            triSnap.docs.first.data(),
          );
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
        _attendance = attendanceData
            .map((e) => AttendanceModel.fromMap(e))
            .toList();
        _evaluations = evaluationData
            .map((e) => EvaluationModel.fromMap(e))
            .toList();
        _feedback = feedbackData
            .map((e) => ParentFeedbackModel.fromMap(e))
            .toList();
        if (triangulationData.isNotEmpty) {
          _latestTriangulation = TriangulationModel.fromMap(
            triangulationData.first,
          );
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
