import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_service.dart';
import '../../policies/company_policies_page.dart';
import '../../settings/settings_page.dart';

/// The customer's account hub: editable info, profile photo, activity
/// stats, and quick links to Notifications, Company Policies, Settings,
/// and Sign Out.
class ProfilePanel extends StatefulWidget {
  const ProfilePanel({
    super.key,
    required this.onSignOut,
    required this.onViewNotifications,
    required this.unreadNotificationCount,
  });

  final VoidCallback onSignOut;
  final VoidCallback onViewNotifications;
  final int unreadNotificationCount;

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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _email;
  String? _avatarUrl;
  bool _isActive = true;
  DateTime? _memberSince;

  Map<String, int> _activity = const {'favorites': 0, 'reservations': 0, 'inquiries': 0};

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _profileService.fetchProfile();
      final activity = await _profileService.fetchActivityCounts();

      if (profile != null) {
        _nameController.text = (profile['full_name'] as String?) ?? '';
        _phoneController.text = (profile['phone'] as String?) ?? '';
        _email = profile['email'] as String?;
        _avatarUrl = profile['avatar_url'] as String?;
        _isActive = (profile['is_active'] as bool?) ?? true;
        _memberSince =
            profile['created_at'] != null ? DateTime.parse(profile['created_at'] as String) : null;
      }

      setState(() {
        _activity = activity;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load your profile.';
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final url = await _profileService.uploadAvatar(bytes, extension);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _profileService.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save changes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) return _errorState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_isActive) _buildBlockedBanner(),
          _buildAvatarHeader(),
          const SizedBox(height: 24),
          _buildActivityRow(),
          const SizedBox(height: 24),
          _buildEditForm(),
          const SizedBox(height: 28),
          _buildMenu(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBlockedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account has been disabled. Contact the dealership for help.',
              style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHeader() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF1A1A1D),
              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white38, size: 44)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F0F11), width: 2),
                  ),
                  child: _uploadingAvatar
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(_email ?? '', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        if (_memberSince != null) ...[
          const SizedBox(height: 2),
          Text(
            'Member since ${_memberSince!.month}/${_memberSince!.year}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityRow() {
    return Row(
      children: [
        Expanded(child: _statTile(Icons.favorite_border, '${_activity['favorites']}', 'Favorites')),
        const SizedBox(width: 10),
        Expanded(child: _statTile(Icons.event_available, '${_activity['reservations']}', 'Reservations')),
        const SizedBox(width: 10),
        Expanded(child: _statTile(Icons.chat_bubble_outline, '${_activity['inquiries']}', 'Inquiries')),
      ],
    );
  }

  Widget _statTile(IconData icon, String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1D), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 14),
            _field(
              controller: _nameController,
              label: 'Full name',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _field(controller: _phoneController, label: 'Phone (optional)', keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFF1F1F24),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _menuRow(
            icon: Icons.notifications_none,
            label: 'Notifications',
            trailing: widget.unreadNotificationCount > 0
                ? _countPill(widget.unreadNotificationCount)
                : const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
            onTap: widget.onViewNotifications,
          ),
          _menuDivider(),
          _menuRow(
            icon: Icons.description_outlined,
            label: 'Company Policies',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompanyPoliciesPage()),
            ),
          ),
          _menuDivider(),
          _menuRow(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          _menuDivider(),
          _menuRow(
            icon: Icons.logout,
            label: 'Sign Out',
            iconColor: const Color(0xFFDC2626),
            labelColor: const Color(0xFFDC2626),
            onTap: widget.onSignOut,
          ),
        ],
      ),
    );
  }

  Widget _menuDivider() => Divider(color: Colors.white.withOpacity(0.06), height: 1);

  Widget _menuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
    Color iconColor = Colors.white70,
    Color labelColor = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _countPill(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}