// reservations_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reservation_details_page.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final _supabase = Supabase.instance.client;

  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _filteredReservations = [];

  bool _loading = true;
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      setState(() => _loading = true);

      final data = await _supabase
          .from('reservations')
          .select('''
            *,
            cars(*),
            profiles!customer_id(
              id,
              full_name,
              email,
              phone,
              avatar_url
            )
          ''')
          .order('created_at', ascending: false);

      _reservations =
          List<Map<String, dynamic>>.from(data);

      _applyFilters();
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query =
        _searchController.text.trim().toLowerCase();

    _filteredReservations = _reservations.where((r) {
      final customer =
          (r['customer_name'] ?? '').toString().toLowerCase();

      final email =
          (r['customer_email'] ?? '').toString().toLowerCase();

      final phone =
          (r['customer_phone'] ?? '').toString().toLowerCase();

      final status =
          (r['status'] ?? '').toString().toLowerCase();

      final matchesSearch =
          customer.contains(query) ||
          email.contains(query) ||
          phone.contains(query);

      final matchesStatus =
          _selectedStatus == 'All' ||
          status == _selectedStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    setState(() {});
  }

  Future<void> _updateStatus(
    String reservationId,
    String status,
  ) async {
    try {
      await _supabase
          .from('reservations')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservationId);

      await _loadReservations();

      _showSnackBar(
        'Reservation updated',
        Colors.green,
      );
    } catch (e) {
      _showSnackBar(
        e.toString(),
        Colors.red,
      );
    }
  }

  Future<void> _deleteReservation(
    String reservationId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Reservation'),
        content: const Text(
          'Are you sure you want to delete this reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('reservations')
          .delete()
          .eq('id', reservationId);

      await _loadReservations();

      _showSnackBar(
        'Reservation deleted',
        Colors.green,
      );
    } catch (e) {
      _showSnackBar(
        e.toString(),
        Colors.red,
      );
    }
  }

  void _showSnackBar(
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  int get total => _reservations.length;

  int get pending => _reservations
      .where((e) => e['status'] == 'pending')
      .length;

  int get approved => _reservations
      .where((e) => e['status'] == 'approved')
      .length;

  int get completed => _reservations
      .where((e) => e['status'] == 'completed')
      .length;

  int get rejected => _reservations
      .where((e) => e['status'] == 'rejected')
      .length;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'rejected':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  Widget _statCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),

      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(
            onPressed: _loadReservations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReservations,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 180,
                        child: _statCard(
                          'Total',
                          '$total',
                          Colors.indigo,
                          Icons.list_alt,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: _statCard(
                          'Pending',
                          '$pending',
                          Colors.orange,
                          Icons.pending_actions,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: _statCard(
                          'Approved',
                          '$approved',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: _statCard(
                          'Completed',
                          '$completed',
                          Colors.blue,
                          Icons.task_alt,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search customer, email or phone',
                      prefixIcon:
                          const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),

                  const SizedBox(height: 16),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Pending',
                        'Approved',
                        'Completed',
                        'Rejected'
                      ]
                          .map(
                            (status) => Padding(
                              padding:
                                  const EdgeInsets.only(
                                right: 8,
                              ),
                              child: ChoiceChip(
                                label: Text(status),
                                selected:
                                    _selectedStatus ==
                                        status,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedStatus =
                                        status;
                                  });

                                  _applyFilters();
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ..._filteredReservations.map(
                    (reservation) {
                      final car =
                          reservation['cars'] ?? {};

                      final status =
                          reservation['status'] ??
                              'pending';

                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reservation[
                                              'customer_name'] ??
                                          '',
                                      style:
                                          const TextStyle(
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    backgroundColor:
                                        _statusColor(
                                      status,
                                    ),
                                    label: Text(
                                      status
                                          .toString()
                                          .toUpperCase(),
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                  height: 8),

                              Text(
                                reservation[
                                        'customer_email'] ??
                                    '',
                              ),

                              Text(
                                reservation[
                                        'customer_phone'] ??
                                    '',
                              ),

                              const Divider(),

                              Text(
                                '${car['make'] ?? ''} ${car['model'] ?? ''} ${car['year'] ?? ''}',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),

                              Text(
                                'Reservation Date: ${reservation['reservation_date'] ?? ''}',
                              ),

                              const SizedBox(
                                  height: 16),

                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                        Icons
                                            .visibility),
                                    label:
                                        const Text(
                                            'View'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReservationDetailsPage(
                                            reservation:
                                                reservation,
                                          ),
                                        ),
                                      ).then(
                                        (_) =>
                                            _loadReservations(),
                                      );
                                    },
                                  ),

                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(
                                      reservation['id'],
                                      'approved',
                                    ),
                                    child:
                                        const Text(
                                      'Approve',
                                    ),
                                  ),

                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(
                                      reservation['id'],
                                      'completed',
                                    ),
                                    child:
                                        const Text(
                                      'Complete',
                                    ),
                                  ),

                                  ElevatedButton(
                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          Colors.red,
                                    ),
                                    onPressed: () =>
                                        _updateStatus(
                                      reservation['id'],
                                      'rejected',
                                    ),
                                    child:
                                        const Text(
                                      'Reject',
                                    ),
                                  ),

                                  OutlinedButton(
                                    onPressed: () =>
                                        _deleteReservation(
                                      reservation['id'],
                                    ),
                                    child:
                                        const Text(
                                      'Delete',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}