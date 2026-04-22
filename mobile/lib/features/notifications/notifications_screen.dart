import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<AppNotification> _notifications = [];
  bool _loading = true;
  final _dtFmt = DateFormat('dd MMM, hh:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.notifications);
      setState(() {
        _notifications = (res.data as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await _api.patch('${ApiConstants.notifications}/${n.id}/read');
      setState(() {
        _notifications = _notifications
            .map((x) => x.id == n.id
                ? AppNotification(
                    id: x.id, type: x.type, message: x.message,
                    entityId: x.entityId, actorName: x.actorName,
                    isRead: true, createdAt: x.createdAt)
                : x)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.patch(ApiConstants.notificationsReadAll);
      setState(() {
        _notifications = _notifications
            .map((x) => AppNotification(
                id: x.id, type: x.type, message: x.message,
                entityId: x.entityId, actorName: x.actorName,
                isRead: true, createdAt: x.createdAt))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _deleteOne(AppNotification n) async {
    setState(() => _notifications.removeWhere((x) => x.id == n.id));
    try {
      await _api.delete('${ApiConstants.notifications}/${n.id}');
    } catch (_) {
      // Restore on failure
      await _load();
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _notifications = []);
    try {
      await _api.delete('${ApiConstants.notifications}/all');
    } catch (_) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text('Notifications${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No notifications yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red.shade600,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteOne(n),
                        child: InkWell(
                          onTap: () => _markRead(n),
                          child: Container(
                            color: n.isRead
                                ? null
                                : const Color(0xFF3D5216).withValues(alpha: 0.05),
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: n.isRead
                                      ? Colors.grey.shade100
                                      : const Color(0xFF3D5216).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(n.typeIcon, style: const TextStyle(fontSize: 20)),
                              ),
                              title: Text(
                                n.message.split('\n').first,
                                style: TextStyle(
                                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (n.message.contains('\n'))
                                    Text(
                                      n.message.split('\n').skip(1).join('\n'),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dtFmt.format(n.createdAt),
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                              trailing: n.isRead
                                  ? null
                                  : Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3D5216),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              isThreeLine: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
