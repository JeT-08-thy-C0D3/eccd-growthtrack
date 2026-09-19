import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/repositories/audit_repository.dart';
import '../domain/audit_log_model.dart';

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  final AuditRepository _repository = AuditRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedModule;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Trail'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<AuditLogModel>>(
              stream: _repository.streamLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No audit logs found.'));
                }

                final logs = snapshot.data!.where((log) {
                  final matchesSearch = log.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      log.userId.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchesModule = _selectedModule == null || log.module == _selectedModule;
                  return matchesSearch && matchesModule;
                }).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                        columns: const [
                          DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('User ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: logs.map((log) {
                          return DataRow(cells: [
                            DataCell(Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp))),
                            DataCell(Text(log.userId, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            DataCell(_buildModuleBadge(log.module)),
                            DataCell(Text(log.action, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(log.description)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final modules = ['Authentication', 'User Management', 'Child Registration', 'Referral', 'Evaluation'];

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search logs...',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _selectedModule,
              decoration: const InputDecoration(
                labelText: 'Filter by Module',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Modules')),
                ...modules.map((m) => DropdownMenuItem(value: m, child: Text(m))),
              ],
              onChanged: (val) => setState(() => _selectedModule = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleBadge(String module) {
    Color color = Colors.grey;
    if (module == 'Authentication') color = Colors.purple;
    if (module == 'User Management') color = Colors.red;
    if (module == 'Child Registration') color = Colors.blue;
    if (module == 'Referral') color = Colors.orange;
    if (module == 'Evaluation') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        module,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
