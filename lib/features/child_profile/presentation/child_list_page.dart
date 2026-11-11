import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/child_repository.dart';
import 'child_registration_page.dart';

/// Standalone CRUD screen for the teacher's child profiles.
///
/// This is deliberately not embedded in the dashboard. It prevents the
/// dashboard shell from constraining the list and gives the page its own app
/// bar, scrolling area, and action button.
class ChildListPage extends StatefulWidget {
  const ChildListPage({
    super.key,
    this.teacherMode = false,
    this.showTeacherBottomNavigation = true,
    this.onTeacherSectionSelected,
  });

  final bool teacherMode;
  final bool showTeacherBottomNavigation;
  final ValueChanged<int>? onTeacherSectionSelected;

  @override
  State<ChildListPage> createState() => _ChildListPageState();
}

class _ChildListPageState extends State<ChildListPage> {
  final ChildRepository _repository = ChildRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();

  List<ChildModel> _children = const [];
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _showInactive = false;
  String _gender = 'All Genders';
  String _section = 'All Sections';
  String _sort = 'Name A-Z';
  String? _error;

  bool get _canManage =>
      widget.teacherMode ||
      _currentUser?.role == UserRole.teacher ||
      _currentUser?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final user = await AuthRepositoryImpl().getCurrentUser();
      final List<ChildModel> children;
      if (user?.role == UserRole.teacher || widget.teacherMode) {
        final teacherId = user?.uid.trim().isNotEmpty == true
            ? user!.uid
            : AuthRepositoryImpl().firebaseUserId;
        children = teacherId == null
            ? const []
            : await DatabaseHelper.instance.readChildrenByTeacher(
                teacherId,
                includeInactive: true,
              );
      } else if (user?.role == UserRole.parent) {
        children = await DatabaseHelper.instance.readChildrenByParent(
          user!.uid,
          includeInactive: true,
        );
      } else {
        children = await _repository.getChildren(includeInactive: true);
      }
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _children = children;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Unable to load child profiles: $error');
      if (!mounted) return;
      setState(() {
        _children = const [];
        _error = 'Hindi ma-load ang child profiles. Subukan ulit.';
        _isLoading = false;
      });
    }
  }

  List<ChildModel> get _visibleChildren {
    final query = _searchController.text.trim().toLowerCase();
    final selected = _children.where((child) {
      final matchesStatus = _showInactive ? !child.isActive : child.isActive;
      final matchesGender =
          _gender == 'All Genders' ||
          child.gender.toLowerCase() == _gender.toLowerCase();
      final matchesSection =
          _section == 'All Sections' || child.section.label == _section;
      final searchable = [
        child.childId,
        child.firstName,
        child.lastName,
        child.parentName,
        child.section.label,
      ].join(' ').toLowerCase();
      return matchesStatus &&
          matchesGender &&
          matchesSection &&
          (query.isEmpty || searchable.contains(query));
    }).toList();

    selected.sort((a, b) {
      if (_sort == 'Newest Updated') return b.updatedAt.compareTo(a.updatedAt);
      if (_sort == 'Oldest Updated') return a.updatedAt.compareTo(b.updatedAt);
      return '${a.lastName} ${a.firstName}'.toLowerCase().compareTo(
        '${b.lastName} ${b.firstName}'.toLowerCase(),
      );
    });
    return selected;
  }

  int get _activeCount => _children.where((child) => child.isActive).length;
  int get _inactiveCount => _children.length - _activeCount;

  Future<void> _openForm([ChildModel? child]) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChildRegistrationPage(child: child)),
    );
    if (didSave == true) await _loadChildren();
  }

  void _selectTeacherSection(int index) {
    if (index == 1) {
      _loadChildren();
      return;
    }
    final onSectionSelected = widget.onTeacherSectionSelected;
    if (onSectionSelected == null) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop();
    onSectionSelected(index);
  }

  Future<void> _changeStatus(ChildModel child, {required bool archive}) async {
    final action = archive ? 'i-archive' : 'i-restore';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          archive ? 'Archive child profile?' : 'Restore child profile?',
        ),
        content: Text(
          archive
              ? 'Mawawala si ${child.firstName} sa active list, pero mananatili siya sa Inactive archive.'
              : 'Ibabalik si ${child.firstName} sa active child list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: archive
                  ? Colors.red.shade700
                  : Colors.teal.shade700,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(archive ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (archive) {
        await _repository.archiveChild(child);
      } else {
        await _repository.restoreChild(child);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${child.firstName} was $action.')),
      );
      await _loadChildren();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hindi na-$action ang profile: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: BrandColors.canvas,
      appBar: AppBar(
        title: const EccdAppBarTitle(
          title: 'Child Profiles',
          subtitle: 'CLASSROOM RECORDS',
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadChildren,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: BrandColors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Register Child'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildToolbar(colorScheme),
            _buildStatusTabs(colorScheme),
            Expanded(child: _buildContent(colorScheme)),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.teacherMode && widget.showTeacherBottomNavigation
          ? SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: 1,
                onDestinationSelected: _selectTeacherSection,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: 'Children',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today),
                    label: 'Attendance',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildToolbar(ColorScheme colorScheme) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100F2D52),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search by Child ID, Name, or Parent...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: const Color(0xFFF2F8FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: BrandColors.sky.withValues(alpha: .18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender,
                isExpanded: true,
                decoration: _filterDecoration(Icons.wc_rounded, 'Gender'),
                items: const [
                  DropdownMenuItem(
                    value: 'All Genders',
                    child: Text('All Genders'),
                  ),
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (value) =>
                    setState(() => _gender = value ?? _gender),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _sort,
                isExpanded: true,
                decoration: _filterDecoration(Icons.sort_rounded, 'Sort'),
                items: const [
                  DropdownMenuItem(value: 'Name A-Z', child: Text('Name A-Z')),
                  DropdownMenuItem(
                    value: 'Newest Updated',
                    child: Text('Newest Updated'),
                  ),
                  DropdownMenuItem(
                    value: 'Oldest Updated',
                    child: Text('Oldest Updated'),
                  ),
                ],
                onChanged: (value) => setState(() => _sort = value ?? _sort),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _section,
          isExpanded: true,
          decoration: _filterDecoration(Icons.groups_rounded, 'Section'),
          items: [
            const DropdownMenuItem(
              value: 'All Sections',
              child: Text('All Sections'),
            ),
            ...ChildSection.values.map(
              (section) => DropdownMenuItem(
                value: section.label,
                child: Text('${section.label} (${section.ageRange})'),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _section = value ?? _section),
        ),
      ],
    ),
  );

  InputDecoration _filterDecoration(IconData icon, String label) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _buildStatusTabs(ColorScheme colorScheme) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: _statusButton(
            label: 'Active ($_activeCount)',
            selected: !_showInactive,
            color: BrandColors.sky,
            onTap: () => setState(() => _showInactive = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statusButton(
            label: 'Inactive ($_inactiveCount)',
            selected: _showInactive,
            color: BrandColors.sunshine,
            onTap: () => setState(() => _showInactive = true),
          ),
        ),
      ],
    ),
  );

  Widget _statusButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: selected ? Colors.white : color,
      backgroundColor: selected ? color : Colors.white,
      side: BorderSide(color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    child: Text(label, overflow: TextOverflow.ellipsis),
  );

  Widget _buildContent(ColorScheme colorScheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    final children = _visibleChildren;
    if (children.isEmpty) return _buildEmpty(colorScheme);

    return RefreshIndicator(
      onRefresh: _loadChildren,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) =>
            _buildChildCard(children[index], colorScheme),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 50,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadChildren,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty(ColorScheme colorScheme) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              _showInactive
                  ? Icons.inventory_2_outlined
                  : Icons.child_care_rounded,
              size: 44,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _showInactive
                ? 'No inactive child profiles'
                : 'No child profiles yet',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _showInactive
                ? 'Archived profiles will appear here and can be restored anytime.'
                : 'Register a child to create their profile and track their development.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    ),
  );

  Widget _buildChildCard(ChildModel child, ColorScheme colorScheme) {
    final fullName = '${child.firstName} ${child.lastName}'.trim();
    final initial = fullName.isEmpty ? '?' : fullName[0].toUpperCase();
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: BrandColors.sky.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: BrandColors.sky.withValues(alpha: .13),
              foregroundColor: BrandColors.navy,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isEmpty ? 'Unnamed child' : fullName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Child ID: ${child.childId}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _detailChip(
                        Icons.cake_outlined,
                        '${child.age} years old',
                      ),
                      _detailChip(
                        Icons.wc_rounded,
                        child.gender.isEmpty ? 'Not specified' : child.gender,
                      ),
                      _detailChip(Icons.groups_rounded, child.section.label),
                      _detailChip(
                        child.rfidVerified
                            ? Icons.verified_rounded
                            : Icons.pending_actions_rounded,
                        child.rfidVerified ? 'RFID Verified' : 'RFID Pending',
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.family_restroom_rounded,
                        size: 17,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          child.parentName.isEmpty
                              ? 'No parent linked'
                              : 'Linked parent: ${child.parentName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_canManage)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => _openForm(child),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: child.isActive
                        ? 'Archive profile'
                        : 'Restore profile',
                    color: child.isActive
                        ? Colors.red.shade700
                        : Colors.teal.shade700,
                    onPressed: () =>
                        _changeStatus(child, archive: child.isActive),
                    icon: Icon(
                      child.isActive
                          ? Icons.archive_outlined
                          : Icons.unarchive_outlined,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.black54),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    ),
  );
}
