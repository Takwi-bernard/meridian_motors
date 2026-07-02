import 'package:flutter/material.dart';
import '../constants/company_info.dart';

class CompanyPoliciesPage extends StatefulWidget {
  const CompanyPoliciesPage({super.key});

  @override
  State<CompanyPoliciesPage> createState() => _CompanyPoliciesPageState();
}

class _CompanyPoliciesPageState extends State<CompanyPoliciesPage> {
  int? _expandedIndex;

  static const List<_Policy> _policies = [
    _Policy(
      icon: Icons.event_available_rounded,
      iconColor: Color(0xFF2563EB),
      title: 'Reservation Policy',
      body:
          'Reservations are held as pending until reviewed and approved by our team. '
          'Submitting a reservation does not guarantee the vehicle is held until it has been formally approved and the reservation fee has been received. '
          'We aim to respond to all reservation requests within 24–48 business hours. '
          'A reservation fee of 5% of the vehicle price is required to confirm and hold your reservation.',
    ),
    _Policy(
      icon: Icons.payments_outlined,
      iconColor: Color(0xFF16A34A),
      title: 'Reservation Fee & Payment',
      body:
          'To confirm a reservation, customers must pay a non-refundable reservation fee equal to 5% of the listed vehicle price. '
          'This fee is paid directly to the dealership via email arrangement at ${CompanyInfo.contactEmail}. '
          'Payment is not processed through this application. The reservation fee is deducted from the final purchase price upon completion.',
    ),
    _Policy(
      icon: Icons.directions_car_rounded,
      iconColor: Color(0xFF7C3AED),
      title: 'Vehicle Condition & Disclosure',
      body:
          'All vehicle details including mileage, condition, year, and pricing are provided to the best of our knowledge at the time of listing. '
          'Meridian Motors strongly encourages customers to schedule an in-person inspection before finalizing any purchase. '
          'Vehicle availability is subject to change without notice.',
    ),
    _Policy(
      icon: Icons.receipt_long_outlined,
      iconColor: Color(0xFFCA8A04),
      title: 'Pricing & Fees',
      body:
          'Listed prices do not include applicable taxes, registration fees, or dealer documentation fees unless explicitly stated. '
          'Final pricing will be confirmed in writing before any transaction is completed. '
          'Meridian Motors reserves the right to update pricing at any time without prior notice.',
    ),
    _Policy(
      icon: Icons.cancel_outlined,
      iconColor: Color(0xFFDC2626),
      title: 'Cancellation Policy',
      body:
          'Reservations may be cancelled by the customer at any time prior to approval at no charge. '
          'Once a reservation has been approved and the reservation fee has been received, cancellations must be discussed directly with our team. '
          'Reservation fees are non-refundable unless otherwise agreed in writing.',
    ),
    _Policy(
      icon: Icons.privacy_tip_outlined,
      iconColor: Color(0xFF0891B2),
      title: 'Privacy & Data',
      body:
          'Personal information you provide — including your name, contact details, and inquiry messages — '
          'is used solely to facilitate your reservation, inquiry, or account management. '
          'We do not sell, rent, or share your personal information with third parties. '
          'Your data is stored securely and handled in accordance with applicable data protection regulations.',
    ),
    _Policy(
      icon: Icons.handshake_outlined,
      iconColor: Color(0xFF374151),
      title: 'Customer Conduct',
      body:
          'We expect respectful and professional communication in all inquiries and interactions with our team. '
          'Meridian Motors reserves the right to restrict or permanently remove access to accounts involved in abuse, fraud, misrepresentation, or repeated policy violations.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: _appBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildIntro()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _policyCard(i),
                childCount: _policies.length,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildContactFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
      title: const Text('Company Policies',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child:
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1D),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Icon(Icons.gavel_rounded,
                    color: Colors.white70, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Policies',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Tap any section to expand',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Text(
              'These policies govern your use of the Meridian Motors platform and your interactions with our dealership. '
              'Please read them carefully — by using this app you agree to abide by them.',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyCard(int index) {
    final p = _policies[index];
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () =>
          setState(() => _expandedIndex = isExpanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isExpanded
              ? const Color(0xFF1C1C24)
              : const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? p.iconColor.withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: p.iconColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(p.icon, size: 18, color: p.iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280), size: 22),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                      color: Colors.white.withOpacity(0.05), height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      p.body,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have a question about our policies?',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Our team is happy to clarify anything. Reach out to us directly:',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.email_outlined,
                        size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email us at',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 11)),
                        Text(
                          CompanyInfo.contactEmail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Policy {
  const _Policy({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
}
