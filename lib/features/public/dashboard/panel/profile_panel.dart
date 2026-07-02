import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_service.dart';
import '../../policies/company_policies_page.dart';
import '../../settings/settings_page.dart';

class ProfilePanel extends StatefulWidget {
  const ProfilePanel({
    super.key,
    required this.onSignOut,
    required this.onViewNotifications,
    required this.unreadNotificationCount,
    this.onNavigateToTab,
  });

  final VoidCallback onSignOut;
  final VoidCallback onViewNotifications;
  final int unreadNotificationCount;

  /// Called with a tab index so stat tiles can deep-link into other panels.
  /// 1 = Favorites, 2 = Reservations, 3 = Inquiries
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  bool _saveSuccess = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _email;
  String? _avatarUrl;
  bool _isActive = true;
  DateTime? _memberSince;

  Map<String, int> _activity = const {
    'favorites': 0,
    'reservations': 0,
    'inquiries': 0,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _saveSuccess = false; });
    try {
      final profile = await _profileService.fetchProfile();
      final activity = await _profileService.fetchActivityCounts();
      if (profile != null) {
        _nameController.text = (profile['full_name'] as String?) ?? '';
        _phoneController.text = (profile['phone'] as String?) ?? '';
        _email = profile['email'] as String?;
        _avatarUrl = profile['avatar_url'] as String?;
        _isActive = (profile['is_active'] as bool?) ?? true;
        _memberSince = profile['created_at'] != null
            ? DateTime.parse(profile['created_at'] as String)
            : null;
      }
      setState(() { _activity = activity; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your profile.'; _loading = false; });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final url = await _profileService.uploadAvatar(bytes, ext);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        _showSnack('Could not upload photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _saveSuccess = false; });
    try {
      await _profileService.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
      if (mounted) {
        setState(() => _saveSuccess = true);
        Future.delayed(const Duration(seconds: 3),
            () { if (mounted) setState(() => _saveSuccess = false); });
      }
    } catch (_) {
      if (mounted) _showSnack('Could not save changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatMemberSince(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (!_isActive) _buildBlockedBanner(),
                _buildHeroHeader(),
                const SizedBox(height: 20),
                _buildActivityRow(),
                const SizedBox(height: 24),
                _buildEditForm(),
                const SizedBox(height: 24),
                _buildMenuSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Blocked Banner ────────────────────────────────────────────────────────

  Widget _buildBlockedBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account has been disabled by the dealership. '
              'Please contact us for assistance.',
              style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Header ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    final displayName = _nameController.text.trim().isEmpty
        ? 'Your Name'
        : _nameController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A22),
            const Color(0xFF0F0F11),
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar with ring + camera button
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              children: [
                // Outer ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0F0F11),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFF1F1F26),
                      backgroundImage:
                          _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                // Camera badge
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _uploadingAvatar ? const Color(0xFF26262A) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F0F11), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: _uploadingAvatar
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap to change photo',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          // Email with lock icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, size: 13, color: Color(0xFF6B7280)),
              const SizedBox(width: 5),
              Text(
                _email ?? '',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
              ),
            ],
          ),
          if (_memberSince != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(
                    'Member since ${_formatMemberSince(_memberSince!)}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Activity Row ──────────────────────────────────────────────────────────

  Widget _buildActivityRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFDC2626),
              count: _activity['favorites'] ?? 0,
              label: 'Favorites',
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              icon: Icons.event_available_rounded,
              iconColor: const Color(0xFF2563EB),
              count: _activity['reservations'] ?? 0,
              label: 'Reservations',
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF16A34A),
              count: _activity['inquiries'] ?? 0,
              label: 'Inquiries',
              onTap: () => widget.onNavigateToTab?.call(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF15151A),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Form ─────────────────────────────────────────────────────────────

  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline_rounded,
                        size: 16, color: Colors.white70),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(
                      controller: _nameController,
                      label: 'Full name',
                      icon: Icons.badge_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    // Email — read only, clearly explained
                    TextFormField(
                      initialValue: _email ?? '',
                      readOnly: true,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        labelStyle:
                            const TextStyle(color: Color(0xFF6B7280)),
                        prefixIcon: const Icon(Icons.email_outlined,
                            size: 18, color: Color(0xFF6B7280)),
                        suffixIcon: Tooltip(
                          message:
                              'Email cannot be changed here. Contact support.',
                          child: const Icon(Icons.lock_outline_rounded,
                              size: 16, color: Color(0xFF6B7280)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _phoneController,
                      label: 'Phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    // Save button with inline success state
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _saveSuccess
                          ? Container(
                              key: const ValueKey('success'),
                              height: 52,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF16A34A).withOpacity(0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF16A34A), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Profile saved successfully',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('save'),
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor:
                                      Colors.white.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFF1A1A1D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }

  // ── Menu Section ──────────────────────────────────────────────────────────

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            _menuRow(
              icon: Icons.notifications_outlined,
              iconBg: const Color(0xFF2563EB),
              label: 'Notifications',
              subtitle: widget.unreadNotificationCount > 0
                  ? '${widget.unreadNotificationCount} unread'
                  : 'All caught up',
              trailing: widget.unreadNotificationCount > 0
                  ? _countBadge(widget.unreadNotificationCount)
                  : null,
              onTap: widget.onViewNotifications,
            ),
            _divider(),
            _menuRow(
              icon: Icons.gavel_rounded,
              iconBg: const Color(0xFF7C3AED),
              label: 'Company Policies',
              subtitle: 'Terms, reservations & conduct',
              onTap: () => Navigator.push(
                context,
                _slideRoute(const CompanyPoliciesPage()),
              ),
            ),
            _divider(),
            _menuRow(
              icon: Icons.settings_outlined,
              iconBg: const Color(0xFF374151),
              label: 'Settings',
              subtitle: 'Password & app security',
              onTap: () => Navigator.push(
                context,
                _slideRoute(const SettingsPage()),
              ),
            ),
            _divider(),
            _menuRow(
              icon: Icons.logout_rounded,
              iconBg: const Color(0xFFDC2626),
              label: 'Sign Out',
              subtitle: 'See you next time',
              labelColor: const Color(0xFFDC2626),
              onTap: widget.onSignOut,
              showChevron: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required Color iconBg,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color labelColor = Colors.white,
    bool showChevron = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                trailing,
                const SizedBox(width: 6),
              ],
              if (showChevron)
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF4B5563), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() =>
      Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 16, endIndent: 16);

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  // ── Loading / Error ───────────────────────────────────────────────────────

  Widget _loadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading your profile...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1D), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Colors.white38, size: 32),
            ),
            const SizedBox(height: 20),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
