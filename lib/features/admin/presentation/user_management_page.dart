import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../shared/models/user_model.dart';
import '../domain/repositories/user_repository.dart';
import '../data/repositories/user_repository_impl.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/brand_widgets.dart';
import 'user_form_page.dart';
import 'user_edit_dialog.dart';

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
  String? _selectedStatusFilter;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  Future<void> _openUserForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserFormPage()),
    );
  }

  void _deleteUser(UserModel user) async {
    if (user.isProtectedAdmin) {
      _showProtectedAdminMessage();
      return;
    }
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Archive account',
      message:
          'Archive "${user.name}"? The account will be retained for audit records and can no longer sign in.',
      confirmLabel: 'Archive',
      confirmColor: Colors.orange,
      icon: Icons.archive_outlined,
    );

    if (confirmed) {
      try {
        int id = user.id ?? 0;
        await _repository.deleteUser(id, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account for ${user.name} archived successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive user account: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _toggleStatus(UserModel user) async {
    if (user.isProtectedAdmin) {
      _showProtectedAdminMessage();
      return;
    }
    final isActivating = user.status != 'active';
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Confirm Status Change',
      message:
          'Are you sure you want to ${isActivating ? "activate" : "deactivate"} ${user.name}?',
      confirmLabel: isActivating ? 'Activate' : 'Deactivate',
      confirmColor: isActivating ? Colors.green : Colors.orange,
      icon: isActivating
          ? Icons.check_circle_outline
          : Icons.pause_circle_outline,
    );

    if (confirmed) {
      try {
        await _repository.toggleUserStatus(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account for ${user.name} is now ${isActivating ? "active" : "deactivated"}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update user status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showProtectedAdminMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The system ADMIN account is protected from CRUD changes.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _editUser(UserModel user) async {
    if (user.isProtectedAdmin) {
      _showProtectedAdminMessage();
      return;
    }
    await UserEditDialog.show(context, user);
  }

  void _sort<T>(
    Comparable<T> Function(UserModel u) getField,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<UserModel> _filterAndSortUsers(List<UserModel> users) {
    var filtered = users.where((u) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.name.toLowerCase().contains(q);
      final matchesRole =
          _selectedRoleFilter == null || u.role == _selectedRoleFilter;
      final matchesStatus =
          _selectedStatusFilter == null || u.status == _selectedStatusFilter;
      return matchesSearch && matchesRole && matchesStatus;
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 10),
            child: _buildUserHero(),
          ),
          _buildSearchAndFilterBar(),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: kIsWeb ? _repository.getUsersStream() : null,
              builder: (context, snapshot) {
                if (!kIsWeb) {
                  return FutureBuilder<List<UserModel>>(
                    future: _repository.getUsers(),
                    builder: (context, futureSnapshot) {
                      if (futureSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (futureSnapshot.hasError) {
                        return _buildErrorView(futureSnapshot.error.toString());
                      }
                      final users = _filterAndSortUsers(
                        futureSnapshot.data ?? [],
                      );
                      return _buildPaginatedView(users, isWide);
                    },
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorView(
                    'Cloud database connection issue: ${snapshot.error}',
                  );
                }

                final users = _filterAndSortUsers(snapshot.data ?? []);
                return _buildPaginatedView(users, isWide);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedView(List<UserModel> users, bool isWide) {
    final totalItems = users.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final paginatedUsers = users
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return Column(
      children: [
        Expanded(child: _buildResponsiveList(users, paginatedUsers, isWide)),
        _buildPaginationControls(totalItems, totalPages),
      ],
    );
  }

  Widget _buildSearchAndFilterBar() {
    final filterValue = _selectedRoleFilter != null
        ? 'role:${_selectedRoleFilter!.name}'
        : _selectedStatusFilter != null
        ? 'status:$_selectedStatusFilter'
        : 'all';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;
          final search = SearchBar(
            controller: _searchController,
            hintText: 'Search users by name, email, or role...',
            leading: const Icon(Icons.search),
            onChanged: (val) => setState(() {
              _searchQuery = val;
              _currentPage = 0;
            }),
          );
          final filter = DropdownButtonFormField<String>(
            initialValue: filterValue,
            decoration: const InputDecoration(
              labelText: 'Filter users',
              prefixIcon: Icon(Icons.filter_list),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All users')),
              ...UserRole.values.map(
                (role) => DropdownMenuItem(
                  value: 'role:${role.name}',
                  child: Text(
                    '${role.name[0].toUpperCase()}${role.name.substring(1)}s',
                  ),
                ),
              ),
              const DropdownMenuItem(
                value: 'status:active',
                child: Text('Active users'),
              ),
              const DropdownMenuItem(
                value: 'status:deactivated',
                child: Text('Deactivated users'),
              ),
              const DropdownMenuItem(
                value: 'status:archived',
                child: Text('Archived users'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRoleFilter = value?.startsWith('role:') == true
                    ? UserRole.values.firstWhere(
                        (role) => role.name == value!.substring(5),
                      )
                    : null;
                _selectedStatusFilter = value?.startsWith('status:') == true
                    ? value!.substring(7)
                    : null;
                _currentPage = 0;
              });
            },
          );

          final addButton = ElevatedButton.icon(
            onPressed: _openUserForm,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF168CF0),
              foregroundColor: Colors.white,
              minimumSize: const Size(142, 58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                filter,
                const SizedBox(height: 10),
                addButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              SizedBox(width: 230, child: filter),
              const SizedBox(width: 16),
              addButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserHero() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      return Container(
        width: double.infinity,
        height: 156,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE1F2FF), Color(0xFFF7FCFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -55,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: BrandColors.sky.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            if (!compact)
              Positioned(
                right: 58,
                bottom: 13,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _heroPerson(
                      Colors.lightBlue.shade200,
                      Icons.person_rounded,
                      64,
                    ),
                    const SizedBox(width: 5),
                    _heroPerson(
                      Colors.indigo.shade200,
                      Icons.admin_panel_settings_rounded,
                      86,
                    ),
                    const SizedBox(width: 5),
                    _heroPerson(Colors.teal.shade200, Icons.school_rounded, 64),
                  ],
                ),
              ),
            Positioned(
              left: 30,
              top: 32,
              right: compact ? 24 : 350,
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
                      Icons.group_rounded,
                      color: Colors.white,
                      size: 39,
                    ),
                  ),
                  const SizedBox(width: 22),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MSWD User Management',
                          style: TextStyle(
                            color: Color(0xFF0D1A5B),
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Manage system users and their access roles across the MSWD admin portal.',
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
    },
  );

  Widget _heroPerson(Color color, IconData icon, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, color: Colors.white, size: size * .52),
  );

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Database Connection Issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              'Refresh the browser to retry the connection.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveList(
    List<UserModel> allUsers,
    List<UserModel> paginatedUsers,
    bool isWide,
  ) {
    if (allUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ||
                        _selectedRoleFilter != null ||
                        _selectedStatusFilter != null
                    ? 'No users match your filter criteria'
                    : 'No user accounts registered yet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try searching with a different keyword or resetting filters.'
                    : 'Click "Create Account" to add center staff or parent accounts.',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty ||
                  _selectedRoleFilter != null ||
                  _selectedStatusFilter != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedRoleFilter = null;
                      _selectedStatusFilter = null;
                      _currentPage = 0;
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Reset Search & Filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

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
                      'Full Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) =>
                        _sort((u) => u.name, index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Email Address',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) =>
                        _sort((u) => u.email, index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Role',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) =>
                        _sort((u) => u.role.name, index, ascending),
                  ),
                  DataColumn(
                    label: const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onSort: (index, ascending) =>
                        _sort((u) => u.status, index, ascending),
                  ),
                  const DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: paginatedUsers
                    .map(
                      (user) => DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _getRoleColor(user.role)
                                      .withValues(alpha: 0.1),
                                  child: Icon(
                                    _getRoleIcon(user.role),
                                    size: 14,
                                    color: _getRoleColor(user.role),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(user.email)),
                          DataCell(
                            Text(
                              user.role.name.toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            user.isProtectedAdmin
                                ? const Chip(label: Text('Protected'))
                                : Switch(
                                    value: user.status == 'active',
                                    onChanged: (_) => _toggleStatus(user),
                                    activeThumbColor: Colors.green,
                                  ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                if (user.isProtectedAdmin)
                                  const Tooltip(
                                    message: 'System ADMIN is protected',
                                    child: Icon(
                                      Icons.lock_outline,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  )
                                else ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () => _editUser(user),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: paginatedUsers.length,
      itemBuilder: (context, index) {
        final user = paginatedUsers[index];
        final isActive = user.status == 'active';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
              child: Icon(
                _getRoleIcon(user.role),
                color: _getRoleColor(user.role),
              ),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${user.email} • ${user.role.name.toUpperCase()}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.isProtectedAdmin)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Chip(label: Text('Protected')),
                  )
                else ...[
                  Switch(
                    value: isActive,
                    onChanged: (_) => _toggleStatus(user),
                    activeThumbColor: Colors.green,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editUser(user),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(user),
                  ),
                ],
              ],
            ),
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
            'Showing $startItem - $endItem of $totalItems accounts',
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

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.teacher:
        return Icons.school;
      case UserRole.parent:
        return Icons.family_restroom;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.teacher:
        return Colors.blue;
      case UserRole.parent:
        return Colors.orange;
    }
  }
}
