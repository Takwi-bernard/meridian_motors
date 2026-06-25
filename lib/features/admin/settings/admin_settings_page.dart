// settings_page.dart
//
// Body-only — lives inside AdminShell.
// Supabase table: admin_settings (id = 'global_config')
//
// Sections:
//   1. Dealership Profile
//   2. Notification & Email
//   3. Business Rules & Automation
//   4. Display & Regional
//   5. Security & Access
//   6. Danger Zone

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';

// ═══════════════════════════════════════════════════════════
//  SETTINGS PAGE
// ═══════════════════════════════════════════════════════════

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _supabase = Supabase.instance.client;
  final _formKey  = GlobalKey<FormState>();

  // ── Section expand state
  final _expanded = [true, false, false, false, false, false];
  final _sectionKeys = List.generate(6, (_) => GlobalKey());

  // ── 1. Dealership Profile
  final _dealerNameCtrl    = TextEditingController();
  final _dealerPhoneCtrl   = TextEditingController();
  final _dealerEmailCtrl   = TextEditingController();
  final _dealerAddressCtrl = TextEditingController();
  final _dealerWebsiteCtrl = TextEditingController();

  // ── 2. Notification & Email
  final _adminEmailCtrl    = TextEditingController();
  final _emailFromCtrl     = TextEditingController();
  bool _notifyReservation  = true;
  bool _notifyInquiry      = true;
  bool _notifyNewCustomer  = false;

  // ── 3. Business Rules
  bool _autoApprove        = false;
  bool _maintenanceMode    = false;
  bool _allowGuestBrowse   = true;
  bool _showPrices         = true;
  bool _requireDeposit     = false;

  // ── 4. Display & Regional
  final _currencyCtrl      = TextEditingController();
  final _taxRateCtrl       = TextEditingController();
  final _currencySymbolCtrl = TextEditingController();
  String _dateFormat       = 'MM/DD/YYYY';
  String _timezone         = 'America/New_York';

  // ── 5. Security
  final _newPasswordCtrl   = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureNew         = true;
  bool _obscureConfirm     = true;
  bool _require2FA         = false;
  bool _sessionTimeout     = true;

  bool _isLoading = true;
  bool _isSaving  = false;
  bool _isDirty   = false;

  static const _dateFormats = [
    'MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD'
  ];
  static const _timezones = [
    'America/New_York', 'America/Chicago',
    'America/Denver',   'America/Los_Angeles',
    'America/Anchorage','Pacific/Honolulu',
    'UTC',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    for (final c in _allControllers) {
      c.addListener(() => setState(() => _isDirty = true));
    }
  }

  List<TextEditingController> get _allControllers => [
    _dealerNameCtrl, _dealerPhoneCtrl, _dealerEmailCtrl,
    _dealerAddressCtrl, _dealerWebsiteCtrl,
    _adminEmailCtrl, _emailFromCtrl,
    _currencyCtrl, _taxRateCtrl, _currencySymbolCtrl,
    _newPasswordCtrl, _confirmPasswordCtrl,
  ];

  @override
  void dispose() {
    for (final c in _allControllers) c.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  //  LOAD
  // ════════════════════════════════════════════════════════
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('admin_settings')
          .select()
          .eq('id', 'global_config')
          .maybeSingle();

      if (data != null && mounted) {
        // Profile
        _dealerNameCtrl.text    = data['dealer_name']    ?? 'Meridian Motors';
        _dealerPhoneCtrl.text   = data['dealer_phone']   ?? '';
        _dealerEmailCtrl.text   = data['dealer_email']   ?? '';
        _dealerAddressCtrl.text = data['dealer_address'] ?? '';
        _dealerWebsiteCtrl.text = data['dealer_website'] ?? '';
        // Notifications
        _adminEmailCtrl.text    = data['admin_email']      ?? '';
        _emailFromCtrl.text     = data['admin_email_from'] ?? '';
        _notifyReservation      = data['notify_on_reservation'] ?? true;
        _notifyInquiry          = data['notify_on_inquiry']     ?? true;
        _notifyNewCustomer      = data['notify_new_customer']   ?? false;
        // Business
        _autoApprove            = data['auto_approve']       ?? false;
        _maintenanceMode        = data['maintenance_mode']   ?? false;        _allowGuestBrowse       = data['allow_guest_browse'] ?? true;
        _showPrices             = data['show_prices']        ?? true;
        _requireDeposit         = data['require_deposit']    ?? false;
        // Display
        _currencyCtrl.text      = data['currency_code']   ?? 'USD';
        _taxRateCtrl.text       = data['tax_rate']         ?? '0';
        _currencySymbolCtrl.text = data['currency_symbol'] ?? '\$';
        _dateFormat             = data['date_format']      ?? 'MM/DD/YYYY';
        _timezone               = data['timezone']         ?? 'America/New_York';
        // Security
        _require2FA             = data['require_2fa']       ?? false;
        _sessionTimeout         = data['session_timeout']   ?? true;
      }
      setState(() => _isDirty = false);
    } catch (e) {
      _toast('Failed to load settings: ${_friendly(e.toString())}',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════
  //  SAVE
  // ════════════════════════════════════════════════════════
  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.from('admin_settings').upsert({
        'id': 'global_config',
        // Profile
        'dealer_name':    _dealerNameCtrl.text.trim(),
        'dealer_phone':   _dealerPhoneCtrl.text.trim(),
        'dealer_email':   _dealerEmailCtrl.text.trim(),
        'dealer_address': _dealerAddressCtrl.text.trim(),
        'dealer_website': _dealerWebsiteCtrl.text.trim(),
        // Notifications
        'admin_email':             _adminEmailCtrl.text.trim(),
        'admin_email_from':        _emailFromCtrl.text.trim(),
        'notify_on_reservation':   _notifyReservation,
        'notify_on_inquiry':       _notifyInquiry,
        'notify_new_customer':     _notifyNewCustomer,
        // Business
        'auto_approve':       _autoApprove,
        'maintenance_mode':   _maintenanceMode,
        'allow_guest_browse': _allowGuestBrowse,
        'show_prices':        _showPrices,
        'require_deposit':    _requireDeposit,
        // Display
        'currency_code':   _currencyCtrl.text.trim(),
        'currency_symbol': _currencySymbolCtrl.text.trim(),
        'tax_rate':        _taxRateCtrl.text.trim(),
        'date_format':     _dateFormat,
        'timezone':        _timezone,
        // Security flags
        'require_2fa':     _require2FA,
        'session_timeout': _sessionTimeout,
        'updated_at':      DateTime.now().toUtc().toIso8601String(),
      });

      setState(() => _isDirty = false);
      _toast('Settings saved successfully.');
    } catch (e) {
      _toast(_friendly(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Password change
  Future<void> _changePassword() async {
    final pwd     = _newPasswordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (pwd.length < 8) {
      _toast('Password must be at least 8 characters.', isError: true);
      return;
    }
    if (pwd != confirm) {
      _toast('Passwords do not match.', isError: true);
      return;
    }

    final ok = await _confirmDialog(
      title: 'Change password?',
      message: 'Your admin login password will be updated immediately.',
      confirmLabel: 'Change Password',
      confirmColor: MM.brandBlue,
    );
    if (ok != true) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.auth.updateUser(
          UserAttributes(password: pwd));
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _toast('Password changed successfully.');
    } catch (e) {
      _toast(_friendly(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Maintenance mode toggle with warning
  Future<void> _toggleMaintenance(bool value) async {
    if (value) {
      final ok = await _confirmDialog(
        title: 'Enable Maintenance Mode?',
        message:
            'The customer-facing app will be locked and show a maintenance screen. '
            'No customers will be able to browse or make reservations.',
        confirmLabel: 'Enable',
        confirmColor: MM.accentRed,
      );
      if (ok != true) return;
    }
    setState(() { _maintenanceMode = value; _isDirty = true; });
  }

  // ── Sign out all sessions
  Future<void> _signOutAll() async {
    final ok = await _confirmDialog(
      title: 'Sign out all sessions?',
      message:
          'All active admin sessions will be terminated. '
          'You will be logged out immediately.',
      confirmLabel: 'Sign Out All',
      confirmColor: MM.accentRed,
    );
    if (ok != true) return;

    try {
      await _supabase.auth.signOut(scope: SignOutScope.global);
    } catch (e) {
      _toast(_friendly(e.toString()), isError: true);
    }
  }

  void _toggleSection(int i) {
    setState(() => _expanded[i] = !_expanded[i]);
    if (_expanded[i]) {
      Future.delayed(const Duration(milliseconds: 200), () {
        final ctx = _sectionKeys[i].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut);
        }
      });
    }
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _loader();

    final isDesktop = MediaQuery.of(context).size.width > 950;

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              isDesktop ? 28 : 16,
              isDesktop ? 28 : 16,
              isDesktop ? 28 : 16,
              100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDesktop),
                const SizedBox(height: 24),
                if (isDesktop)
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(children: [
                          _section(0,
                              Icons.storefront_rounded,
                              'Dealership Profile',
                              'Name, contact, address, website',
                              MM.brandBlue,
                              _dealershipSection()),
                          const SizedBox(height: 12),
                          _section(2,
                              Icons.gavel_rounded,
                              'Business Rules',
                              'Auto-approve, guest access, deposits',
                              MM.accentAmber,
                              _businessSection()),
                          const SizedBox(height: 12),
                          _section(3,
                              Icons.language_rounded,
                              'Display & Regional',
                              'Currency, tax rate, date format, timezone',
                              MM.accentPurple,
                              _displaySection()),
                        ]),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(children: [
                          _section(1,
                              Icons.notifications_none_rounded,
                              'Notifications & Email',
                              'Admin email, relay settings',
                              MM.accentGreen,
                              _notificationSection()),
                          const SizedBox(height: 12),
                          _section(4,
                              Icons.shield_rounded,
                              'Security & Access',
                              'Password, 2FA, sessions',
                              MM.accentRed,
                              _securitySection()),
                          const SizedBox(height: 12),
                          _dangerZoneSection(),
                        ]),
                      ),
                    ],
                  )
                else
                  Column(children: [
                    _section(0, Icons.storefront_rounded,
                        'Dealership Profile',
                        'Name, contact, address',
                        MM.brandBlue, _dealershipSection()),
                    const SizedBox(height: 12),
                    _section(1,
                        Icons.notifications_none_rounded,
                        'Notifications & Email',
                        'Admin email, relay settings',
                        MM.accentGreen, _notificationSection()),
                    const SizedBox(height: 12),
                    _section(2, Icons.gavel_rounded,
                        'Business Rules',
                        'Auto-approve, guest access',
                        MM.accentAmber, _businessSection()),
                    const SizedBox(height: 12),
                    _section(3, Icons.language_rounded,
                        'Display & Regional',
                        'Currency, tax, date format',
                        MM.accentPurple, _displaySection()),
                    const SizedBox(height: 12),
                    _section(4, Icons.shield_rounded,
                        'Security & Access',
                        'Password, 2FA, sessions',
                        MM.accentRed, _securitySection()),
                    const SizedBox(height: 12),
                    _dangerZoneSection(),
                  ]),
              ],
            ),
          ),
        ),
        // Floating save bar — only visible when dirty
        if (_isDirty) _floatingSaveBar(),
      ],
    );
  }

  // ── Header
  Widget _buildHeader(bool isDesktop) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings',
                style: TextStyle(
                    color: MM.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text(
                'Configure dealership profile, notifications, '
                'business rules and security.',
                style: TextStyle(
                    color: MM.textSub, fontSize: 13)),
          ],
        ),
      ),
      if (_maintenanceMode)
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MM.accentRed.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: MM.accentRed.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.construction_rounded,
                color: MM.accentRed, size: 14),
            SizedBox(width: 6),
            Text('Maintenance Mode ON',
                style: TextStyle(
                    color: MM.accentRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }

  // ── Floating save bar
  Widget _floatingSaveBar() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: MM.bgCard,
          border: Border(top: BorderSide(color: MM.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.edit_rounded,
              color: MM.accentAmber, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('You have unsaved changes.',
                style: TextStyle(
                    color: MM.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              _loadSettings();
              setState(() => _isDirty = false);
            },
            child: const Text('Discard',
                style: TextStyle(color: MM.textSub)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: MM.brandBlue,
              disabledBackgroundColor:
                  MM.brandBlue.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            Colors.white)))
                : const Text('Save Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  // ── Collapsible section
  Widget _section(
    int index,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    Widget child,
  ) {
    final open = _expanded[index];
    return Container(
      key: _sectionKeys[index],
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: open ? color.withOpacity(0.3) : MM.border),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => _toggleSection(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: MM.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: MM.textSub, fontSize: 12)),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: open ? color : MM.textMuted,
                  size: 22,
                ),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: child,
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: open
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SECTION CONTENTS
  // ════════════════════════════════════════════════════════

  // ── 1. Dealership Profile
  Widget _dealershipSection() => Column(children: [
    _field('Dealership Name', _dealerNameCtrl,
        icon: Icons.storefront_rounded,
        hint: 'e.g. Meridian Motors',
        required: true),
    const SizedBox(height: 12),
    _row([
      _field('Phone', _dealerPhoneCtrl,
          icon: Icons.phone_rounded,
          hint: '+1 555 000 1234',
          keyboard: TextInputType.phone),
      _field('Email', _dealerEmailCtrl,
          icon: Icons.email_rounded,
          hint: 'contact@meridianmotors.com',
          keyboard: TextInputType.emailAddress),
    ]),
    const SizedBox(height: 12),
    _field('Address', _dealerAddressCtrl,
        icon: Icons.location_on_rounded,
        hint: '123 Main St, New York, NY 10001',
        maxLines: 2),
    const SizedBox(height: 12),
    _field('Website', _dealerWebsiteCtrl,
        icon: Icons.language_rounded,
        hint: 'https://meridianmotors.com'),
  ]);

  // ── 2. Notifications
  Widget _notificationSection() => Column(children: [
    _field('Admin Notification Email', _adminEmailCtrl,
        icon: Icons.alternate_email_rounded,
        hint: 'admin@meridianmotors.com',
        keyboard: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _field('Email From Header', _emailFromCtrl,
        icon: Icons.send_rounded,
        hint: 'Meridian Motors <noreply@meridianmotors.com>'),
    const SizedBox(height: 16),
    Divider(color: MM.border, height: 1),
    const SizedBox(height: 16),
    _switchRow(
      'New Reservation',
      'Email admin when a customer makes a reservation.',
      Icons.calendar_month_rounded,
      MM.accentGreen,
      _notifyReservation,
      (v) => setState(() { _notifyReservation = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    _switchRow(
      'New Inquiry',
      'Email admin when a customer submits an inquiry.',
      Icons.mail_rounded,
      MM.brandBlue,
      _notifyInquiry,
      (v) => setState(() { _notifyInquiry = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    _switchRow(
      'New Customer Registration',
      'Email admin when a new customer creates an account.',
      Icons.person_add_rounded,
      MM.accentPurple,
      _notifyNewCustomer,
      (v) => setState(() { _notifyNewCustomer = v; _isDirty = true; }),
    ),
  ]);

  // ── 3. Business Rules
  Widget _businessSection() => Column(children: [
    _switchRow(
      'Auto-Approve Reservations',
      'Reservations are confirmed instantly without manual review.',
      Icons.auto_awesome_rounded,
      MM.accentGreen,
      _autoApprove,
      (v) => setState(() { _autoApprove = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    _switchRow(
      'Allow Guest Browsing',
      'Customers can browse inventory without creating an account.',
      Icons.visibility_rounded,
      MM.brandBlue,
      _allowGuestBrowse,
      (v) => setState(() { _allowGuestBrowse = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    _switchRow(
      'Show Prices Publicly',
      'Vehicle prices visible to all visitors. Turn off to hide until login.',
      Icons.attach_money_rounded,
      MM.accentGreen,
      _showPrices,
      (v) => setState(() { _showPrices = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    _switchRow(
      'Require Deposit on Reservation',
      'Customers must pay a deposit to confirm their reservation.',
      Icons.credit_card_rounded,
      MM.accentAmber,
      _requireDeposit,
      (v) => setState(() { _requireDeposit = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    // Maintenance mode — separate with warning style
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _maintenanceMode
            ? MM.accentRed.withOpacity(0.08) : MM.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _maintenanceMode
              ? MM.accentRed.withOpacity(0.3) : MM.border,
        ),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: MM.accentRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.construction_rounded,
              color: MM.accentRed, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maintenance Mode',
                  style: TextStyle(
                      color: MM.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(
                _maintenanceMode
                    ? '⚠️ App is locked for customers.'
                    : 'Lock the customer app for maintenance.',
                style: TextStyle(
                    color: _maintenanceMode
                        ? MM.accentRed : MM.textMuted,
                    fontSize: 11),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _maintenanceMode,
          onChanged: _toggleMaintenance,
          activeColor: MM.accentRed,
          activeTrackColor: MM.accentRed.withOpacity(0.25),
          inactiveThumbColor: MM.textMuted,
          inactiveTrackColor: MM.bgCard,
        ),
      ]),
    ),
  ]);

  // ── 4. Display & Regional
  Widget _displaySection() => Column(children: [
    _row([
      _field('Currency Code', _currencyCtrl,
          icon: Icons.paid_rounded,
          hint: 'USD',
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required.';
            return null;
          }),
      _field('Currency Symbol', _currencySymbolCtrl,
          icon: Icons.attach_money_rounded,
          hint: '\$'),
    ]),
    const SizedBox(height: 12),
    _field('Tax Rate (%)', _taxRateCtrl,
        icon: Icons.percent_rounded,
        hint: 'e.g. 8.5',
        keyboard: TextInputType.number),
    const SizedBox(height: 12),
    _labeledDropdown(
      label: 'Date Format',
      icon: Icons.date_range_rounded,
      value: _dateFormat,
      items: _dateFormats,
      onChanged: (v) => setState(() {
        _dateFormat = v!;
        _isDirty    = true;
      }),
    ),
    const SizedBox(height: 12),
    _labeledDropdown(
      label: 'Timezone',
      icon: Icons.access_time_rounded,
      value: _timezone,
      items: _timezones,
      onChanged: (v) => setState(() {
        _timezone = v!;
        _isDirty  = true;
      }),
    ),
  ]);

  // ── 5. Security
  Widget _securitySection() => Column(children: [
    _switchRow(
      'Session Timeout',
      'Automatically sign out after 60 minutes of inactivity.',
      Icons.timer_off_rounded,
      MM.accentAmber,
      _sessionTimeout,
      (v) => setState(() { _sessionTimeout = v; _isDirty = true; }),
    ),
    const SizedBox(height: 12),
    _switchRow(
      'Require 2FA',
      'All admin accounts must use two-factor authentication.',
      Icons.security_rounded,
      MM.accentGreen,
      _require2FA,
      (v) => setState(() { _require2FA = v; _isDirty = true; }),
    ),
    const SizedBox(height: 16),
    Divider(color: MM.border),
    const SizedBox(height: 16),
    // Change password
    const Text('Change Password',
        style: TextStyle(
            color: MM.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    _field('New Password', _newPasswordCtrl,
        icon: Icons.lock_rounded,
        hint: 'Min. 8 characters',
        obscure: _obscureNew,
        suffixIcon: GestureDetector(
          onTap: () =>
              setState(() => _obscureNew = !_obscureNew),
          child: Icon(
            _obscureNew
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: MM.textMuted, size: 18,
          ),
        )),
    const SizedBox(height: 10),
    _field('Confirm Password', _confirmPasswordCtrl,
        icon: Icons.lock_outline_rounded,
        hint: 'Repeat new password',
        obscure: _obscureConfirm,
        suffixIcon: GestureDetector(
          onTap: () => setState(
              () => _obscureConfirm = !_obscureConfirm),
          child: Icon(
            _obscureConfirm
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: MM.textMuted, size: 18,
          ),
        )),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _changePassword,
        style: OutlinedButton.styleFrom(
          foregroundColor: MM.brandBlue,
          side: const BorderSide(color: MM.brandBlue),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.key_rounded, size: 16),
        label: const Text('Update Password',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
    const SizedBox(height: 12),
    // Sign out all
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOutAll,
        style: OutlinedButton.styleFrom(
          foregroundColor: MM.accentAmber,
          side: const BorderSide(
              color: MM.accentAmber, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.logout_rounded, size: 16),
        label: const Text('Sign Out All Sessions',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  ]);

  // ── Danger Zone
  Widget _dangerZoneSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MM.accentRed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: MM.accentRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                  Icons.warning_amber_rounded,
                  color: MM.accentRed, size: 19),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Danger Zone',
                    style: TextStyle(
                        color: MM.accentRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('Irreversible actions — proceed carefully.',
                    style: TextStyle(
                        color: MM.textMuted, fontSize: 12)),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          // Clear all read inquiries
          _dangerRow(
            'Delete all read inquiries',
            'Permanently remove all inquiries marked as read.',
            'Delete',
            () async {
              final ok = await _confirmDialog(
                title: 'Delete all read inquiries?',
                message:
                    'All read inquiries will be permanently deleted.',
                confirmLabel: 'Delete',
                confirmColor: MM.accentRed,
              );
              if (ok != true) return;
              try {
                await _supabase
                    .from('inquiries')
                    .delete()
                    .eq('is_read', true);
                _toast('All read inquiries deleted.');
              } catch (e) {
                _toast(_friendly(e.toString()), isError: true);
              }
            },
          ),
          Divider(color: MM.border.withOpacity(0.5),
              height: 24),
          // Clear completed reservations
          _dangerRow(
            'Delete completed reservations',
            'Permanently remove all completed reservation records.',
            'Delete',
            () async {
              final ok = await _confirmDialog(
                title: 'Delete completed reservations?',
                message:
                    'All completed reservations will be permanently deleted.',
                confirmLabel: 'Delete',
                confirmColor: MM.accentRed,
              );
              if (ok != true) return;
              try {
                await _supabase
                    .from('reservations')
                    .delete()
                    .eq('status', 'completed');
                _toast('Completed reservations deleted.');
              } catch (e) {
                _toast(_friendly(e.toString()), isError: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dangerRow(
    String title,
    String desc,
    String btnLabel,
    VoidCallback onTap,
  ) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(desc,
                style: const TextStyle(
                    color: MM.textMuted,
                    fontSize: 11,
                    height: 1.4)),
          ],
        ),
      ),
      const SizedBox(width: 16),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: MM.accentRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: MM.accentRed.withOpacity(0.3)),
          ),
          child: Text(btnLabel,
              style: const TextStyle(
                  color: MM.accentRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════
  //  REUSABLE FORM WIDGETS
  // ════════════════════════════════════════════════════════
  Widget _row(List<Widget> children) => Row(
    children: children
        .map((c) => Expanded(child: c))
        .toList()
        .expand((c) => [c, const SizedBox(width: 12)])
        .toList()
      ..removeLast(),
  );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    bool required = false,
    int maxLines  = 1,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure  = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: MM.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          obscureText: obscure,
          style: const TextStyle(
              color: MM.textPrimary, fontSize: 14),
          cursorColor: MM.brandBlue,
          validator: validator ??
              (required
                  ? (v) {
                      if (v == null || v.trim().isEmpty)
                        return '$label is required.';
                      return null;
                    }
                  : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: MM.textMuted, fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: MM.textMuted, size: 17)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: MM.bgSurface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: MM.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: MM.brandBlue, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: MM.accentRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: MM.accentRed, width: 1.8),
            ),
            errorStyle: const TextStyle(
                color: MM.accentRed, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _switchRow(
    String label,
    String desc,
    IconData icon,
    Color color,
    bool value,
    void Function(bool) onChange,
  ) {
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: MM.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(desc,
                style: const TextStyle(
                    color: MM.textMuted,
                    fontSize: 11,
                    height: 1.3)),
          ],
        ),
      ),
      Switch.adaptive(
        value: value,
        onChanged: onChange,
        activeColor: color,
        activeTrackColor: color.withOpacity(0.25),
        inactiveThumbColor: MM.textMuted,
        inactiveTrackColor: MM.bgSurface,
      ),
    ]);
  }

  Widget _labeledDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: MM.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: MM.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MM.border, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: MM.bgSurface,
              style: const TextStyle(
                  color: MM.textPrimary, fontSize: 14),
              icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: MM.textMuted, size: 20),
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Row(children: [
                  Icon(icon, color: MM.textMuted, size: 15),
                  const SizedBox(width: 8),
                  Text(item,
                      style: const TextStyle(
                          color: MM.textPrimary,
                          fontSize: 13)),
                ]),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
                  color: MM.textSub,
                  fontSize: 14,
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
        duration: Duration(seconds: isError ? 4 : 2),
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

  String _friendly(String raw) {
    if (raw.contains('network')) return 'No internet connection.';
    if (raw.contains('permission')) return 'Permission denied.';
    if (raw.contains('duplicate')) return 'A conflict occurred.';
    return 'Something went wrong. Please try again.';
  }

  Widget _loader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 34, height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor:
                AlwaysStoppedAnimation<Color>(MM.brandBlue),
          ),
        ),
        SizedBox(height: 16),
        Text('Loading settings…',
            style: TextStyle(
                color: MM.textSub, fontSize: 14)),
      ],
    ),
  );
}