import 'package:flutter/material.dart';

/// Static policy content. The copy below is placeholder — replace each
/// section's body with your dealership's actual written policies.
class CompanyPoliciesPage extends StatelessWidget {
  const CompanyPoliciesPage({super.key});

  static const List<_PolicySection> _sections = [
    _PolicySection(
      title: 'Reservation Policy',
      body:
          'Reservations are held as pending until reviewed by our team. Submitting a reservation does not guarantee the vehicle is held until it has been approved. We aim to respond to all reservation requests within 24-48 hours.',
    ),
    _PolicySection(
      title: 'Vehicle Condition & Disclosure',
      body:
          'All vehicle details, including mileage, condition, and pricing, are provided to the best of our knowledge at the time of listing. We encourage customers to schedule an in-person inspection before finalizing any purchase.',
    ),
    _PolicySection(
      title: 'Pricing & Fees',
      body:
          'Listed prices do not include applicable taxes, registration, or dealer fees unless otherwise stated. Final pricing will be confirmed in writing before any transaction is completed.',
    ),
    _PolicySection(
      title: 'Cancellation Policy',
      body:
          'Reservations may be cancelled by the customer at any time prior to approval. Once a reservation is approved, please contact our team directly to discuss cancellation or changes.',
    ),
    _PolicySection(
      title: 'Privacy & Data',
      body:
          'Information you provide, including contact details and inquiry messages, is used solely to facilitate your reservation, inquiry, or account management, and is not sold to third parties.',
    ),
    _PolicySection(
      title: 'Customer Conduct',
      body:
          'We expect respectful communication in all inquiries and interactions. The dealership reserves the right to restrict account access in cases of abuse, fraud, or repeated policy violations.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Company Policies', style: TextStyle(color: Colors.white)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF15151A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                Text(section.body, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5, height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;
}
