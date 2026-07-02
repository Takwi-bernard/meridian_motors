import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

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
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.fetchMyNotifications();
      setState(() { _notifications = items; _loading = false; });
      widget.onUnreadCountChanged?.call(items.where((n) => !n.isRead).length);
    } catch (_) {
      setState(() { _error = 'Could not load notifications.'; _loading = false; });
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    try {
      await _service.markAsRead(n.id);
      await load();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllAsRead();
      await load();
    } catch (_) {}
  }

  /// Groups notifications into Today / Yesterday / Earlier.
  Map<String, List<NotificationModel>> get _grouped {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<NotificationModel>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final n in _notifications) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (d == today) {
        groups['Today']!.add(n);
      } else if (d == yesterday) {
        groups['Yesterday']!.add(n);
      } else {
        groups['Earlier']!.add(n);
      }
    }

    // Remove empty groups so we don't show empty section headers.
    groups.removeWhere((_, list) => list.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();

    final unread = _notifications.where((n) => !n.isRead).length;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(unread)),
          if (_notifications.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
          else
            ..._buildGroupedSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          const Icon(Icons.notifications, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Notifications',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Mark all read', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSlivers() {
    final slivers = <Widget>[];
    _grouped.forEach((label, items) {
      slivers.add(SliverToBoxAdapter(child: _sectionLabel(label)));
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _tile(items[i]),
              childCount: items.length,
            ),
          ),
        ),
      );
    });
    return slivers;
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _tile(NotificationModel n) {
    final isReservation = n.type == 'reservation_status';
    final Color accentColor = _accentColor(n);

    return InkWell(
      onTap: () => _markRead(n),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? const Color(0xFF15151A) : const Color(0xFF1C1C24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead
                ? Colors.white.withOpacity(0.05)
                : accentColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReservation ? Icons.event_available_outlined : Icons.chat_bubble_outline,
                size: 16,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 4),
                  Text(n.message,
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(_relativeTime(n.createdAt),
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                ],
              ),
            ),
            if (!n.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _accentColor(NotificationModel n) {
    if (n.type == 'inquiry_response') return const Color(0xFF16A34A);
    // Reservation: color based on message content
    final msg = n.message.toLowerCase();
    if (msg.contains('approved')) return const Color(0xFF16A34A);
    if (msg.contains('rejected') || msg.contains('declined')) return const Color(0xFFDC2626);
    if (msg.contains('completed')) return const Color(0xFF2563EB);
    return const Color(0xFFCA8A04); // pending / updated
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _loadingState() => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading notifications...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ]),
      );

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF1A1A1D), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 32),
          ),
          const SizedBox(height: 20),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: Colors.white38, size: 40),
            ),
            const SizedBox(height: 24),
            const Text("You're all caught up",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text(
              "We'll notify you here when your\nreservations are updated or your\nquestions are answered.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
