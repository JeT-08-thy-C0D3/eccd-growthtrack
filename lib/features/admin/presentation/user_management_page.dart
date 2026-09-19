import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../shared/models/user_model.dart';
import '../domain/repositories/user_repository.dart';
import '../data/repositories/user_repository_impl.dart';
import 'user_form_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserRepository _repository = UserRepositoryImpl();

  void _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int id = user.id ?? 0;
      await _repository.deleteUser(id, user.uid);
    }
  }

  void _toggleStatus(UserModel user) async {
    await _repository.toggleUserStatus(user);
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
      body: StreamBuilder<List<UserModel>>(
        stream: kIsWeb ? _repository.getUsersStream() : null,
        builder: (context, snapshot) {
          if (!kIsWeb) {
             return FutureBuilder<List<UserModel>>(
               future: _repository.getUsers(),
               builder: (context, futureSnapshot) {
                 if (futureSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                 return _buildResponsiveList(futureSnapshot.data ?? [], isWide);
               }
             );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          return _buildResponsiveList(users, isWide);
        }
      ),
    );
  }

  Widget _buildResponsiveList(List<UserModel> users, bool isWide) {
    if (users.isEmpty) return const Center(child: Text('No users found.'));

    if (isWide && kIsWeb) {
       return SingleChildScrollView(
         padding: const EdgeInsets.all(32),
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
                 headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainer),
                 columns: const [
                   DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                   DataColumn(label: Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold))),
                   DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                   DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                   DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                 ],
                 rows: users.map((user) => DataRow(cells: [
                   DataCell(Row(
                     children: [
                       CircleAvatar(
                         radius: 14,
                         backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
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
                     activeColor: Colors.green,
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
              backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
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
                  activeColor: Colors.green,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue), 
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserFormPage(user: user))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () => _deleteUser(user)
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
