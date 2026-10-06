import 'package:flutter/material.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

class ParentNotificationsPage extends StatefulWidget {
  const ParentNotificationsPage({super.key});

  @override
  State<ParentNotificationsPage> createState() => _ParentNotificationsPageState();
}

class _ParentNotificationsPageState extends State<ParentNotificationsPage> {
  final _repository = NotificationRepositoryImpl();
  String _parentUid = '';
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _parentUid = user.uid;
        _isLoadingUser = false;
      });
    }
  }

  void _handleNotificationTap(NotificationModel notification) async {
    await _repository.markAsRead(notification);

    if (!mounted) return;

    switch (notification.type) {
      case 'home_activity':
        Navigator.pushNamed(context, '/home-activities');
        break;
      case 'development_summary':
        Navigator.pushNamed(context, '/parent');
        break;
      case 'referral':
        Navigator.pushNamed(context, '/parent');
        break;
      case 'clarification_response':
        Navigator.pushNamed(context, '/clarifications');
        break;
      default:
        Navigator.pushNamed(context, '/parent');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All as Read',
            onPressed: () async {
              if (_parentUid.isNotEmpty) {
                await _repository.markAllAsRead(_parentUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications marked as read')),
                  );
                }
              }
            },
          )
        ],
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<NotificationModel>>(
              stream: _repository.getParentNotificationsStream(_parentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        const Text('No notifications yet', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final meta = _getNotificationConfig(item.type);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: item.isRead ? 0 : 2,
                      color: item.isRead
                          ? Theme.of(context).colorScheme.surfaceContainerLow
                          : meta.color.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: item.isRead
                              ? Theme.of(context).colorScheme.outlineVariant
                              : meta.color.withValues(alpha: 0.4),
                          width: item.isRead ? 1 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: meta.color.withValues(alpha: 0.15),
                          child: Icon(meta.icon, color: meta.color, size: 22),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: meta.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.body, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Child: ${item.childName}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: meta.color),
                                ),
                                Text(
                                  item.createdAt.split('T')[0],
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _handleNotificationTap(item),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  _NotifConfig _getNotificationConfig(String type) {
    switch (type) {
      case 'home_activity':
        return _NotifConfig(Icons.home_work, Colors.indigo);
      case 'development_summary':
        return _NotifConfig(Icons.auto_awesome, Colors.amber.shade900);
      case 'referral':
        return _NotifConfig(Icons.medical_services, Colors.deepOrange);
      case 'clarification_response':
        return _NotifConfig(Icons.question_answer, Colors.green);
      default:
        return _NotifConfig(Icons.notifications, Colors.blue);
    }
  }
}

class _NotifConfig {
  final IconData icon;
  final Color color;
  _NotifConfig(this.icon, this.color);
}
