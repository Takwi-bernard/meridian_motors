import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _submitting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _passwordChanged = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _passwordChanged = false; });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _newPasswordCtrl.text));
      if (mounted) {
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
        setState(() => _passwordChanged = true);
        Future.delayed(const Duration(seconds: 4),
            () { if (mounted) setState(() => _passwordChanged = false); });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update password. Please try again.'),
            backgroundColor: const Color(0xFF1A1A1D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPasswordSection(),
          const SizedBox(height: 20),
          _buildSecuritySection(),
          const SizedBox(height: 20),
          _buildNotificationSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D10),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text('Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  // ── Password Section ──────────────────────────────────────────────────────

  Widget _buildPasswordSection() {
    return _sectionCard(
      icon: Icons.lock_outline_rounded,
      iconColor: const Color(0xFF2563EB),
      title: 'Change Password',
      subtitle: 'Update your account password',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _passwordField(
              controller: _newPasswordCtrl,
              label: 'New password',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'At least 8 characters';
                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                  return 'Include at least one uppercase letter';
                }
                if (!RegExp(r'[0-9]').hasMatch(v)) {
                  return 'Include at least one number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _passwordField(
              controller: _confirmPasswordCtrl,
              label: 'Confirm new password',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) => v != _newPasswordCtrl.text
                  ? 'Passwords do not match'
                  : null,
            ),
            const SizedBox(height: 8),
            // Password strength hints
            _PasswordHints(password: _newPasswordCtrl.text),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _passwordChanged
                  ? Container(
                      key: const ValueKey('done'),
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                const Color(0xFF16A34A).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 8),
                          Text('Password updated successfully',
                              style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('btn'),
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Update Password',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return StatefulBuilder(
      builder: (context, setLocal) {
        controller.addListener(() => setLocal(() {}));
        return TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Color(0xFF6B7280)),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: Color(0xFF6B7280)),
            filled: true,
            fillColor: const Color(0xFF1A1A1D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.07)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF6B7280),
                size: 18,
              ),
              onPressed: onToggle,
            ),
          ),
        );
      },
    );
  }

  // ── Security Section ──────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
    return _sectionCard(
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF7C3AED),
      title: 'App Security',
      subtitle: 'Advanced protection features',
      child: Column(
        children: [
          _comingSoonRow(
            icon: Icons.fingerprint_rounded,
            label: 'Biometric Sign-In',
            subtitle: 'Use fingerprint or Face ID to sign in',
          ),
          _rowDivider(),
          _comingSoonRow(
            icon: Icons.security_rounded,
            label: 'Two-Factor Authentication',
            subtitle: 'Add a second layer of protection',
          ),
          _rowDivider(),
          _comingSoonRow(
            icon: Icons.devices_rounded,
            label: 'Active Sessions',
            subtitle: 'View and revoke signed-in devices',
          ),
        ],
      ),
    );
  }

  // ── Notification Section ──────────────────────────────────────────────────

  Widget _buildNotificationSection() {
    return _sectionCard(
      icon: Icons.notifications_outlined,
      iconColor: const Color(0xFFCA8A04),
      title: 'Notification Preferences',
      subtitle: 'Control how we reach you',
      child: Column(
        children: [
          _comingSoonRow(
            icon: Icons.email_outlined,
            label: 'Email Notifications',
            subtitle: 'Reservation updates and replies',
          ),
          _rowDivider(),
          _comingSoonRow(
            icon: Icons.phone_android_rounded,
            label: 'Push Notifications',
            subtitle: 'Real-time alerts on your device',
          ),
        ],
      ),
    );
  }

  // ── Shared Components ─────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _comingSoonRow({
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white38),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Soon',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider() =>
      Divider(color: Colors.white.withOpacity(0.05), height: 16);
}

// ── Password strength hints widget ────────────────────────────────────────

class _PasswordHints extends StatelessWidget {
  const _PasswordHints({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final has8 = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        _hint('At least 8 characters', has8),
        const SizedBox(height: 4),
        _hint('At least one uppercase letter', hasUpper),
        const SizedBox(height: 4),
        _hint('At least one number', hasNumber),
      ],
    );
  }

  Widget _hint(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: met ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: met ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
