import 'package:flutter/material.dart';
import '../../models/inquiry_model.dart';
import '../../services/inquiry_service.dart';

/// Lists the signed-in customer's inquiries and the dealership's
/// response, once one exists. Guest inquiries aren't shown here since
/// there's no account to attach them to.
class InquiriesPanel extends StatefulWidget {
  const InquiriesPanel({super.key});

  @override
  State<InquiriesPanel> createState() => _InquiriesPanelState();
}

class _InquiriesPanelState extends State<InquiriesPanel> {
  final InquiryService _service = InquiryService();

  bool _loading = true;
  String? _error;
  List<InquiryModel> _inquiries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inquiries = await _service.fetchMyInquiries();
      setState(() {
        _inquiries = inquiries;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load your inquiries.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) return _errorState();
    if (_inquiries.isEmpty) return _emptyState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _inquiries.length,
        itemBuilder: (context, index) => _inquiryCard(_inquiries[index]),
      ),
    );
  }

  Widget _inquiryCard(InquiryModel i) {
    final responded = i.adminResponse != null && i.adminResponse!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1D), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  i.subject,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              _statusBadge(responded),
            ],
          ),
          if (i.carTitle != null) ...[
            const SizedBox(height: 4),
            Text(i.carTitle!, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Text(i.message, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13)),
          if (responded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF26262A), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dealership response',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(i.adminResponse!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(bool responded) {
    final color = responded ? const Color(0xFF16A34A) : const Color(0xFFCA8A04);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
      child: Text(
        responded ? 'Responded' : 'Pending',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text('No inquiries yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Ask a question from a car\'s detail page to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
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