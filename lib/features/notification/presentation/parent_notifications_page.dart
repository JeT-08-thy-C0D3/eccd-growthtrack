import 'package:flutter/material.dart';

import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

class ParentNotificationsPage extends StatefulWidget {
  const ParentNotificationsPage({super.key});

  @override
  State<ParentNotificationsPage> createState() =>
      _ParentNotificationsPageState();
}

class _ParentNotificationsPageState extends State<ParentNotificationsPage> {
  final _repository = NotificationRepositoryImpl();
  final _searchController = TextEditingController();
  String _parentUid = '';
  String _selectedType = 'All notifications';
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (!mounted) return;
    setState(() {
      _parentUid = user?.uid ?? '';
      _isLoadingUser = false;
    });
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    await _repository.markAsRead(notification);
    if (!mounted) return;
    switch (notification.type) {
      case 'home_activity':
        Navigator.pushNamed(context, '/home-activities');
      case 'clarification_response':
        Navigator.pushNamed(context, '/clarifications');
      default:
        Navigator.pushNamed(context, '/parent');
    }
  }

  List<NotificationModel> _filteredNotifications(
    List<NotificationModel> notifications,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return notifications.where((notification) {
      final matchesType =
          _selectedType == 'All notifications' ||
          _notificationLabel(notification.type) == _selectedType;
      final matchesSearch =
          query.isEmpty ||
          notification.title.toLowerCase().contains(query) ||
          notification.body.toLowerCase().contains(query) ||
          notification.createdAt.toLowerCase().contains(query);
      return matchesType && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF8FCFF),
      child: StreamBuilder<List<NotificationModel>>(
        stream: _repository.getParentNotificationsStream(_parentUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildStateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load notifications',
              message: 'Please check your connection and try again.',
              action: FilledButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = _filteredNotifications(snapshot.data ?? []);
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    children: [
                      _buildHero(constraints.maxWidth),
                      const SizedBox(height: 26),
                      _buildFilters(constraints.maxWidth),
                      const SizedBox(height: 26),
                      if (notifications.isEmpty)
                        _buildEmptyState(snapshot.data?.isEmpty ?? true)
                      else
                        _buildNotificationList(notifications),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(double width) {
    final compact = width < 760;
    return Container(
      width: double.infinity,
      height: compact ? 205 : 196,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 28,
        vertical: 24,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF8FF), Color(0xFFD7F0FF)],
        ),
      ),
      child: Stack(
        children: [
          if (!compact) ...[
            Positioned(
              right: 60,
              top: 17,
              child: Transform.rotate(
                angle: .45,
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF2498EA),
                  size: 54,
                ),
              ),
            ),
            Positioned(
              right: 32,
              bottom: -22,
              child: Icon(
                Icons.notifications_rounded,
                color: BrandColors.sunshine.withValues(alpha: .86),
                size: 134,
              ),
            ),
            Positioned(
              right: 188,
              bottom: -16,
              child: Icon(
                Icons.forum_rounded,
                color: Colors.white.withValues(alpha: .9),
                size: 96,
              ),
            ),
            Positioned(
              right: 286,
              bottom: -25,
              child: Icon(
                Icons.spa_rounded,
                color: BrandColors.green.withValues(alpha: .55),
                size: 110,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1599F4), Color(0xFF198BE4)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF168FEA).withValues(alpha: .22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 53,
                  ),
                ),
                const SizedBox(width: 24),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Color(0xFF07135B),
                          fontSize: 39,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        "Stay updated with important announcements, activities,\nand messages from your child's teacher.",
                        style: TextStyle(
                          color: const Color(0xFF526B9A).withValues(alpha: .9),
                          height: 1.35,
                          fontSize: compact ? 15 : 18,
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
  }

  Widget _buildFilters(double width) {
    final typeOptions = const [
      'All notifications',
      'Home activity',
      'Development update',
      'Referral',
      'Clarification',
    ];
    final search = TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration(
        hint: 'Search notifications by title, message, or date...',
        icon: Icons.search_rounded,
      ),
    );
    final filter = DropdownButtonFormField<String>(
      initialValue: _selectedType,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: _fieldDecoration(
        hint: 'Filter type',
        icon: Icons.filter_alt_outlined,
        label: 'Filter type',
      ),
      items: typeOptions
          .map((label) => DropdownMenuItem(value: label, child: Text(label)))
          .toList(),
      onChanged: (value) => setState(() => _selectedType = value!),
    );
    if (width < 760) {
      return Column(children: [search, const SizedBox(height: 14), filter]);
    }
    return Row(
      children: [
        Expanded(flex: 3, child: search),
        const SizedBox(width: 22),
        Expanded(child: filter),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    String? label,
  }) => InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF182545), size: 28),
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

  Widget _buildEmptyState(bool isActuallyEmpty) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 490),
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1798E8).withValues(alpha: .08),
          blurRadius: 30,
        ),
      ],
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 180,
            height: 145,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(54),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF43A9F3),
              size: 86,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            isActuallyEmpty
                ? 'No notifications yet'
                : 'No matching notifications',
            style: const TextStyle(
              color: Color(0xFF07135B),
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isActuallyEmpty
                ? "You’ll see announcements, activity updates, and messages\nfrom your child’s teacher here."
                : 'Try a different search term or filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7183AA),
              fontSize: 17,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: BrandColors.sky),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 18),
        action,
      ],
    ),
  );

  Widget _buildNotificationList(List<NotificationModel> notifications) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          itemCount: notifications.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = notifications[index];
            final meta = _getNotificationConfig(item.type);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: meta.color.withValues(alpha: .13),
                child: Icon(meta.icon, color: meta.color),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
              subtitle: Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                item.createdAt.split('T').first,
                style: const TextStyle(color: Color(0xFF7183AA), fontSize: 12),
              ),
              onTap: () => _handleNotificationTap(item),
            );
          },
        ),
      );

  String _notificationLabel(String type) {
    switch (type) {
      case 'home_activity':
        return 'Home activity';
      case 'development_summary':
        return 'Development update';
      case 'referral':
        return 'Referral';
      case 'clarification_response':
        return 'Clarification';
      default:
        return 'All notifications';
    }
  }

  _NotifConfig _getNotificationConfig(String type) {
    switch (type) {
      case 'home_activity':
        return _NotifConfig(Icons.home_work_rounded, Colors.indigo);
      case 'development_summary':
        return _NotifConfig(Icons.auto_awesome_rounded, Colors.amber.shade800);
      case 'referral':
        return _NotifConfig(Icons.medical_services_rounded, Colors.deepOrange);
      case 'clarification_response':
        return _NotifConfig(Icons.question_answer_rounded, Colors.green);
      default:
        return _NotifConfig(Icons.notifications_rounded, BrandColors.sky);
    }
  }
}

class _NotifConfig {
  const _NotifConfig(this.icon, this.color);
  final IconData icon;
  final Color color;
}
