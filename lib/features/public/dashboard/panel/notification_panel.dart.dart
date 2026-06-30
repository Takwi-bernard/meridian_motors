import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

/// Notification center. State class is public so the parent Dashboard
/// can call [load] via a GlobalKey after a tab switch, keeping the
/// unread badge in the nav in sync with what's actually been read.
class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key, this.onUnreadCountChanged});

  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsPanel> createState() => NotificationsPanelState();
}

class NotificationsPanelState extends State<NotificationsPanel> {
  final NotificationService _service = NotificationService();

  bool _loading = true;
  String? _error;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchMyNotifications();
      setState(() {
        _notifications = items;
        _loading = false;
      });
      widget.onUnreadCountChanged?.call(items.where((n) => !n.isRead).length);
    } catch (_) {
      setState(() {
        _error = 'Could not load notifications.';
        _loading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    try {
      await _service.markAsRead(n.id);
      await load();
    } catch (_) {
      // Non-fatal: it'll just stay unread until the next refresh attempt.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllAsRead();
      await load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) return _errorState();

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _markAllRead,
                      child: const Text('Mark all read', style: TextStyle(color: Color(0xFF9CA3AF))),
                    ),
                ],
              ),
            ),
          ),
          if (_notifications.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _EmptyNotifications())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _notificationTile(_notifications[index]),
                  childCount: _notifications.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notificationTile(NotificationModel n) {
    final icon = n.type == 'inquiry_response' ? Icons.chat_bubble_outline : Icons.event_available;

    return InkWell(
      onTap: () => _markRead(n),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? const Color(0xFF15151A) : const Color(0xFF1D1D24),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isRead ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF26262A), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(n.message, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(_relativeTime(n.createdAt), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                margin: const EdgeInsets.only(left: 6, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: load, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              "You'll be notified here when your reservations are updated or your questions are answered.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
