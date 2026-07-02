import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../dashboard/customer_dashboard.dart';

/// Combined login / signup screen.
///
/// SOCIAL AUTH SETUP (Supabase Dashboard → Authentication → Providers):
///   Google : enable, add Web Client ID + Secret from Google Cloud Console.
///   Apple  : enable, add Services ID + Key from Apple Developer portal.
///   Facebook: enable, add App ID + Secret from Meta Developer portal.
///   Redirect URL to whitelist in each provider:
///     https://<your-project>.supabase.co/auth/v1/callback
///
/// Once those are enabled the buttons below work automatically.
class CustomerAuthPage extends StatefulWidget {
  const CustomerAuthPage({super.key});

  @override
  State<CustomerAuthPage> createState() => _CustomerAuthPageState();
}

class _CustomerAuthPageState extends State<CustomerAuthPage>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _socialLoading; // which provider button is spinning

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation =
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _slideController.reset();
    setState(() => _isLogin = !_isLogin);
    _slideController.forward();
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CustomerDashboardPage(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.signUp(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );
      }
      if (mounted) _goToDashboard();
    } catch (e) {
      if (mounted) {
        _showError(_friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider, String label) async {
    setState(() => _socialLoading = label);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: Uri.base.origin, // returns user back to the app URL
        authScreenLaunchMode: LaunchMode.platformDefault,
      );
      // signInWithOAuth triggers a redirect; the Supabase client handles
      // the session on return. If still mounted (e.g. popup flow), check
      // for an active session and navigate.
      await Future.delayed(const Duration(milliseconds: 800));
      final session = Supabase.instance.client.auth.currentSession;
      if (mounted && session != null) _goToDashboard();
    } catch (e) {
      if (mounted) _showError('Could not sign in with $label. Please try again.');
    } finally {
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) return 'Incorrect email or password.';
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with that email already exists.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBackButton(),
                      const SizedBox(height: 8),
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildHeading(),
                      const SizedBox(height: 28),
                      _buildSocialButtons(),
                      const SizedBox(height: 20),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      _buildForm(),
                      const SizedBox(height: 28),
                      _buildPrimaryButton(),
                      const SizedBox(height: 20),
                      _buildToggleLink(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/meridian_logo.png',
        height: 72,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.directions_car, color: Colors.white54, size: 36),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isLogin ? 'Welcome Back' : 'Create Account',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isLogin
              ? 'Sign in to manage reservations and favorites.'
              : 'Join us to reserve cars and save your favourites.',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _socialButton(
          label: 'Continue with Google',
          provider: OAuthProvider.google,
          icon: _GoogleIcon(),
        ),
        const SizedBox(height: 10),
        _socialButton(
          label: 'Continue with Apple',
          provider: OAuthProvider.apple,
          icon: const Icon(Icons.apple, size: 20, color: Colors.white),
        ),
        const SizedBox(height: 10),
        _socialButton(
          label: 'Continue with Facebook',
          provider: OAuthProvider.facebook,
          icon: const _FacebookIcon(),
        ),
      ],
    );
  }

  Widget _socialButton({
    required String label,
    required OAuthProvider provider,
    required Widget icon,
  }) {
    final isLoading = _socialLoading == label;
    final disabled = _submitting || (_socialLoading != null && !isLoading);

    return SizedBox(
      height: 52,
      child: Material(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : () => _signInWithProvider(provider, label),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : icon,
                ),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: disabled ? Colors.white38 : Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with email',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (!_isLogin) ...[
            _field(
              controller: _fullNameController,
              label: 'Full name',
              icon: Icons.person_outline,
              validator: _required,
            ),
            const SizedBox(height: 12),
          ],
          _field(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 12),
            _field(
              controller: _phoneController,
              label: 'Phone (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
          const SizedBox(height: 12),
          _field(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: _validatePassword,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 12),
            _field(
              controller: _confirmController,
              label: 'Confirm password',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              validator: _validateConfirmPassword,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: (_submitting || _socialLoading != null) ? null : _submitEmailPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white24,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(
                _isLogin ? 'Sign In' : 'Create Account',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleLink() {
    return Center(
      child: TextButton(
        onPressed: (_submitting || _socialLoading != null) ? null : _toggleMode,
        child: RichText(
          text: TextSpan(
            text: _isLogin ? "Don't have an account? " : 'Already have an account? ',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            children: [
              TextSpan(
                text: _isLogin ? 'Sign Up' : 'Sign In',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
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
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF6B7280),
                  size: 18,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (!_isLogin && v.length < 6) return 'At least 6 characters required';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }
}

// ── Social icon widgets ──────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Clipping circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // White background
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white);

    // Simplified G segments
    final segments = [
      // Red top-right
      (_drawArc, const Color(0xFFEA4335), -55.0, 110.0),
      // Yellow bottom
      (_drawArc, const Color(0xFFFBBC05), 55.0, 95.0),
      // Green bottom-left
      (_drawArc, const Color(0xFF34A853), 150.0, 90.0),
      // Blue top-left
      (_drawArc, const Color(0xFF4285F4), 240.0, 80.0),
    ];

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.$2
        ..strokeWidth = size.width * 0.28
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      final rect = Rect.fromCircle(
          center: Offset(cx, cy), radius: r * 0.72);
      canvas.drawArc(
          rect,
          seg.$3 * (3.14159 / 180),
          seg.$4 * (3.14159 / 180),
          false,
          paint);
    }

    // White horizontal bar for the G cutout
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.13, r * 0.9, size.height * 0.26),
      Paint()..color = Colors.white,
    );
  }

  void _drawArc(Canvas c, Size s) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}