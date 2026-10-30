import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/parent_feedback_repository.dart';
import '../domain/parent_feedback_model.dart';
import 'parent_feedback_page.dart';

class ParentFeedbackHistoryPage extends StatefulWidget {
  const ParentFeedbackHistoryPage({super.key});

  @override
  State<ParentFeedbackHistoryPage> createState() =>
      _ParentFeedbackHistoryPageState();
}

class _ParentFeedbackHistoryPageState extends State<ParentFeedbackHistoryPage> {
  final _repository = ParentFeedbackRepositoryImpl();
  final _searchController = TextEditingController();
  List<ParentFeedbackModel> _history = const [];
  List<ChildModel> _children = const [];
  String _query = '';
  String _period = 'All time';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final user = await AuthRepositoryImpl().getCurrentUser();
      if (user == null) return;
      final children = await DatabaseHelper.instance.readChildrenByParent(
        user.uid,
      );
      final records = <ParentFeedbackModel>[];
      for (final child in children) {
        records.addAll(await _repository.getFeedbackHistory(child.childId));
      }
      records.sort((a, b) => b.submissionDate.compareTo(a.submissionDate));
      if (mounted)
        setState(() {
          _children = children;
          _history = records;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _children = const [];
          _history = const [];
        });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ParentFeedbackModel> get _filtered {
    final now = DateTime.now();
    return _history.where((item) {
      final haystack =
          '${item.parentObservation} ${item.notes} ${item.assistanceLevel} ${item.submissionDate}'
              .toLowerCase();
      if (!haystack.contains(_query.toLowerCase())) {
        return false;
      }
      final date = DateTime.tryParse(item.submissionDate);
      if (date == null || _period == 'All time') {
        return true;
      }
      final days = _period == 'This week' ? 7 : 31;
      return date.isAfter(now.subtract(Duration(days: days)));
    }).toList();
  }

  Future<void> _edit(ParentFeedbackModel item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ParentFeedbackPage(feedback: item)),
    );
    if (changed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF8FCFF),
    child: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    children: [
                      const _HistoryHero(),
                      const SizedBox(height: 26),
                      _filters(constraints.maxWidth),
                      const SizedBox(height: 24),
                      if (_filtered.isEmpty)
                        const _HistoryEmptyState()
                      else
                        _records(_filtered),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );

  Widget _filters(double width) {
    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: _decoration(
        hint: 'Search observation, notes, or date...',
        icon: Icons.search_rounded,
      ),
    );
    final period = DropdownButtonFormField<String>(
      initialValue: _period,
      isExpanded: true,
      decoration: _decoration(
        hint: 'Filter date',
        label: 'Filter date',
        icon: Icons.filter_alt_outlined,
      ),
      items: const [
        'All time',
        'This week',
        'This month',
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _period = v ?? 'All time'),
    );
    return width < 760
        ? Column(children: [search, const SizedBox(height: 14), period])
        : Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 22),
              Expanded(child: period),
            ],
          );
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    String? label,
  }) => InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF17284C), size: 28),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFD2E0F1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFD2E0F1)),
    ),
  );

  Widget _records(List<ParentFeedbackModel> items) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (context, index) {
      final item = items[index];
      final child = _children
          .where((c) => c.childId == item.childId)
          .firstOrNull;
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 14,
          ),
          leading: CircleAvatar(
            radius: 27,
            backgroundColor: BrandColors.sky.withValues(alpha: .12),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: BrandColors.sky,
            ),
          ),
          title: Text(
            child == null
                ? item.childId
                : '${child.firstName} ${child.lastName}',
            style: const TextStyle(
              color: Color(0xFF07135B),
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            item.parentObservation,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            onPressed: () => _edit(item),
            icon: const Icon(Icons.edit_outlined, color: BrandColors.sky),
          ),
        ),
      );
    },
  );
}

class _HistoryHero extends StatelessWidget {
  const _HistoryHero();
  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFEAF8FF), Color(0xFFD8F0FF)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: 23,
          bottom: -46,
          child: Icon(
            Icons.family_restroom_rounded,
            size: 224,
            color: const Color(0xFFFF8494).withValues(alpha: .75),
          ),
        ),
        Positioned(
          right: 192,
          bottom: -16,
          child: Icon(
            Icons.spa_rounded,
            size: 112,
            color: BrandColors.green.withValues(alpha: .52),
          ),
        ),
        Positioned(
          right: 190,
          top: 24,
          child: const Icon(
            Icons.history_rounded,
            color: Color(0xFFFFA637),
            size: 48,
          ),
        ),
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF168FEA),
                borderRadius: BorderRadius.circular(23),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 25),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feedback History',
                    style: TextStyle(
                      color: Color(0xFF07135B),
                      fontSize: 39,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'View and track all your submitted observations and feedback.',
                    style: TextStyle(color: Color(0xFF526F9E), fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 490),
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: BrandColors.sky.withValues(alpha: .08),
          blurRadius: 28,
        ),
      ],
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 170,
            height: 145,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.assignment_rounded,
              color: BrandColors.sky,
              size: 86,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'No feedback records found',
            style: TextStyle(
              color: Color(0xFF07135B),
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your submitted observations, notes, and feedback\nwill appear here once you start sharing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7183AA),
              fontSize: 17,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}
