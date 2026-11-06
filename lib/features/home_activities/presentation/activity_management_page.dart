import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/activity_repository.dart';
import '../domain/activity_model.dart';
import '../../../core/utils/validators.dart';
import '../../../core/sync/sync_service.dart';
import 'activity_submission_page.dart';
import 'activity_review_page.dart';
import '../../../shared/widgets/brand_widgets.dart';

class ActivityManagementPage extends StatefulWidget {
  const ActivityManagementPage({super.key});

  @override
  State<ActivityManagementPage> createState() => _ActivityManagementPageState();
}

class _ActivityManagementPageState extends State<ActivityManagementPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<ActivityModel> _allActivities = [];
  List<ActivityModel> _filteredActivities = [];
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  UserModel? _currentUser;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _sortBy = 'Due Date Newest First';
  bool _isLoading = true;

  final List<String> _statusFilters = [
    'All',
    'Assigned',
    'Completed',
    'Overdue',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await AuthRepositoryImpl().getCurrentUser();

      if (_currentUser?.role == UserRole.teacher) {
        // Keep the teacher's local cache current, then show only children
        // assigned to this teacher and their activities.
        await SyncService().performSync();
        _children = await DatabaseHelper.instance.readChildrenByTeacher(
          _currentUser!.uid,
        );
        final teacherChildIds = _children.map((child) => child.childId).toSet();
        _allActivities = (await _repository.getAllActivities())
            .where((activity) => teacherChildIds.contains(activity.childId))
            .toList();
      } else if (_currentUser?.role == UserRole.parent) {
        // Pull teacher-created activities before reading the parent's local cache.
        await SyncService().performSync();
        _children = await DatabaseHelper.instance.readChildrenByParent(
          _currentUser!.uid,
        );
        _selectedChild = _children.isEmpty
            ? null
            : _children.firstWhere(
                (child) => child.childId == _selectedChild?.childId,
                orElse: () => _children.first,
              );
        _allActivities = _selectedChild == null
            ? []
            : await _repository.getActivitiesForChild(_selectedChild!.childId);
      }
      if (!mounted) return;
      _applyFilterAndSort();
    } catch (_) {
      _allActivities = [];
      _filteredActivities = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onParentChildChanged(ChildModel? child) async {
    if (child == null) return;
    setState(() {
      _selectedChild = child;
      _isLoading = true;
    });
    _allActivities = await _repository.getActivitiesForChild(child.childId);
    _applyFilterAndSort();
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredActivities = _allActivities.where((activity) {
        final title = activity.activityTitle.toLowerCase();
        final instructions = activity.instructions.toLowerCase();
        final childId = activity.childId.toLowerCase();

        final isOverdue =
            DateTime.tryParse(activity.dueDate)?.isBefore(DateTime.now()) ??
            false;
        final currentStatus = (isOverdue && activity.status == 'Assigned')
            ? 'Overdue'
            : activity.status;

        final matchesSearch =
            title.contains(q) ||
            instructions.contains(q) ||
            childId.contains(q);
        final matchesStatus =
            _selectedStatusFilter == 'All' ||
            currentStatus.toLowerCase() == _selectedStatusFilter.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();

      _filteredActivities.sort((a, b) {
        final dateA = a.dueDate;
        final dateB = b.dueDate;
        switch (_sortBy) {
          case 'Title A-Z':
            return a.activityTitle.toLowerCase().compareTo(
              b.activityTitle.toLowerCase(),
            );
          case 'Due Date Oldest First':
            return dateA.compareTo(dateB);
          case 'Due Date Newest First':
          default:
            return dateB.compareTo(dateA);
        }
      });
    });
  }

  void _showCreateActivityDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final instructionsController = TextEditingController();
    final maxScoreController = TextEditingController(text: '20');
    ChildModel? selectedChild = _children.isNotEmpty ? _children.first : null;
    String selectedDomain = 'Gross Motor';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Home Activity'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ChildModel>(
                    initialValue: selectedChild,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assign to Child',
                    ),
                    items: _children
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              "${c.firstName} ${c.lastName} (${c.childId})",
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedChild = val),
                    validator: (val) =>
                        val == null ? 'Please select a child' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDomain,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Developmental Domain',
                      prefixIcon: Icon(Icons.psychology_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Gross Motor',
                        child: Text('Gross Motor'),
                      ),
                      DropdownMenuItem(
                        value: 'Fine Motor',
                        child: Text('Fine Motor'),
                      ),
                      DropdownMenuItem(
                        value: 'Self-Help',
                        child: Text('Self-Help'),
                      ),
                      DropdownMenuItem(
                        value: 'Language',
                        child: Text('Language'),
                      ),
                      DropdownMenuItem(
                        value: 'Cognitive',
                        child: Text('Cognitive'),
                      ),
                      DropdownMenuItem(
                        value: 'Social-Emotional',
                        child: Text('Social-Emotional'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => selectedDomain = value ?? selectedDomain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Activity Title',
                    ),
                    validator: (v) =>
                        Validators.validateRequired(v, 'Activity Title'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: instructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        Validators.validateRequired(v, 'Instructions'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: maxScoreController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max Score (e.g. 20)',
                      helperText: 'Maximum points possible for this activity',
                    ),
                    validator: (v) {
                      final req = Validators.validateRequired(v, 'Max Score');
                      if (req != null) return req;
                      final score = int.tryParse(v!.trim());
                      if (score == null || score <= 0 || score > 100) {
                        return 'Score must be a number between 1 and 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(
                      'Due date: ${DateFormat('MMM d, yyyy').format(selectedDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(
                          () => selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDate.hour,
                            selectedDate.minute,
                            selectedDate.second,
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      'Due time: ${DateFormat('HH:mm:ss').format(selectedDate)}',
                    ),
                    subtitle: const Text(
                      'Hours, minutes, and seconds are configurable',
                    ),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final picked = await _showTimeWithSecondsPicker(
                        selectedDate,
                      );
                      if (picked != null) {
                        setDialogState(
                          () => selectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            picked.hour,
                            picked.minute,
                            picked.second,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isSubmitting) return;
                if (formKey.currentState!.validate()) {
                  if (selectedChild == null) return;
                  setDialogState(() => isSubmitting = true);
                  final now = DateFormat('yyyy-MM-dd HH:mm:ss')
                      .format(DateTime.now());
                  final maxScore =
                      int.tryParse(maxScoreController.text.trim()) ?? 20;

                  final activity = ActivityModel(
                    childId: selectedChild!.childId,
                    activityTitle: titleController.text.trim(),
                    developmentalDomain: selectedDomain,
                    instructions: instructionsController.text.trim(),
                    dueDate: DateFormat('yyyy-MM-dd HH:mm:ss')
                        .format(selectedDate),
                    assignedBy: _currentUser?.name ?? 'Teacher',
                    createdDate: now,
                    status: 'Assigned',
                    updatedAt: now,
                    isSynced: false,
                    maxScore: maxScore,
                  );
                  try {
                    await _repository.createActivity(activity);
                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  } catch (error) {
                    setDialogState(() => isSubmitting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Unable to assign activity: $error'),
                        ),
                      );
                    }
                  }
                }
              },
              child: isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _currentUser?.role == UserRole.teacher;
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Home Activities'),
        actions: [
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.rate_review),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActivityReviewPage(),
                ),
              ),
              tooltip: 'Review Submissions',
            ),
        ],
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: _showCreateActivityDialog,
              label: const Text('New Activity'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF7FBFF)),
        child: Column(
          children: [
            if (isTeacher) _buildHero(isPhone),
            if (!isTeacher && _children.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: DropdownButtonFormField<ChildModel>(
                  initialValue: _selectedChild,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'View activities for child',
                    prefixIcon: Icon(Icons.child_care),
                  ),
                  items: _children
                      .map(
                        (child) => DropdownMenuItem(
                          value: child,
                          child: Text(
                            '${child.firstName} ${child.lastName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onParentChildChanged,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: _buildSearchField(isPhone),
            ),
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredActivities.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      child: _buildEmptyState(isTeacher),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = _filteredActivities[index];
                        final isOverdue =
                            (DateTime.tryParse(activity.dueDate)
                                    ?.isBefore(DateTime.now()) ??
                                false) &&
                            activity.status == 'Assigned';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            title: Text(
                              activity.activityTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.instructions,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Domain: ${activity.developmentalDomain}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Child ID: ${activity.childId} | Max Score: ${activity.maxScore} pts',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: isOverdue
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Due: ${activity.dueDate}',
                                          style: TextStyle(
                                            color: isOverdue
                                                ? Colors.red
                                                : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildStatusBadge(
                                      activity.status,
                                      isOverdue,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () async {
                              if (isTeacher) {
                                _showActivityDetails(activity);
                              } else {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ActivitySubmissionPage(
                                          activity: activity,
                                        ),
                                  ),
                                );
                                if (result == true) _loadData();
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isPhone) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD7E5F1)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D0F2D52),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: Color(0xFF17365D)),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        hintText: isPhone
            ? 'Search activities...'
            : 'Search by child ID, title, or instructions...',
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF7891A8)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2277C9)),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _searchController.clear();
                  _searchQuery = '';
                  _applyFilterAndSort();
                },
              ),
      ),
      onChanged: (value) {
        _searchQuery = value;
        _applyFilterAndSort();
      },
    ),
  );

  Widget _buildHero(bool isPhone) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
    child: Container(
      height: 168,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5FF), Color(0xFFF9FCFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: isPhone ? 1 : .47,
                heightFactor: 1,
                child: Image.asset(
                  'assets/images/home_activities_hero.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          if (isPhone)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xE6E8F5FF), Color(0x66F9FCFF)],
                  ),
                ),
              ),
            ),
          Positioned(
            left: isPhone ? 24 : 28,
            top: isPhone ? 26 : 34,
            right: isPhone ? 24 : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Home Activities',
                  style: TextStyle(
                    fontSize: isPhone ? 26 : 31,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102A72),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browse, manage, and track home activities assigned to children.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF54769B)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState(bool isTeacher) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 105,
          height: 105,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3FF),
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            size: 58,
            color: BrandColors.sky,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'No matching activities found.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'There are no home activities to display yet.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        if (isTeacher) ...[
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _showCreateActivityDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sky,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;
        final fieldWidth = isNarrow
            ? constraints.maxWidth - 32
            : (constraints.maxWidth - 44) / 2;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.filter_list),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  items: _statusFilters
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedStatusFilter = value);
                    _applyFilterAndSort();
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    prefixIcon: Icon(Icons.sort),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  items:
                      [
                            'Due Date Newest First',
                            'Due Date Oldest First',
                            'Title A-Z',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortBy = value);
                    _applyFilterAndSort();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_TimeWithSeconds?> _showTimeWithSecondsPicker(DateTime initialTime) {
    var hour = initialTime.hour;
    var minute = initialTime.minute;
    var second = initialTime.second;
    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final secondController = FixedExtentScrollController(initialItem: second);

    return showDialog<_TimeWithSeconds>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set due time'),
          content: SizedBox(
            width: double.maxFinite,
            height: 230,
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeWheel(
                    label: 'Hour',
                    itemCount: 24,
                    controller: hourController,
                    onChanged: (value) => setDialogState(() => hour = value),
                  ),
                ),
                Expanded(
                  child: _buildTimeWheel(
                    label: 'Minute',
                    itemCount: 60,
                    controller: minuteController,
                    onChanged: (value) => setDialogState(() => minute = value),
                  ),
                ),
                Expanded(
                  child: _buildTimeWheel(
                    label: 'Second',
                    itemCount: 60,
                    controller: secondController,
                    onChanged: (value) => setDialogState(() => second = value),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _TimeWithSeconds(hour, minute, second),
              ),
              child: const Text('Set time'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeWheel({
    required String label,
    required int itemCount,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: .45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: 44,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                background: Colors.transparent,
              ),
              onSelectedItemChanged: onChanged,
              childCount: itemCount,
              itemBuilder: (context, index) => Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showActivityDetails(ActivityModel activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activity.activityTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Child ID: ${activity.childId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Developmental domain: ${activity.developmentalDomain}',
                style: const TextStyle(color: Colors.deepPurple),
              ),
              Text(
                'Max Score: ${activity.maxScore} pts',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(activity.instructions),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isOverdue) {
    Color color = Colors.blue;
    String label = status;
    if (isOverdue) {
      color = Colors.red;
      label = 'Overdue';
    } else if (status == 'Completed') {
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _TimeWithSeconds {
  const _TimeWithSeconds(this.hour, this.minute, this.second);

  final int hour;
  final int minute;
  final int second;
}
