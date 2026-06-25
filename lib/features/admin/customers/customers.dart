// customers_page.dart
//
// Body-only widget — lives inside AdminShell.
// No Scaffold, no AppBar.
// Supabase table: profiles

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';

// ═══════════════════════════════════════════════════════════
//  CUSTOMERS PAGE
// ═══════════════════════════════════════════════════════════

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _supabase   = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _users    = [];
  List<Map<String, dynamic>> _filtered = [];

  Map<String, dynamic>? _selected;

  bool   _isLoading   = true;
  bool   _hasError    = false;
  bool   _isActing    = false;
  String _roleFilter  = 'All';
  String _statusFilter = 'All';
  String _sortBy      = 'newest';

  // ── Counts
  int get _totalUsers     => _users.length;
  int get _totalAdmins    => _users.where((e) => e['role'] == 'admin').length;
  int get _totalCustomers => _users.where((e) => e['role'] == 'customer').length;
  int get _activeUsers    => _users.where((e) => e['is_active'] == true).length;
  int get _inactiveUsers  => _users.where((e) => e['is_active'] == false).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      _users = List<Map<String, dynamic>>.from(data);
      _applyFilters();
    } catch (e) {
      debugPrint('Customers load error: $e');
      if (mounted && !silent) setState(() => _hasError = true);
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();

    var list = _users.where((u) {
      final name  = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email']     ?? '').toString().toLowerCase();
      final phone = (u['phone']     ?? '').toString().toLowerCase();

      final matchSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q);

      final matchRole = _roleFilter == 'All' ||
          (u['role'] ?? '').toString().toLowerCase() ==
              _roleFilter.toLowerCase();

      final matchStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Active'   && u['is_active'] == true) ||
          (_statusFilter == 'Inactive' && u['is_active'] != true);

      return matchSearch && matchRole && matchStatus;
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
            (a['full_name'] ?? '').compareTo(b['full_name'] ?? ''));
        break;
    }

    setState(() => _filtered = list);
  }

  // ════════════════════════════════════════════════════════
  //  ACTIONS
  // ════════════════════════════════════════════════════════
  Future<void> _updateRole(String userId, String role, String name) async {
    final isPromoting = role == 'admin';
    final confirm = await _confirmDialog(
      title: isPromoting ? 'Promote to Admin?' : 'Demote to Customer?',
      message: isPromoting
          ? '$name will gain full admin access to this panel. Make sure this is intentional.'
          : '$name will lose admin privileges and become a regular customer.',
      confirmLabel: isPromoting ? 'Promote' : 'Demote',
      confirmColor: isPromoting ? MM.accentAmber : MM.accentRed,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      await _supabase.from('profiles').update({
        'role':       role,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await _load(silent: true);
      // Refresh selected user
      if (_selected != null && _selected!['id'] == userId) {
        _selected = _users.firstWhere(
          (u) => u['id'] == userId,
          orElse: () => _selected!,
        );
      }
      _toast('${name} is now ${role == 'admin' ? 'an Admin' : 'a Customer'}.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _updateStatus(
      String userId, bool active, String name) async {
    final confirm = await _confirmDialog(
      title: active ? 'Activate account?' : 'Deactivate account?',
      message: active
          ? '$name will be able to log in and use the app.'
          : '$name will be blocked from logging in.',
      confirmLabel: active ? 'Activate' : 'Deactivate',
      confirmColor: active ? MM.accentGreen : MM.accentRed,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      await _supabase.from('profiles').update({
        'is_active':  active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await _load(silent: true);
      if (_selected != null && _selected!['id'] == userId) {
        _selected = _users.firstWhere(
          (u) => u['id'] == userId,
          orElse: () => _selected!,
        );
      }
      _toast('${name} account ${active ? 'activated' : 'deactivated'}.');
    } catch (e) {
      _toast(_friendlyError(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _deleteUser(String userId, String name) async {
    final confirm = await _confirmDialog(
      title: 'Delete account?',
      message:
          '$name\'s account and all associated data will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: MM.accentRed,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      await _supabase.from('profiles').delete().eq('id', userId);
      setState(() => _selected = null);
      await _load(silent: true);
      _toast('$name\'s account deleted.');
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

    return RefreshIndicator(
      onRefresh: _load,
      color: MM.brandBlue,
      backgroundColor: MM.bgCard,
      child: isDesktop ? _desktopLayout() : _mobileLayout(),
    );
  }

  // ── Desktop: split panel
  Widget _desktopLayout() {
    return Row(
      children: [
        // Left — list
        SizedBox(
          width: 360,
          child: Column(
            children: [
              _buildListHeader(),
              _buildSearchBar(),
              Expanded(child: _buildList()),
            ],
          ),
        ),
        Container(width: 1, color: MM.border),
        // Right — details
        Expanded(
          child: _selected == null
              ? _noSelection()
              : _buildDetails(_selected!),
        ),
      ],
    );
  }

  // ── Mobile: list only, tap → push details
  Widget _mobileLayout() {
    return Column(
      children: [
        _buildListHeader(),
        _buildSearchBar(),
        Expanded(child: _buildList()),
      ],
    );
  }

  // ── List header with stats
  Widget _buildListHeader() {
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
                  const Text('Customers',
                      style: TextStyle(
                          color: MM.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  Text('$_totalUsers users · $_activeUsers active',
                      style: const TextStyle(
                          color: MM.textSub, fontSize: 12)),
                ],
              ),
            ),
            _sortMenu(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: MM.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MM.border),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: MM.brandBlue, size: 18),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // Stat chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _statChip('All',      '$_totalUsers',    MM.brandBlue,   'All'),
              _statChip('Customers','$_totalCustomers',MM.accentGreen, 'Customer'),
              _statChip('Admins',   '$_totalAdmins',   MM.accentRed,   'Admin'),
              _statChip('Active',   '$_activeUsers',   MM.accentGreen, null,
                  statusFilter: 'Active'),
              _statChip('Inactive', '$_inactiveUsers', MM.textSub,     null,
                  statusFilter: 'Inactive'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    String label,
    String count,
    Color color,
    String? roleValue, {
    String? statusFilter,
  }) {
    final selected = statusFilter != null
        ? _statusFilter == statusFilter
        : roleValue == null
            ? _roleFilter == 'All'
            : _roleFilter == roleValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (statusFilter != null) {
            _statusFilter = selected ? 'All' : statusFilter;
          } else {
            _roleFilter   = selected ? 'All' : (roleValue ?? 'All');
          }
        });
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
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
                horizontal: 6, vertical: 1),
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
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MM.border),
          ),
          child: const Icon(Icons.sort_rounded,
              color: MM.textSub, size: 18),
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
                size: 16,
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

  Widget _buildSearchBar() {
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
            hintText: 'Search by name, email or phone…',
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

  // ── User list
  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_rounded,
                color: MM.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty ||
                      _roleFilter != 'All' ||
                      _statusFilter != 'All'
                  ? 'No users match your filters.'
                  : 'No users found.',
              style: const TextStyle(
                  color: MM.textSub, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final user     = _filtered[i];
        final name     = user['full_name']?.toString() ?? 'Unknown';
        final email    = user['email']?.toString()     ?? '';
        final role     = user['role']?.toString()      ?? 'customer';
        final isActive = user['is_active'] == true;
        final selected = _selected?['id'] == user['id'];

        return GestureDetector(
          onTap: () {
            setState(() => _selected = user);
            // On mobile, push details page
            if (MediaQuery.of(context).size.width <= 900) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _CustomerDetailSheet(
                    user: user,
                    isActing: _isActing,
                    onUpdateRole: (r) =>
                        _updateRole(user['id'], r, name),
                    onUpdateStatus: (a) =>
                        _updateStatus(user['id'], a, name),
                    onDelete: () =>
                        _deleteUser(user['id'], name),
                  ),
                ),
              ).then((_) => _load(silent: true));
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? MM.brandBlue.withOpacity(0.08) : MM.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? MM.brandBlue.withOpacity(0.35)
                    : MM.border,
              ),
            ),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: MM.brandBlue.withOpacity(0.15),
                backgroundImage: user['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null,
                child: user['avatar_url'] == null
                    ? Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: MM.brandBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: MM.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    Text(email,
                        style: const TextStyle(
                            color: MM.textSub, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _roleBadge(role),
                  const SizedBox(height: 4),
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? MM.accentGreen : MM.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── Desktop details panel
  Widget _buildDetails(Map<String, dynamic> user) {
    final name     = user['full_name']?.toString() ?? 'Unknown';
    final email    = user['email']?.toString()     ?? '';
    final phone    = user['phone']?.toString()     ?? '';
    final role     = user['role']?.toString()      ?? 'customer';
    final isActive = user['is_active'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Row(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: MM.brandBlue.withOpacity(0.15),
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? Text(
                      name.isNotEmpty
                          ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: MM.brandBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 26),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: MM.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(
                          color: MM.textSub, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _roleBadge(role),
                    const SizedBox(width: 8),
                    _activeBadge(isActive),
                  ]),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Info card
          _infoCard('Profile Information', [
            if (phone.isNotEmpty) _infoRow('Phone',   phone,  Icons.phone_rounded),
            _infoRow('Role',    role[0].toUpperCase() + role.substring(1),
                Icons.shield_rounded),
            _infoRow('Status',  isActive ? 'Active' : 'Inactive',
                Icons.circle, color: isActive ? MM.accentGreen : MM.accentRed),
            if (user['created_at'] != null)
              _infoRow('Joined',  _fmtDate(user['created_at'].toString()),
                  Icons.calendar_today_rounded),
            if (user['updated_at'] != null)
              _infoRow('Updated', _fmtDate(user['updated_at'].toString()),
                  Icons.update_rounded),
            _infoRow('User ID',  user['id']?.toString() ?? '—',
                Icons.fingerprint_rounded, copyable: true),
          ]),

          const SizedBox(height: 20),

          // Actions
          if (_isActing)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(
                backgroundColor: MM.bgSurface,
                valueColor: AlwaysStoppedAnimation(MM.brandBlue),
              ),
            ),

          AbsorbPointer(
            absorbing: _isActing,
            child: Opacity(
              opacity: _isActing ? 0.5 : 1,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // Activate / Deactivate
                  if (!isActive)
                    _actionBtn('Activate', Icons.check_circle_rounded,
                        MM.accentGreen, () =>
                            _updateStatus(user['id'], true, name))
                  else
                    _actionBtn('Deactivate', Icons.block_rounded,
                        MM.accentRed, () =>
                            _updateStatus(user['id'], false, name)),

                  // Promote / Demote
                  if (role != 'admin')
                    _actionBtn('Make Admin', Icons.admin_panel_settings_rounded,
                        MM.accentAmber, () =>
                            _updateRole(user['id'], 'admin', name))
                  else
                    _actionBtn('Make Customer', Icons.person_rounded,
                        MM.textSub, () =>
                            _updateRole(user['id'], 'customer', name)),

                  // Delete
                  _actionBtn('Delete Account',
                      Icons.delete_outline_rounded, MM.accentRed,
                      () => _deleteUser(user['id'], name),
                      outlined: true),
                ],
              ),
            ),
          ),
        ],
      ),
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
            child: const Icon(Icons.person_rounded,
                color: MM.textMuted, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('Select a customer',
              style: TextStyle(
                  color: MM.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Click any user from the list to view details.',
              style: TextStyle(color: MM.textSub, fontSize: 13)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════
  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: MM.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          Divider(color: MM.border, height: 20),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, color: color ?? MM.textMuted, size: 16),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  color: MM.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: copyable
                ? () async {
                    await Clipboard.setData(
                        ClipboardData(text: value));
                    _toast('Copied to clipboard.');
                  }
                : null,
            child: Row(children: [
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        color: color ?? MM.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
              if (copyable)
                const Icon(Icons.copy_rounded,
                    color: MM.textMuted, size: 12),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _roleBadge(String role) {
    final isAdmin = role == 'admin';
    final color   = isAdmin ? MM.accentRed : MM.brandBlue;
    final label   = isAdmin ? 'Admin' : 'Customer';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _activeBadge(bool isActive) {
    final color = isActive ? MM.accentGreen : MM.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(isActive ? 'Active' : 'Inactive',
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: outlined
              ? Colors.transparent
              : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════
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
                  color: MM.textSub, fontSize: 14, height: 1.5)),
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
    if (raw.contains('permission')) return 'Permission denied.';
    return 'Something went wrong. Please try again.';
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final m  = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
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
        Text('Loading customers…',
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
        const Text('Could not load customers.',
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
//  Mobile detail sheet — pushed as a route on mobile
// ═══════════════════════════════════════════════════════════
class _CustomerDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isActing;
  final void Function(String) onUpdateRole;
  final void Function(bool) onUpdateStatus;
  final VoidCallback onDelete;

  const _CustomerDetailSheet({
    required this.user,
    required this.isActing,
    required this.onUpdateRole,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name     = user['full_name']?.toString() ?? 'Unknown';
    final role     = user['role']?.toString()      ?? 'customer';
    final isActive = user['is_active'] == true;

    return Theme(
      data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: MM.bgDeep),
      child: Scaffold(
        backgroundColor: MM.bgDeep,
        appBar: AppBar(
          backgroundColor: MM.bgCard,
          foregroundColor: MM.textPrimary,
          elevation: 0,
          title: Text(name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: MM.border),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: MM.brandBlue.withOpacity(0.15),
                backgroundImage: user['avatar_url'] != null
                    ? NetworkImage(user['avatar_url']) : null,
                child: user['avatar_url'] == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: MM.brandBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 28),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(name,
                  style: const TextStyle(
                      color: MM.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              // Actions
              Wrap(
                spacing: 10, runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (!isActive)
                    _btn('Activate', Icons.check_circle_rounded,
                        MM.accentGreen, () => onUpdateStatus(true))
                  else
                    _btn('Deactivate', Icons.block_rounded,
                        MM.accentRed, () => onUpdateStatus(false)),
                  if (role != 'admin')
                    _btn('Make Admin',
                        Icons.admin_panel_settings_rounded,
                        MM.accentAmber, () => onUpdateRole('admin'))
                  else
                    _btn('Make Customer', Icons.person_rounded,
                        MM.textSub, () => onUpdateRole('customer')),
                  _btn('Delete Account',
                      Icons.delete_outline_rounded,
                      MM.accentRed, onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}