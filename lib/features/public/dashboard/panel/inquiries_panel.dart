import 'package:flutter/material.dart';
import '../../models/inquiry_model.dart';
import '../../services/inquiry_service.dart';

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
    setState(() { _loading = true; _error = null; });
    try {
      final q = await _service.fetchMyInquiries();
      setState(() { _inquiries = q; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your inquiries.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    if (_inquiries.isEmpty) return _emptyState();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1D),
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _inquiryCard(_inquiries[i]),
                childCount: _inquiries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final responded = _inquiries.where((i) => i.adminResponse != null && i.adminResponse!.isNotEmpty).length;
    final pending = _inquiries.length - responded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble, color: Colors.white70, size: 22),
              const SizedBox(width: 10),
              const Text('My Inquiries',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (pending > 0) _statPill('$pending awaiting reply', const Color(0xFFCA8A04)),
              if (pending > 0 && responded > 0) const SizedBox(width: 8),
              if (responded > 0) _statPill('$responded responded', const Color(0xFF16A34A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _inquiryCard(InquiryModel i) {
    final responded = i.adminResponse != null && i.adminResponse!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question block ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF26262A),
                      child: Icon(Icons.person_outline, size: 16, color: Colors.white60),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.subject,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (i.carTitle != null) ...[
                                const Icon(Icons.directions_car_outlined, size: 12, color: Color(0xFF6B7280)),
                                const SizedBox(width: 4),
                                Text(i.carTitle!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                                const SizedBox(width: 8),
                              ],
                              Text(_formatDate(i.createdAt),
                                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(responded),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(i.message,
                      style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13.5, height: 1.5)),
                ),
              ],
            ),
          ),
          // ── Response block ───────────────────────────────────────────
          if (responded) ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent, size: 14, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 8),
                      const Text('Meridian Motors',
                          style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700, fontSize: 12.5)),
                      const SizedBox(width: 6),
                      if (i.respondedAt != null)
                        Text(_formatDate(i.respondedAt!),
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.2)),
                    ),
                    child: Text(i.adminResponse!,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFCA8A04)),
                  const SizedBox(width: 8),
                  const Text('Waiting for a response from the dealership.',
                      style: TextStyle(color: Color(0xFFCA8A04), fontSize: 12.5)),
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
    final label = responded ? 'Responded' : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  String _formatDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  Widget _loadingState() => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading your inquiries...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ]),
      );

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white38, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('No inquiries yet',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text(
              'Have a question about a vehicle?\nTap "Inquire" on any car detail page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF1A1A1D), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 32),
          ),
          const SizedBox(height: 20),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ]),
      ),
    );
  }
}
