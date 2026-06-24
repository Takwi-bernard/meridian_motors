// reservation_details_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> reservation;

  const ReservationDetailsPage({
    super.key,
    required this.reservation,
  });

  @override
  State<ReservationDetailsPage> createState() =>
      _ReservationDetailsPageState();
}

class _ReservationDetailsPageState
    extends State<ReservationDetailsPage> {
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> reservation;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    reservation = widget.reservation;
  }

  Future<void> _updateStatus(String status) async {
    try {
      setState(() => _loading = true);

      await _supabase
          .from('reservations')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservation['id']);

      if (status == 'completed') {
        await _supabase
            .from('cars')
            .update({'status': 'sold'})
            .eq('id', reservation['car_id']);
      }

      setState(() {
        reservation['status'] = status;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reservation $status successfully',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteReservation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Reservation'),
        content: const Text(
          'Are you sure you want to delete this reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('reservations')
          .delete()
          .eq('id', reservation['id']);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.toString()),
        ),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoTile(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final car =
        reservation['cars'] as Map<String, dynamic>? ?? {};

    final profile =
        reservation['profiles'] as Map<String, dynamic>? ??
            {};

    final status =
        reservation['status']?.toString() ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservation Details'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Reservation Status',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Chip(
                            backgroundColor:
                                _statusColor(status),
                            label: Text(
                              status.toUpperCase(),
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    'Customer Information',
                  ),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _infoTile(
                            'Full Name',
                            profile['full_name'] ??
                                reservation[
                                    'customer_name'],
                          ),
                          _infoTile(
                            'Email',
                            profile['email'] ??
                                reservation[
                                    'customer_email'],
                          ),
                          _infoTile(
                            'Phone',
                            profile['phone'] ??
                                reservation[
                                    'customer_phone'],
                          ),
                          _infoTile(
                            'Role',
                            profile['role'],
                          ),
                          _infoTile(
                            'Active',
                            profile['is_active'],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    'Vehicle Information',
                  ),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _infoTile(
                            'Brand',
                            car['brand'],
                          ),
                          _infoTile(
                            'Make',
                            car['make'],
                          ),
                          _infoTile(
                            'Model',
                            car['model'],
                          ),
                          _infoTile(
                            'Year',
                            car['year'],
                          ),
                          _infoTile(
                            'Trim',
                            car['trim'],
                          ),
                          _infoTile(
                            'VIN',
                            car['vin'],
                          ),
                          _infoTile(
                            'Stock Number',
                            car['stock_number'],
                          ),
                          _infoTile(
                            'Condition',
                            car['condition'],
                          ),
                          _infoTile(
                            'Price',
                            car['price'],
                          ),
                          _infoTile(
                            'Sale Price',
                            car['sale_price'],
                          ),
                          _infoTile(
                            'Mileage',
                            car['mileage'],
                          ),
                          _infoTile(
                            'Fuel Type',
                            car['fuel_type'],
                          ),
                          _infoTile(
                            'Transmission',
                            car['transmission'],
                          ),
                          _infoTile(
                            'Body Type',
                            car['body_type'],
                          ),
                          _infoTile(
                            'Drivetrain',
                            car['drivetrain'],
                          ),
                          _infoTile(
                            'Engine',
                            car['engine'],
                          ),
                          _infoTile(
                            'Exterior Color',
                            car['exterior_color'],
                          ),
                          _infoTile(
                            'Interior Color',
                            car['interior_color'],
                          ),
                          _infoTile(
                            'Doors',
                            car['doors'],
                          ),
                          _infoTile(
                            'Seats',
                            car['seats'],
                          ),
                          _infoTile(
                            'Status',
                            car['status'],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    'Reservation Information',
                  ),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _infoTile(
                            'Reservation ID',
                            reservation['id'],
                          ),
                          _infoTile(
                            'Reservation Date',
                            reservation[
                                'reservation_date'],
                          ),
                          _infoTile(
                            'Status',
                            reservation['status'],
                          ),
                          _infoTile(
                            'Notes',
                            reservation['notes'],
                          ),
                          _infoTile(
                            'Created At',
                            reservation[
                                'created_at'],
                          ),
                          _infoTile(
                            'Updated At',
                            reservation[
                                'updated_at'],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _updateStatus(
                          'approved',
                        ),
                        icon: const Icon(
                            Icons.check),
                        label:
                            const Text('Approve'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _updateStatus(
                          'completed',
                        ),
                        icon: const Icon(
                            Icons.task_alt),
                        label:
                            const Text('Complete'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton
                            .styleFrom(
                          backgroundColor:
                              Colors.red,
                        ),
                        onPressed: () =>
                            _updateStatus(
                          'rejected',
                        ),
                        icon: const Icon(
                            Icons.close),
                        label:
                            const Text('Reject'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _deleteReservation,
                        icon: const Icon(
                            Icons.delete),
                        label:
                            const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}