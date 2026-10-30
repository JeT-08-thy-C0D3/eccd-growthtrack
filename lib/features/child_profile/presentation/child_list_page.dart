import 'package:flutter/material.dart';

import '../data/child_repository.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../auth/data/auth_repository_impl.dart';
import 'child_registration_page.dart';
import '../../../shared/widgets/brand_widgets.dart';

class ChildListPage extends StatefulWidget {
  const ChildListPage({super.key});

  @override
  State<ChildListPage> createState() => _ChildListPageState();
}

class _ChildListPageState extends State<ChildListPage> {
  final ChildRepository _repository = ChildRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<ChildModel> _allChildren = [];
  List<ChildModel> _filteredChildren = [];
  String _searchQuery = '';
  String _selectedGenderFilter = 'All';
  String _sortBy = 'Name A-Z';
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _refreshChildren();
  }

  Future<void> _refreshChildren() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthRepositoryImpl().getCurrentUser();
      final data = user?.role == UserRole.teacher
          ? await DatabaseHelper.instance.readChildrenByTeacher(user!.uid)
          : user?.role == UserRole.parent
          ? await DatabaseHelper.instance.readChildrenByParent(user!.uid)
          : await _repository.getChildren();
      final visibleChildren = _childrenVisibleToUser(data, user);
      final filteredChildren = _filterAndSort(visibleChildren);
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _allChildren = visibleChildren;
        _filteredChildren = filteredChildren;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allChildren = [];
        _filteredChildren = [];
        _isLoading = false;
      });
    }
  }

  List<ChildModel> _childrenVisibleToUser(
    List<ChildModel> children,
    UserModel? user,
  ) {
    if (user == null || user.role == UserRole.admin) return children;
    if (user.role == UserRole.teacher) {
      return children.where((child) => child.teacherUid == user.uid).toList();
    }
    return children.where((child) => child.parentUid == user.uid).toList();
  }

  void _applyFilterAndSort() {
    setState(() => _filteredChildren = _filterAndSort(_allChildren));
  }

  List<ChildModel> _filterAndSort(List<ChildModel> children) {
    final q = _searchQuery.toLowerCase();
    final filteredChildren = children.where((child) {
      final name = "${child.firstName} ${child.lastName}".toLowerCase();
      final matchesSearch =
          name.contains(q) ||
          child.childId.toLowerCase().contains(q) ||
          child.parentName.toLowerCase().contains(q);

      final matchesGender =
          _selectedGenderFilter == 'All' ||
          child.gender.toLowerCase() == _selectedGenderFilter.toLowerCase();

      return matchesSearch && matchesGender;
    }).toList();

    filteredChildren.sort((a, b) {
      switch (_sortBy) {
        case 'Name Z-A':
          return "${b.firstName} ${b.lastName}".toLowerCase().compareTo(
            "${a.firstName} ${a.lastName}".toLowerCase(),
          );
        case 'Age (Youngest)':
          return a.age.compareTo(b.age);
        case 'Age (Oldest)':
          return b.age.compareTo(a.age);
        case 'Name A-Z':
        default:
          return "${a.firstName} ${a.lastName}".toLowerCase().compareTo(
            "${b.firstName} ${b.lastName}".toLowerCase(),
          );
      }
    });
    return filteredChildren;
  }

  void _deleteChild(ChildModel child) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context: context,
      itemName: '${child.firstName} ${child.lastName}',
    );

    if (confirmed) {
      await _repository.deleteChild(child.id!);
      _refreshChildren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Child profile deleted successfully')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Child Profiles'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChildRegistrationPage(),
            ),
          );
          if (result == true) _refreshChildren();
        },
        label: const Text('Register Child'),
        icon: const Icon(Icons.add),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF7FAFC)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    8,
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Child Profiles',
                          style: TextStyle(
                            fontSize: 28,
                            color: Color(0xFF102A72),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage and monitor enrolled children records.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    12,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    elevation: const WidgetStatePropertyAll(3),
                    backgroundColor: const WidgetStatePropertyAll(Colors.white),
                    hintText: 'Search by Child ID, Name, or Parent...',
                    leading: const Icon(
                      Icons.search_rounded,
                      color: BrandColors.navy,
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilterAndSort();
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _buildFilterBar(),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredChildren.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredChildren.length,
                          itemBuilder: (context, index) {
                            final child = _filteredChildren[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    child.firstName[0],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${child.firstName} ${child.lastName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${child.childId}'),
                                    Text(
                                      'Age: ${child.age} yrs | Gender: ${child.gender}',
                                    ),
                                    Text('Parent: ${child.parentName}'),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChildRegistrationPage(
                                                  child: child,
                                                ),
                                          ),
                                        );
                                        if (result == true) _refreshChildren();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          _currentUser?.role == UserRole.admin
                                          ? () => _deleteChild(child)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F2D52),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;
          final filters = Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 21,
                color: BrandColors.navy,
              ),
              const SizedBox(width: 8),
              const Text(
                'Filter Gender:',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: BrandColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Male', 'Female'].map((gender) {
                      final isSelected = _selectedGenderFilter == gender;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            gender == 'All' ? 'All Genders' : gender,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGenderFilter = gender;
                                _applyFilterAndSort();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isCompact) const VerticalDivider(width: 28),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                icon: const Icon(Icons.sort, size: 20),
                items:
                    ['Name A-Z', 'Name Z-A', 'Age (Youngest)', 'Age (Oldest)']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _sortBy = val;
                      _applyFilterAndSort();
                    });
                  }
                },
              ),
            ],
          );
          return isCompact
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filters,
                )
              : filters;
        },
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 230,
            height: 155,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 170,
                  height: 125,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F1FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                Positioned(
                  left: 30,
                  bottom: 18,
                  child: _emptyChildAvatar(
                    BrandColors.green,
                    Icons.menu_book_rounded,
                  ),
                ),
                Positioned(
                  right: 28,
                  bottom: 16,
                  child: _emptyChildAvatar(
                    BrandColors.sunshine,
                    Icons.abc_rounded,
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D95E8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x333D95E8), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(
                    Icons.folder_shared_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No child profiles yet',
            style: TextStyle(
              fontSize: 25,
              color: Color(0xFF102A72),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 500,
            child: Text(
              'Get started by registering a child to manage their records, track attendance, and support their learning journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChildRegistrationPage(),
                ),
              );
              if (result == true) _refreshChildren();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1175E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text(
              'Register Child',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyChildAvatar(Color color, IconData icon) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
    ),
    child: Icon(icon, color: Colors.white, size: 27),
  );
}
