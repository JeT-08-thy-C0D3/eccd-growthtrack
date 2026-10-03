import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../shared/models/user_model.dart';
import '../domain/repositories/user_repository.dart';
import '../data/repositories/user_repository_impl.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import 'user_form_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserRepository _repository = UserRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  UserRole? _selectedRoleFilter;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _deleteUser(UserModel user) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context: context,
      itemName: user.name,
    );

    if (confirmed) {
      int id = user.id ?? 0;
      await _repository.deleteUser(id, user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account for ${user.name} deleted')),
        );
      }
    }
  }

  void _toggleStatus(UserModel user) async {
    final isActivating = user.status != 'active';
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Confirm Status Change',
      message: 'Are you sure you want to ${isActivating ? "activate" : "deactivate"} ${user.name}?',
      confirmLabel: isActivating ? 'Activate' : 'Deactivate',
      confirmColor: isActivating ? Colors.green : Colors.orange,
      icon: isActivating ? Icons.check_circle_outline : Icons.pause_circle_outline,
    );

    if (confirmed) {
      await _repository.toggleUserStatus(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account for ${user.name} is now ${isActivating ? "active" : "deactivated"}'),
          ),
        );
      }
    }
  }

  void _sort<T>(Comparable<T> Function(UserModel u) getField, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<UserModel> _filterAndSortUsers(List<UserModel> users) {
    var filtered = users.where((u) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.name.toLowerCase().contains(q);
      final matchesRole = _selectedRoleFilter == null || u.role == _selectedRoleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int result = 0;
        switch (_sortColumnIndex) {
          case 0:
            result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 1:
            result = a.email.toLowerCase().compareTo(b.email.toLowerCase());
            break;
          case 2:
            result = a.role.name.compareTo(b.role.name);
            break;
          case 3:
            result = a.status.compareTo(b.status);
            break;
        }
        return _sortAscending ? result : -result;
      });
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MSWD User Management'),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserFormPage()),
          );
        },
        label: const Text('Create Account'),
        icon: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search users by Name, Email, or Role...',
              leading: const Icon(Icons.search),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          _buildRoleFilterBar(),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: kIsWeb ? _repository.getUsersStream() : null,
              builder: (context, snapshot) {
                if (!kIsWeb) {
                  return FutureBuilder<List<UserModel>>(
                    future: _repository.getUsers(),
                    builder: (context, futureSnapshot) {
                      if (futureSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = _filterAndSortUsers(futureSnapshot.data ?? []);
                      return _buildResponsiveList(users, isWide);
                    },
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final users = _filterAndSortUsers(snapshot.data ?? []);
                return _buildResponsiveList(users, isWide);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 20),
          const SizedBox(width: 8),
          const Text('Filter by Role:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All Roles'),
                      selected: _selectedRoleFilter == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedRoleFilter = null);
                      },
                    ),
                  ),
                  ...UserRole.values.map((role) {
                    final isSelected = _selectedRoleFilter == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(role.name.toUpperCase()),
                        selected: isSelected,
                        selectedColor: _getRoleColor(role).withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setState(() {
                            _selectedRoleFilter = selected ? role : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveList(List<UserModel> users, bool isWide) {
    if (users.isEmpty) return const Center(child: Text('No matching user records found.'));

    if (isWide && kIsWeb) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainer),
                columns: [
                  DataColumn(
                    label: const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (index, ascending) => _sort((u) => u.name, index, ascending),
                  ),
                  DataColumn(
                    label: const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (index, ascending) => _sort((u) => u.email, index, ascending),
                  ),
                  DataColumn(
                    label: const Text('Role', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (index, ascending) => _sort((u) => u.role.name, index, ascending),
                  ),
                  DataColumn(
                    label: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (index, ascending) => _sort((u) => u.status, index, ascending),
                  ),
                  const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: users.map((user) => DataRow(cells: [
                  DataCell(Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
                        child: Icon(_getRoleIcon(user.role), size: 14, color: _getRoleColor(user.role)),
                      ),
                      const SizedBox(width: 12),
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  )),
                  DataCell(Text(user.email)),
                  DataCell(Text(user.role.name.toUpperCase(), style: const TextStyle(fontSize: 12))),
                  DataCell(Switch(
                    value: user.status == 'active',
                    onChanged: (_) => _toggleStatus(user),
                    activeThumbColor: Colors.green,
                  )),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserFormPage(user: user))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteUser(user),
                      ),
                    ],
                  )),
                ])).toList(),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isActive = user.status == 'active';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
              child: Icon(_getRoleIcon(user.role), color: _getRoleColor(user.role)),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${user.email} • ${user.role.name.toUpperCase()}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  onChanged: (_) => _toggleStatus(user),
                  activeThumbColor: Colors.green,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserFormPage(user: user))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin: return Icons.admin_panel_settings;
      case UserRole.teacher: return Icons.school;
      case UserRole.parent: return Icons.family_restroom;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return Colors.red;
      case UserRole.teacher: return Colors.blue;
      case UserRole.parent: return Colors.orange;
    }
  }
}
