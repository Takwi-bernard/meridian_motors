// inquiries_page.dart
//
// Body-only widget — lives inside AdminShell.
// No Scaffold, no AppBar.
// Supabase table: inquiries
// Realtime: listens for new INSERT on inquiries table

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';

// ═══════════════════════════════════════════════════════════
//  INQUIRIES PAGE
//  Desktop: split panel (list left, detail right)
//  Mobile:  list only, tap opens detail sheet
// ═══════════════════════════════════════════════════════════

class InquiriesPage extends StatefulWidget {
  /// Notifies AdminShell to update the sidebar unread badge.
  final void Function(int unreadCount)? onBadgeUpdate;

  const InquiriesPage({super.key, this.onBadgeUpdate});

  @override
  State<InquiriesPage> createState() => _InquiriesPageState();
}

class _InquiriesPageState extends State<InquiriesPage> {
  final _supabase   = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  RealtimeChannel? _channel;

  List<Map<String, dynamic>> _inquiries = [];
  List<Map<String, dynamic>> _filtered  = [];

  Map<String, dynamic>? _selected;

  bool   _isLoading = true;
  bool   _hasError  = false;
  bool   _isActing  = false;
  String _filter    = 'All'; // All | Unread | Read
  String _sortBy    = 'newest';

  // ── Counts
  int get _total  => _inquiries.length;
  int get _unread => _inquiries.where((e) => e['is_read'] == false).length;
  int get _read   => _inquiries.where((e) => e['is_read'] == true).length;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  //  REALTIME — new inquiries appear instantly
  // ════════════════════════════════════════════════════════
  void _subscribeRealtime() {
    _channel = _supabase
        .channel('admin_inquiries_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'inquiries',
          callback: (payload) {
            if (!mounted) return;
            _load(silent: true);
            _showNewInquiryBanner(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _showNewInquiryBanner(Map<String, dynamic> record) {
    final name    = record['name']?.toString()    ?? 'Someone';
    final subject = record['subject']?.toString() ?? 'New inquiry';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MM.brandNavy,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(20),
        content: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: MM.accentRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mail_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('New Inquiry',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text('$name: $subject',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              setState(() => _filter = 'Unread');
              _applyFilters();
            },
            child: const Text('View',
                style: TextStyle(
                    color: MM.brandBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  DATA
  // ════════════════════════════════════════════════════════
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      if (mounted) setState(() { _isLoading = true; _hasError = false; });
    }
    try {
      final data = await _supabase
          .from('inquiries')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      _inquiries = List<Map<String, dynamic>>.from(data);

      // Update sidebar badge
      widget.onBadgeUpdate?.call(_unread);

      _applyFilters();

      // Auto-select first item on desktop if nothing selected
      if (_filtered.isNotEmpty && _selected == null &&
          MediaQuery.of(context).size.width > 900) {
        _selected = _filtered.first;
        // Auto mark as read when selected on load
        if (_selected!['is_read'] == false) {
          await _markRead(_selected!['id'], true, silent: true);
        }
      }
    } catch (e) {
      debugPrint('Inquiries load error: $e');
      if (mounted && !silent) setState(() => _hasError = true);
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();

    var list = _inquiries.where((item) {
      final name    = (item['name']    ?? '').toString().toLowerCase();
      final email   = (item['email']   ?? '').toString().toLowerCase();
      final subject = (item['subject'] ?? '').toString().toLowerCase();
      final message = (item['message'] ?? '').toString().toLowerCase();

      final matchSearch = q.isEmpty ||
          name.contains(q)    ||
          email.contains(q)   ||
          subject.contains(q) ||
          message.contains(q);

      final matchFilter = _filter == 'All' ||
          (_filter == 'Unread' && item['is_read'] == false) ||
          (_filter == 'Read'   && item['is_read'] == true);

      return matchSearch && matchFilter;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'newest':
        list.sort((a, b) =>
            (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        break;
      case 'oldest':
        list.sort((a, b) =>
            (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
        break;
      case 'name':
        list.sort((a, b) =>
            (a['name'] ?? '').compareTo(b['name'] ?? ''));
        break;
    }

    setState(() => _filtered = list);
  }

  // ════════════════════════════════════════════════════════
  //  ACTIONS
  // ════════════════════════════════════════════════════════
  Future<void> _markRead(
    String id,
    bool value, {
    bool silent = false,
  }) async {
    try {
      await _supabase
          .from('inquiries')
          .update({
            'is_read':    value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      // Update locally for instant UI response
      final idx = _inquiries.indexWhere((e) => e['id'] == id);
      if (idx != -1) _inquiries[idx]['is_read'] = value;
      if (_selected?['id'] == id) _selected!['is_read'] = value;

      widget.onBadgeUpdate?.call(_unread);
      _applyFilters();

      if (!silent) {
        _toast(value ? 'Marked as read.' : 'Marked as unread.');
      }
    } catch (e) {
      if (!silent) _toast(_friendlyError(e.toString()), isError: true);
    }
  }

  Future<void> _delete(String id, String subject) async {
    final confirm = await _confirmDialog(
      title: 'Delete inquiry?',
      message: '"$subject" will be permanently deleted.',
      confirmLabel: 'Delete',
      confirmColor: MM.accentRed,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      await _supabase.from('inquiries').delete().eq('id', id);

      if (_selected?['id'] == id) setState(() => _selected = null);
      await _load(silent: true);
      _toast('Inquiry deleted.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await _confirmDialog(
      title: 'Delete all read inquiries?',
      message:
          'All ${_read} read inquiries will be permanently deleted. Unread ones will remain.',
      confirmLabel: 'Delete All Read',
      confirmColor: MM.accentRed,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      await _supabase
          .from('inquiries')
          .delete()
          .eq('is_read', true);

      if (_selected != null && _selected!['is_read'] == true) {
        setState(() => _selected = null);
      }
      await _load(silent: true);
      _toast('All read inquiries deleted.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) { _toast('All inquiries are already read.'); return; }

    setState(() => _isActing = true);
    try {
      await _supabase
          .from('inquiries')
          .update({'is_read': true})
          .eq('is_read', false);

      await _load(silent: true);
      _toast('All inquiries marked as read.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _loader();
    if (_hasError)  return _error();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return isDesktop ? _desktopLayout() : _mobileLayout();
  }

  // ── Desktop: split panel like an email client
  Widget _desktopLayout() {
    return Row(
      children: [
        // ── Left: list panel
        SizedBox(
          width: 340,
          child: Column(children: [
            _listHeader(),
            _searchBar(),
            Expanded(child: _buildList()),
          ]),
        ),
        Container(width: 1, color: MM.border),
        // ── Right: detail panel
        Expanded(
          child: _selected == null
              ? _noSelection()
              : _detailPanel(_selected!),
        ),
      ],
    );
  }

  // ── Mobile: scrollable list
  Widget _mobileLayout() {
    return RefreshIndicator(
      onRefresh: _load,
      color: MM.brandBlue,
      backgroundColor: MM.bgCard,
      child: Column(children: [
        _listHeader(),
        _searchBar(),
        Expanded(child: _buildList()),
      ]),
    );
  }

  // ── List header
  Widget _listHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inquiries',
                      style: TextStyle(
                          color: MM.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  Text(
                    '$_total total · $_unread unread',
                    style: const TextStyle(
                        color: MM.textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Sort menu
            _sortMenu(),
            const SizedBox(width: 8),
            // More actions
            _headerMoreMenu(),
          ]),
          const SizedBox(height: 12),
          // Filter chips — tappable
          Row(children: [
            _filterChip('All',    '$_total',  MM.brandBlue),
            const SizedBox(width: 8),
            _filterChip('Unread', '$_unread', MM.accentRed),
            const SizedBox(width: 8),
            _filterChip('Read',   '$_read',   MM.accentGreen),
          ]),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String count, Color color) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = label);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12) : MM.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.4) : MM.border,
          ),
        ),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: selected ? color : MM.textSub,
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(count,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _sortMenu() {
    final options = {
      'newest': 'Newest first',
      'oldest': 'Oldest first',
      'name':   'By name',
    };
    return Theme(
      data: ThemeData.dark().copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: MM.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: MM.border),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          setState(() => _sortBy = v);
          _applyFilters();
        },
        icon: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MM.border),
          ),
          child: const Icon(Icons.sort_rounded,
              color: MM.textSub, size: 17),
        ),
        itemBuilder: (_) => options.entries.map((e) {
          final sel = _sortBy == e.key;
          return PopupMenuItem(
            value: e.key,
            child: Row(children: [
              Icon(
                sel ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: sel ? MM.brandBlue : MM.textMuted,
                size: 15,
              ),
              const SizedBox(width: 10),
              Text(e.value,
                  style: TextStyle(
                      color: sel ? MM.brandBlue : MM.textPrimary,
                      fontSize: 13,
                      fontWeight: sel
                          ? FontWeight.w700 : FontWeight.w400)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _headerMoreMenu() {
    return Theme(
      data: ThemeData.dark().copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: MM.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: MM.border),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'mark_all_read') _markAllRead();
          if (v == 'delete_read')  _deleteAll();
          if (v == 'refresh')      _load();
        },
        icon: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MM.border),
          ),
          child: const Icon(Icons.more_vert_rounded,
              color: MM.textSub, size: 17),
        ),
        itemBuilder: (_) => [
          _mi('refresh',        'Refresh',
              Icons.refresh_rounded,           MM.brandBlue),
          _mi('mark_all_read',  'Mark all as read',
              Icons.done_all_rounded,          MM.accentGreen),
          const PopupMenuDivider(),
          _mi('delete_read',    'Delete all read',
              Icons.delete_sweep_rounded,      MM.accentRed),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: MM.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MM.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(
              color: MM.textPrimary, fontSize: 13),
          cursorColor: MM.brandBlue,
          decoration: InputDecoration(
            hintText: 'Search name, email, subject…',
            hintStyle: const TextStyle(
                color: MM.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: MM.textMuted, size: 18),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _applyFilters();
                    },
                    child: const Icon(Icons.close_rounded,
                        color: MM.textMuted, size: 16),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (_) => _applyFilters(),
        ),
      ),
    );
  }

  // ── Inquiry list
  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mail_rounded,
                color: MM.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty || _filter != 'All'
                  ? 'No inquiries match your filters.'
                  : 'No inquiries yet.',
              style: const TextStyle(
                  color: MM.textSub, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final item     = _filtered[i];
        final name     = item['name']?.toString()    ?? 'Unknown';
        final subject  = item['subject']?.toString() ?? 'No subject';
        final isRead   = item['is_read'] == true;
        final selected = _selected?['id'] == item['id'];
        final date     = item['created_at'] != null
            ? _fmtDate(item['created_at'].toString())
            : '';

        return GestureDetector(
          onTap: () async {
            setState(() => _selected = item);
            // Auto mark as read on open
            if (!isRead) {
              await _markRead(item['id'], true, silent: true);
            }
            // Mobile: push detail sheet
            if (mounted &&
                MediaQuery.of(context).size.width <= 900) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _InquiryDetailSheet(
                    inquiry: _selected!,
                    onMarkRead: (v) =>
                        _markRead(item['id'], v),
                    onDelete: () =>
                        _delete(item['id'], subject),
                    onReply: () =>
                        _launchMailto(item['email'] ?? '',
                            subject),
                  ),
                ),
              ).then((_) => _load(silent: true));
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? MM.brandBlue.withOpacity(0.08)
                  : isRead ? MM.bgCard : MM.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? MM.brandBlue.withOpacity(0.35)
                    : isRead ? MM.border
                        : MM.accentRed.withOpacity(0.2),
              ),
            ),
            child: Row(children: [
              // Unread dot / read check
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.transparent : MM.accentRed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isRead
                        ? MM.textMuted : MM.accentRed,
                    width: isRead ? 1.5 : 0,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(name,
                            style: TextStyle(
                                color: MM.textPrimary,
                                fontSize: 13,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(date,
                          style: const TextStyle(
                              color: MM.textMuted,
                              fontSize: 10)),
                    ]),
                    const SizedBox(height: 3),
                    Text(subject,
                        style: TextStyle(
                            color: isRead
                                ? MM.textSub : MM.textPrimary,
                            fontSize: 12,
                            fontWeight: isRead
                                ? FontWeight.w400
                                : FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── Desktop detail panel
  Widget _detailPanel(Map<String, dynamic> item) {
    final name    = item['name']?.toString()    ?? 'Unknown';
    final email   = item['email']?.toString()   ?? '';
    final phone   = item['phone']?.toString()   ?? '';
    final subject = item['subject']?.toString() ?? 'No subject';
    final message = item['message']?.toString() ?? '';
    final isRead  = item['is_read'] == true;
    final date    = item['created_at'] != null
        ? _fmtDateTime(item['created_at'].toString())
        : '';

    return Column(
      children: [
        // Detail top bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: MM.bgCard,
            border: Border(
                bottom: BorderSide(color: MM.border)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(subject,
                  style: const TextStyle(
                      color: MM.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
            ),
            // Mark read/unread
            GestureDetector(
              onTap: () => _markRead(item['id'], !isRead),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isRead
                      ? MM.bgSurface
                      : MM.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRead
                        ? MM.border
                        : MM.accentGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    isRead
                        ? Icons.mark_email_unread_rounded
                        : Icons.done_all_rounded,
                    color: isRead
                        ? MM.textSub : MM.accentGreen,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRead ? 'Mark Unread' : 'Mark Read',
                    style: TextStyle(
                        color: isRead
                            ? MM.textSub : MM.accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Reply
            if (email.isNotEmpty)
              GestureDetector(
                onTap: () => _launchMailto(email, subject),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: MM.brandBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: MM.brandBlue.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.reply_rounded,
                        color: MM.brandBlue, size: 15),
                    SizedBox(width: 6),
                    Text('Reply',
                        style: TextStyle(
                            color: MM.brandBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            const SizedBox(width: 8),
            // Delete
            GestureDetector(
              onTap: () => _delete(item['id'], subject),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: MM.accentRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: MM.accentRed.withOpacity(0.25)),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: MM.accentRed, size: 17),
              ),
            ),
          ]),
        ),

        // Detail body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MM.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MM.border),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          MM.brandBlue.withOpacity(0.15),
                      child: Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: MM.brandBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: MM.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          if (email.isNotEmpty)
                            GestureDetector(
                              onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: email));
                                _toast('Email copied.');
                              },
                              child: Row(children: [
                                Text(email,
                                    style: const TextStyle(
                                        color: MM.brandBlue,
                                        fontSize: 12)),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy_rounded,
                                    color: MM.textMuted,
                                    size: 11),
                              ]),
                            ),
                          if (phone.isNotEmpty)
                            Text(phone,
                                style: const TextStyle(
                                    color: MM.textSub,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(date,
                            style: const TextStyle(
                                color: MM.textMuted,
                                fontSize: 11)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isRead
                                ? MM.accentGreen.withOpacity(0.1)
                                : MM.accentRed.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(20),
                            border: Border.all(
                              color: isRead
                                  ? MM.accentGreen.withOpacity(0.3)
                                  : MM.accentRed.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            isRead ? 'Read' : 'Unread',
                            style: TextStyle(
                                color: isRead
                                    ? MM.accentGreen
                                    : MM.accentRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // Message body
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MM.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MM.border),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.notes_rounded,
                            color: MM.accentPurple, size: 16),
                        const SizedBox(width: 8),
                        const Text('Message',
                            style: TextStyle(
                                color: MM.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                      Divider(color: MM.border, height: 20),
                      Text(
                        message.isEmpty
                            ? 'No message content.' : message,
                        style: const TextStyle(
                            color: MM.textSub,
                            fontSize: 14,
                            height: 1.7),
                      ),
                    ],
                  ),
                ),

                // Reply prompt
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _launchMailto(
                        email, subject),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MM.brandBlue.withOpacity(0.06),
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                            color: MM.brandBlue.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.reply_rounded,
                            color: MM.brandBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Reply to this inquiry',
                                  style: TextStyle(
                                      color: MM.brandBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text('Opens mail client to $email',
                                  style: const TextStyle(
                                      color: MM.textMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded,
                            color: MM.brandBlue, size: 15),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _noSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: MM.bgSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MM.border),
            ),
            child: const Icon(Icons.mail_rounded,
                color: MM.textMuted, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('Select an inquiry',
              style: TextStyle(
                  color: MM.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Click any inquiry from the list to read it.',
              style: TextStyle(
                  color: MM.textSub, fontSize: 13)),
          if (_unread > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: MM.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: MM.accentRed.withOpacity(0.25)),
              ),
              child: Text('$_unread unread',
                  style: const TextStyle(
                      color: MM.accentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════
  void _launchMailto(String email, String subject) {
    // Copy email to clipboard as fallback
    // For proper mailto: use url_launcher package:
    // launchUrl(Uri.parse('mailto:$email?subject=Re: $subject'));
    Clipboard.setData(ClipboardData(text: email));
    _toast('Email copied: $email\nOpen your mail client to reply.');
  }

  PopupMenuItem<String> _mi(
      String val, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color == MM.textSub
                    ? MM.textPrimary : color,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MM.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: const TextStyle(
                  color: MM.textPrimary,
                  fontWeight: FontWeight.w700)),
          content: Text(message,
              style: const TextStyle(
                  color: MM.textSub, fontSize: 14,
                  height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: MM.textSub)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(confirmLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? MM.accentRed : MM.accentGreen,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
        ]),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('network')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }

  String _fmtDate(String raw) {
    try {
      final dt  = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month &&
          dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      }
      final m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}';
    } catch (_) { return ''; }
  }

  String _fmtDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final m  = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h   = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min';
    } catch (_) { return raw; }
  }

  Widget _loader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 34, height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(MM.brandBlue),
          ),
        ),
        SizedBox(height: 16),
        Text('Loading inquiries…',
            style: TextStyle(color: MM.textSub, fontSize: 14)),
      ],
    ),
  );

  Widget _error() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded,
            color: MM.textMuted, size: 48),
        const SizedBox(height: 16),
        const Text('Could not load inquiries.',
            style: TextStyle(
                color: MM.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: MM.brandBlue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
          ),
          icon: const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 18),
          label: const Text('Try again',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  Mobile detail sheet
// ═══════════════════════════════════════════════════════════
class _InquiryDetailSheet extends StatelessWidget {
  final Map<String, dynamic> inquiry;
  final void Function(bool) onMarkRead;
  final VoidCallback onDelete;
  final VoidCallback onReply;

  const _InquiryDetailSheet({
    required this.inquiry,
    required this.onMarkRead,
    required this.onDelete,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final name    = inquiry['name']?.toString()    ?? 'Unknown';
    final email   = inquiry['email']?.toString()   ?? '';
    final phone   = inquiry['phone']?.toString()   ?? '';
    final subject = inquiry['subject']?.toString() ?? 'No subject';
    final message = inquiry['message']?.toString() ?? '';
    final isRead  = inquiry['is_read'] == true;

    return Theme(
      data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: MM.bgDeep),
      child: Scaffold(
        backgroundColor: MM.bgDeep,
        appBar: AppBar(
          backgroundColor: MM.bgCard,
          foregroundColor: MM.textPrimary,
          elevation: 0,
          title: Text(subject,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: MM.border),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isRead
                    ? Icons.mark_email_unread_rounded
                    : Icons.done_all_rounded,
                color: isRead ? MM.textSub : MM.accentGreen,
                size: 20,
              ),
              onPressed: () {
                onMarkRead(!isRead);
                Navigator.pop(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: MM.accentRed, size: 20),
              onPressed: () {
                onDelete();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: MM.brandBlue.withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: MM.brandBlue,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: MM.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                color: MM.textSub, fontSize: 12)),
                      if (phone.isNotEmpty)
                        Text(phone,
                            style: const TextStyle(
                                color: MM.textSub, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              // Message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MM.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MM.border),
                ),
                child: Text(
                  message.isEmpty ? 'No message.' : message,
                  style: const TextStyle(
                      color: MM.textSub,
                      fontSize: 14,
                      height: 1.7),
                ),
              ),
              const SizedBox(height: 16),
              // Reply
              GestureDetector(
                onTap: onReply,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MM.brandBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: MM.brandBlue.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.reply_rounded,
                          color: MM.brandBlue, size: 18),
                      SizedBox(width: 8),
                      Text('Reply via Email',
                          style: TextStyle(
                              color: MM.brandBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}