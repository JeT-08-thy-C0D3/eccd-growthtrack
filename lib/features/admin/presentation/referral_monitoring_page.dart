import 'package:flutter/material.dart';

import '../../../shared/widgets/brand_widgets.dart';
import '../../referral/data/referral_repository.dart';
import '../../referral/domain/referral_model.dart';

class ReferralMonitoringPage extends StatefulWidget {
  const ReferralMonitoringPage({super.key});

  @override
  State<ReferralMonitoringPage> createState() => _ReferralMonitoringPageState();
}

class _ReferralMonitoringPageState extends State<ReferralMonitoringPage> {
  final ReferralRepository _repository = ReferralRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allReferrals = [];
  List<Map<String, dynamic>> _filteredReferrals = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  String? _errorMessage;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  static const _statusFilters = [
    'All',
    'Pending',
    'Referred',
    'For Follow-Up',
    'Completed',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.getAllReferrals();
      if (!mounted) return;
      setState(() {
        _allReferrals = data;
        _applyFilterAndSort();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load referral records.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilterAndSort() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredReferrals = _allReferrals.where((referral) {
      final childName =
          '${referral['first_name'] ?? ''} ${referral['last_name'] ?? ''}'
              .toLowerCase();
      final concern = '${referral['concern'] ?? ''}'.toLowerCase();
      final status = '${referral['status'] ?? ''}'.toLowerCase();
      return (query.isEmpty ||
              childName.contains(query) ||
              concern.contains(query) ||
              status.contains(query)) &&
          (_selectedFilter == 'All' || referral['status'] == _selectedFilter);
    }).toList();

    if (_sortColumnIndex != null) {
      _filteredReferrals.sort((a, b) {
        final values = switch (_sortColumnIndex) {
          0 => (
            '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}',
            '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}',
          ),
          1 => ('${a['concern'] ?? ''}', '${b['concern'] ?? ''}'),
          2 => ('${a['referral_date'] ?? ''}', '${b['referral_date'] ?? ''}'),
          3 => ('${a['follow_up_date'] ?? ''}', '${b['follow_up_date'] ?? ''}'),
          _ => ('${a['status'] ?? ''}', '${b['status'] ?? ''}'),
        };
        final result = values.$1.compareTo(values.$2);
        return _sortAscending ? result : -result;
      });
    }
  }

  void _updateFilter() => setState(() {
    _currentPage = 0;
    _applyFilterAndSort();
  });

  void _sort(int index, bool ascending) => setState(() {
    _sortColumnIndex = index;
    _sortAscending = ascending;
    _applyFilterAndSort();
  });

  Future<void> _updateStatus(Map<String, dynamic> referralData) async {
    final referral = ReferralModel.fromMap(referralData);
    final status = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Referral Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusFilters
              .where((item) => item != 'All')
              .map(
                (item) => RadioListTile<String>(
                  title: Text(item),
                  value: item,
                  groupValue: referral.status,
                  onChanged: (value) => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (status == null || status == referral.status) return;
    await _repository.updateReferral(referral.copyWith(status: status));
    await _loadReferrals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final total = _filteredReferrals.length;
      final pages = (total / _itemsPerPage).ceil();
      if (_currentPage >= pages && pages > 0) _currentPage = pages - 1;
      final records = _filteredReferrals
          .skip(_currentPage * _itemsPerPage)
          .take(_itemsPerPage)
          .toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReferralHero(compact: constraints.maxWidth < 800),
                const SizedBox(height: 20),
                _buildFilters(constraints.maxWidth < 720),
                const SizedBox(height: 24),
                if (_isLoading)
                  const _ReferralState(
                    message: 'Loading referral records...',
                    loading: true,
                  )
                else if (_errorMessage != null)
                  _ReferralState(
                    message: _errorMessage!,
                    icon: Icons.error_outline_rounded,
                    action: _loadReferrals,
                  )
                else if (records.isEmpty)
                  const _ReferralState(
                    message: 'No matching referral records found.',
                    detail: 'Try adjusting your search or filters, or wait for new referral records to appear.',
                    icon: Icons.assignment_outlined,
                  )
                else
                  _ReferralTable(
                    records: records,
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    onSort: _sort,
                    onUpdateStatus: _updateStatus,
                    footer: _pagination(total, pages),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildFilters(bool stacked) {
    final search = TextField(
      controller: _searchController,
      onChanged: (value) {
        _searchQuery = value;
        _updateFilter();
      },
      decoration: _fieldDecoration(
        hint: 'Search referrals by child, concern, or status...',
        icon: Icons.search_rounded,
      ),
    );
    final filter = DropdownButtonFormField<String>(
      initialValue: _selectedFilter,
      isExpanded: true,
      decoration: _fieldDecoration(
        hint: 'Filter status',
        icon: Icons.filter_list_rounded,
      ),
      items: _statusFilters
          .map((status) => DropdownMenuItem(value: status, child: Text(status)))
          .toList(),
      onChanged: (value) {
        _selectedFilter = value ?? 'All';
        _updateFilter();
      },
    );
    return stacked
        ? Column(children: [search, const SizedBox(height: 12), filter])
        : Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 16),
              Expanded(child: filter),
            ],
          );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    hintText: hint,
    labelText: icon == Icons.filter_list_rounded ? 'Filter status' : null,
    prefixIcon: Icon(icon, color: BrandColors.navy),
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
  );

  Widget _pagination(int total, int pages) {
    final start = _currentPage * _itemsPerPage + 1;
    final end = ((_currentPage + 1) * _itemsPerPage).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start to $end of $total referrals',
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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: BrandColors.sky,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentPage + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage + 1 < pages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReferralHero extends StatelessWidget {
  const _ReferralHero({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: compact ? 258 : 182,
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
          right: -35,
          top: -58,
          child: _HeroOrb(
            size: 230,
            color: BrandColors.sky.withValues(alpha: .14),
          ),
        ),
        Positioned(
          right: 110,
          bottom: -75,
          child: _HeroOrb(
            size: 190,
            color: BrandColors.green.withValues(alpha: .12),
          ),
        ),
        if (!compact)
          const Positioned(
            right: 56,
            bottom: 0,
            child: _ReferralIllustration(),
          ),
        Positioned(
          left: compact ? 24 : 28,
          top: compact ? 24 : 42,
          right: compact ? 24 : 500,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _referralIcon(compact: true),
                    const SizedBox(height: 14),
                    _referralText(compact: true),
                  ],
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _referralIcon(),
              const SizedBox(width: 22),
              Expanded(child: _referralText()),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _referralIcon({bool compact = false}) => Container(
    width: compact ? 58 : 68,
    height: compact ? 58 : 68,
    decoration: BoxDecoration(
      color: const Color(0xFF1E9CE5),
      borderRadius: BorderRadius.circular(compact ? 16 : 18),
    ),
    child: Icon(
      Icons.medical_services_rounded,
      color: Colors.white,
      size: compact ? 33 : 39,
    ),
  );

  Widget _referralText({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'MSWD Referral Monitoring',
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
        'Track and monitor child referrals, concerns, and their current status.',
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

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ReferralIllustration extends StatelessWidget {
  const _ReferralIllustration();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 325,
    height: 174,
    child: Stack(
      children: [
        Positioned(
          left: 55,
          top: 15,
          child: Container(
            width: 125,
            height: 150,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF5FAAF2), width: 6),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.add_circle_rounded,
                  color: Color(0xFFF25778),
                  size: 42,
                ),
                SizedBox(height: 14),
                _ReferralLine(),
                SizedBox(height: 8),
                _ReferralLine(),
                SizedBox(height: 8),
                _ReferralLine(),
              ],
            ),
          ),
        ),
        const Positioned(
          right: 26,
          bottom: 24,
          child: Icon(
            Icons.child_care_rounded,
            color: Color(0xFFF29378),
            size: 92,
          ),
        ),
        const Positioned(
          right: 0,
          top: 30,
          child: Icon(
            Icons.favorite_rounded,
            color: Color(0xFFF28AAD),
            size: 34,
          ),
        ),
      ],
    ),
  );
}

class _ReferralLine extends StatelessWidget {
  const _ReferralLine();
  @override
  Widget build(BuildContext context) => Container(
    width: 78,
    height: 7,
    decoration: BoxDecoration(
      color: const Color(0xFFD1E9FF),
      borderRadius: BorderRadius.circular(5),
    ),
  );
}

class _ReferralTable extends StatelessWidget {
  const _ReferralTable({
    required this.records,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onUpdateStatus,
    required this.footer,
  });
  final List<Map<String, dynamic>> records;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final ValueChanged<Map<String, dynamic>> onUpdateStatus;
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
            columnSpacing: 28,
            columns: [
              _column('Child Name', Icons.child_care_rounded, 0),
              _column('Concern', Icons.assignment_late_rounded, 1),
              _column('Referral Date', Icons.calendar_month_rounded, 2),
              _column('Follow-Up', Icons.event_repeat_rounded, 3),
              _column('Status', Icons.flag_rounded, 4),
              const DataColumn(label: Text('')),
            ],
            rows: records.map(_row).toList(),
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
        Icon(icon, size: 19, color: BrandColors.navy),
        const SizedBox(width: 9),
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

  DataRow _row(Map<String, dynamic> record) {
    final status = '${record['status'] ?? 'Pending'}';
    return DataRow(
      cells: [
        DataCell(
          Text(
            '${record['first_name'] ?? ''} ${record['last_name'] ?? ''}',
            style: const TextStyle(color: Color(0xFF53698D)),
          ),
        ),
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              '${record['concern'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF53698D)),
            ),
          ),
        ),
        DataCell(
          Text(
            '${record['referral_date'] ?? '—'}',
            style: const TextStyle(color: Color(0xFF53698D)),
          ),
        ),
        DataCell(
          Text(
            '${record['follow_up_date'] ?? '—'}',
            style: const TextStyle(color: Color(0xFF53698D)),
          ),
        ),
        DataCell(_StatusBadge(status: status)),
        DataCell(
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: BrandColors.sky),
            tooltip: 'Update status',
            onPressed: () => onUpdateStatus(record),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Pending' => const Color(0xFFF39A15),
      'Referred' => BrandColors.sky,
      'For Follow-Up' => const Color(0xFF9B34D2),
      'Completed' => BrandColors.green,
      'Closed' => Colors.grey,
      _ => BrandColors.navy,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReferralState extends StatelessWidget {
  const _ReferralState({
    required this.message,
    this.detail,
    this.icon,
    this.loading = false,
    this.action,
  });
  final String message;
  final String? detail;
  final IconData? icon;
  final bool loading;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 420),
    padding: const EdgeInsets.all(42),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x0C173B64), blurRadius: 20)],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const CircularProgressIndicator(color: BrandColors.green)
        else
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: BrandColors.sky.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.assignment_outlined,
              color: BrandColors.sky,
              size: 66,
            ),
          ),
        const SizedBox(height: 24),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF10184F),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 460,
            child: Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7182A5),
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ],
    ),
  );
}
