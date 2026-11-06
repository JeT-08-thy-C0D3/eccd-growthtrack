import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/brand_widgets.dart';
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
  String? _selectedActionFilter;
  int? _sortColumnIndex;
  bool _sortAscending = false;
  int _currentPage = 0;
  static const int _itemsPerPage = 25;

  static const _trackedActions = [
    'Login',
    'User Created',
    'User Updated',
    'User Deleted',
    'Referral Updated',
    'Report Generated',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _sort(int columnIndex, bool ascending) => setState(() {
    _sortColumnIndex = columnIndex;
    _sortAscending = ascending;
  });

  List<AuditLogModel> _filterAndSortLogs(List<AuditLogModel> logs) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = logs.where((log) {
      final matchesSearch =
          query.isEmpty ||
          log.action.toLowerCase().contains(query) ||
          log.performedBy.toLowerCase().contains(query) ||
          log.targetRecord.toLowerCase().contains(query);
      return matchesSearch &&
          (_selectedActionFilter == null ||
              log.action == _selectedActionFilter);
    }).toList();

    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        final result = switch (_sortColumnIndex) {
          0 => a.timestamp.compareTo(b.timestamp),
          1 => a.action.compareTo(b.action),
          2 => a.performedBy.compareTo(b.performedBy),
          _ => a.targetRecord.compareTo(b.targetRecord),
        };
        return _sortAscending ? result : -result;
      });
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuditHero(compact: constraints.maxWidth < 800),
              const SizedBox(height: 20),
              _buildFilterBar(constraints.maxWidth < 720),
              const SizedBox(height: 18),
              StreamBuilder<List<AuditLogModel>>(
                stream: _repository.streamLogs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _AuditStateCard(
                      icon: Icons.hourglass_top_rounded,
                      message: 'Loading secure audit records...',
                      loading: true,
                    );
                  }
                  if (snapshot.hasError) {
                    return _AuditStateCard(
                      icon: Icons.error_outline_rounded,
                      message: 'Unable to load audit records. Please try again later.',
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const _AuditStateCard(
                      icon: Icons.manage_search_rounded,
                      message: 'No audit logs found.',
                    );
                  }

                  final logs = _filterAndSortLogs(snapshot.data!);
                  final totalItems = logs.length;
                  final totalPages = (totalItems / _itemsPerPage).ceil();
                  if (_currentPage >= totalPages && totalPages > 0) {
                    _currentPage = totalPages - 1;
                  }
                  final visibleLogs = logs
                      .skip(_currentPage * _itemsPerPage)
                      .take(_itemsPerPage)
                      .toList();

                  return _AuditTableCard(
                    logs: visibleLogs,
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    onSort: _sort,
                    footer: _buildPaginationControls(totalItems, totalPages),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildFilterBar(bool stacked) {
    final search = TextField(
      controller: _searchController,
      onChanged: (value) => setState(() {
        _searchQuery = value;
        _currentPage = 0;
      }),
      decoration: InputDecoration(
        hintText: 'Search logs by Action, Performed By, or Target Record...',
        prefixIcon: const Icon(Icons.search_rounded, color: BrandColors.navy),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD2E0F2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD2E0F2)),
        ),
      ),
    );
    final filter = DropdownButtonFormField<String>(
      initialValue: _selectedActionFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Filter Actions',
        prefixIcon: const Icon(
          Icons.filter_list_rounded,
          color: BrandColors.navy,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD2E0F2)),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Actions')),
        ..._trackedActions.map(
          (action) => DropdownMenuItem(value: action, child: Text(action)),
        ),
      ],
      onChanged: (value) => setState(() {
        _selectedActionFilter = value;
        _currentPage = 0;
      }),
    );

    if (stacked) {
      return Column(children: [search, const SizedBox(height: 12), filter]);
    }
    return Row(
      children: [
        Expanded(flex: 3, child: search),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: filter),
      ],
    );
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    if (totalItems == 0) return const SizedBox.shrink();
    final start = _currentPage * _itemsPerPage + 1;
    final end = ((_currentPage + 1) * _itemsPerPage).clamp(0, totalItems);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start to $end of $totalItems records',
              style: const TextStyle(color: Color(0xFF57719C), fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: BrandColors.sky,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentPage + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage + 1 < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _AuditHero extends StatelessWidget {
  const _AuditHero({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: compact ? 258 : 174,
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
          right: -30,
          top: -60,
          child: _Bubble(
            size: 220,
            color: BrandColors.sky.withValues(alpha: .13),
          ),
        ),
        if (!compact)
          const Positioned(right: 56, bottom: 8, child: _AuditIllustration()),
        Positioned(
          top: compact ? 24 : 36,
          left: compact ? 24 : 28,
          right: compact ? 24 : 430,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _auditIcon(compact: true),
                    const SizedBox(height: 14),
                    _auditText(compact: true),
                  ],
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _auditIcon(),
              const SizedBox(width: 22),
              Expanded(child: _auditText()),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _auditIcon({bool compact = false}) => Container(
    width: compact ? 58 : 68,
    height: compact ? 58 : 68,
    decoration: BoxDecoration(
      color: const Color(0xFF9FD3FF),
      borderRadius: BorderRadius.circular(compact ? 16 : 18),
    ),
    child: Icon(
      Icons.manage_search_rounded,
      color: const Color(0xFF1676D2),
      size: compact ? 33 : 39,
    ),
  );

  Widget _auditText({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'System Audit Trail',
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
        'Track system activities and monitor important actions across the portal.',
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
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _AuditIllustration extends StatelessWidget {
  const _AuditIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 156,
    width: 320,
    child: Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 5,
          child: Container(
            width: 104,
            height: 126,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF438DDF), width: 5),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFF398BE1),
                  size: 34,
                ),
                SizedBox(height: 8),
                _MiniLine(),
                SizedBox(height: 7),
                _MiniLine(),
                SizedBox(height: 7),
                _MiniLine(),
              ],
            ),
          ),
        ),
        Positioned(
          left: 120,
          bottom: 10,
          child: Container(
            width: 154,
            height: 98,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF398BE1), width: 5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                _MiniLine(width: 116),
                SizedBox(height: 11),
                _MiniLine(width: 94),
                SizedBox(height: 11),
                _MiniLine(width: 110),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 98,
          top: 57,
          child: Icon(Icons.search_rounded, color: BrandColors.navy, size: 72),
        ),
      ],
    ),
  );
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({this.width = 62});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(
      color: const Color(0xFFD4E9FB),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _AuditTableCard extends StatelessWidget {
  const _AuditTableCard({
    required this.logs,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.footer,
  });
  final List<AuditLogModel> logs;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x0C173B64), blurRadius: 20)],
    ),
    child: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF5FF)),
            horizontalMargin: 24,
            columnSpacing: 34,
            columns: [
              _column('Timestamp', Icons.calendar_today_outlined, 0),
              _column('Action', Icons.settings_rounded, 1),
              _column('Performed By', Icons.person_rounded, 2),
              _column('Target Record', Icons.description_outlined, 3),
              const DataColumn(label: SizedBox(width: 10)),
            ],
            rows: logs.map((log) => _row(log)).toList(),
          ),
        ),
        const Divider(height: 1),
        footer,
      ],
    ),
  );

  DataColumn _column(String label, IconData icon, int index) => DataColumn(
    label: Row(
      children: [
        Icon(icon, size: 20, color: BrandColors.navy),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF102A59),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
    onSort: onSort,
  );

  DataRow _row(AuditLogModel log) => DataRow(
    cells: [
      DataCell(
        Text(
          DateFormat('yyyy-MM-dd\nHH:mm:ss').format(log.timestamp),
          style: const TextStyle(color: Color(0xFF53698D), height: 1.4),
        ),
      ),
      DataCell(_ActionBadge(action: log.action)),
      DataCell(
        Text(log.performedBy, style: const TextStyle(color: Color(0xFF53698D))),
      ),
      DataCell(
        SizedBox(
          width: 470,
          child: Text(
            log.targetRecord,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF53698D)),
          ),
        ),
      ),
      const DataCell(Icon(Icons.more_vert_rounded, color: Color(0xFF274C77))),
    ],
  );
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});
  final String action;

  @override
  Widget build(BuildContext context) {
    final lower = action.toLowerCase();
    final color = lower.contains('login')
        ? BrandColors.green
        : lower.contains('updated')
        ? const Color(0xFFF39A15)
        : lower.contains('deleted')
        ? const Color(0xFFE65555)
        : lower.contains('created')
        ? BrandColors.sky
        : BrandColors.navy;
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        action,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AuditStateCard extends StatelessWidget {
  const _AuditStateCard({
    required this.icon,
    required this.message,
    this.loading = false,
  });
  final IconData icon;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(54),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        if (loading)
          const CircularProgressIndicator(color: BrandColors.green)
        else
          Icon(icon, color: BrandColors.navy, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF53698D)),
        ),
      ],
    ),
  );
}
