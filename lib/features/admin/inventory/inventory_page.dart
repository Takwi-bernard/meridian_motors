import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adminShell.dart';
import 'package:meridian_motors/features/admin/inventory/add_vehicle_page.dart';
// ─────────────────────────────────────────────────────────────
//  MERIDIAN MOTORS — Inventory Page
//  Lives inside AdminShell — no Scaffold/AppBar needed
// ─────────────────────────────────────────────────────────────

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  bool _isLoading = true;
  bool _hasError  = false;

  List<Map<String, dynamic>> _vehicles         = [];
  List<Map<String, dynamic>> _filteredVehicles = [];

  int _total = 0, _available = 0, _reserved = 0,
      _sold  = 0, _featured  = 0;

  String _searchQuery    = '';
  String _selectedStatus = 'All';

  // ── Lifecycle
  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data
  Future<void> loadInventory() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final data = await _supabase
          .from('cars')
          .select()
          .order('created_at', ascending: false);

      _vehicles = List<Map<String, dynamic>>.from(data);
      _total     = _vehicles.length;
      _available = _vehicles.where((e) => e['status'] == 'available').length;
      _reserved  = _vehicles.where((e) => e['status'] == 'reserved').length;
      _sold      = _vehicles.where((e) => e['status'] == 'sold').length;
      _featured  = _vehicles.where((e) => e['featured'] == true).length;
      _applyFilters();
    } catch (e) {
      debugPrint('Inventory load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filteredVehicles = _vehicles.where((v) {
        final title =
            '${v['make'] ?? ''} ${v['model'] ?? ''} ${v['year'] ?? ''}'
                .toLowerCase();
        final matchSearch = q.isEmpty || title.contains(q);
        final matchStatus = _selectedStatus == 'All' ||
            v['status'] == _selectedStatus.toLowerCase();
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  // ── Actions
  Future<void> _deleteVehicle(String id, String label) async {
    final confirm = await _confirmDialog(
      title: 'Delete vehicle?',
      message:
          '$label will be permanently removed from inventory. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: MM.accentRed,
    );
    if (confirm != true) return;
    try {
      await _supabase.from('cars').delete().eq('id', id);
      _showToast('Vehicle deleted.');
      loadInventory();
    } catch (e) {
      _showToast('Failed to delete vehicle.', isError: true);
    }
  }

  Future<void> _updateStatus(String id, String status, String label) async {
    final confirm = await _confirmDialog(
      title: 'Mark as ${MM.statusLabel(status)}?',
      message: '$label will be updated to "${MM.statusLabel(status)}".',
      confirmLabel: 'Confirm',
      confirmColor: MM.statusColor(status),
    );
    if (confirm != true) return;
    try {
      await _supabase.from('cars').update({'status': status}).eq('id', id);
      _showToast('Status updated to ${MM.statusLabel(status)}.');
      loadInventory();
    } catch (e) {
      _showToast('Failed to update status.', isError: true);
    }
  }

  Future<void> _toggleFeatured(String id, bool value, String label) async {
    try {
      await _supabase.from('cars').update({'featured': value}).eq('id', id);
      _showToast(value
          ? '$label added to featured.'
          : '$label removed from featured.');
      loadInventory();
    } catch (e) {
      _showToast('Failed to update featured status.', isError: true);
    }
  }

  // ── Dialogs / toasts
  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MM.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: MM.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(message,
            style: const TextStyle(color: MM.textSub, fontSize: 14,
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
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? MM.accentRed : MM.accentGreen,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (_isLoading) return _buildLoader();
    if (_hasError)  return _buildError();

    return RefreshIndicator(
      onRefresh: loadInventory,
      color: MM.brandBlue,
      backgroundColor: MM.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 28 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDesktop),
            const SizedBox(height: 24),
            _buildStatRow(isDesktop),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  // ── Header
  Widget _buildHeader(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inventory',
                  style: TextStyle(
                      color: MM.textPrimary, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('$_total vehicles in fleet',
                  style: const TextStyle(
                      color: MM.textSub, fontSize: 13)),
            ],
          ),
        ),
        // Refresh
        _headerBtn(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          color: MM.textSub,
          onTap: loadInventory,
        ),
        const SizedBox(width: 10),
        // Add vehicle
        _headerBtn(
          icon: Icons.add_rounded,
          label: 'Add Vehicle',
          color: MM.brandBlue,
          filled: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVehiclePage()),
          ),
        ),
      ],
    );
  }

  Widget _headerBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? MM.brandBlue : MM.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: filled
                  ? Colors.transparent
                  : MM.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: filled ? Colors.white : color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: filled ? Colors.white : color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Stat row
  Widget _buildStatRow(bool isDesktop) {
    final stats = [
      ('Total',     '$_total',     Icons.directions_car_rounded, MM.brandBlue),
      ('Available', '$_available', Icons.check_circle_rounded,   MM.accentGreen),
      ('Reserved',  '$_reserved',  Icons.event_rounded,          MM.accentAmber),
      ('Sold',      '$_sold',      Icons.sell_rounded,           MM.accentRed),
      ('Featured',  '$_featured',  Icons.star_rounded,           MM.accentPurple),
    ];

    return GridView.count(
      crossAxisCount: isDesktop ? 5 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.8 : 1.5,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MM.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MM.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: s.$4.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(s.$3, color: s.$4, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$2,
                      style: const TextStyle(
                          color: MM.textPrimary, fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  Text(s.$1,
                      style: const TextStyle(
                          color: MM.textSub, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Search + filter bar
  Widget _buildSearchBar() {
    final statuses = ['All', 'Available', 'Reserved', 'Sold'];

    return Row(
      children: [
        // Search
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: MM.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MM.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: MM.textPrimary, fontSize: 14),
              cursorColor: MM.brandBlue,
              decoration: InputDecoration(
                hintText: 'Search by make, model or year…',
                hintStyle: const TextStyle(color: MM.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: MM.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _applyFilters();
                        },
                        child: const Icon(Icons.close_rounded,
                            color: MM.textMuted, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statuses.map((s) {
              final selected = _selectedStatus == s;
              final color = s == 'Available'
                  ? MM.accentGreen
                  : s == 'Reserved'
                      ? MM.accentAmber
                      : s == 'Sold'
                          ? MM.accentRed
                          : MM.brandBlue;
              return GestureDetector(
                onTap: () {
                  _selectedStatus = s;
                  _applyFilters();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.12)
                        : MM.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? color.withOpacity(0.4)
                          : MM.border,
                    ),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          color: selected ? color : MM.textSub,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Table
  Widget _buildTable() {
    if (_filteredVehicles.isEmpty) return _buildEmptyState();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      decoration: BoxDecoration(
        color: MM.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MM.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(MM.bgSurface),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return MM.brandBlue.withOpacity(0.05);
              }
              return Colors.transparent;
            }),
            dividerThickness: 1,
            headingTextStyle: const TextStyle(
              color: MM.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            dataTextStyle: const TextStyle(
              color: MM.textPrimary, fontSize: 13),
            columnSpacing: isDesktop ? 28 : 20,
            columns: const [
              DataColumn(label: Text('VEHICLE')),
              DataColumn(label: Text('YEAR')),
              DataColumn(label: Text('PRICE')),
              DataColumn(label: Text('MILEAGE')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('FEATURED')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: _filteredVehicles.map((v) {
              final id    = v['id']?.toString() ?? '';
              final label =
                  '${v['year'] ?? ''} ${v['make'] ?? ''} ${v['model'] ?? ''}'
                      .trim();
              final status    = v['status']?.toString() ?? '';
              final isFeatured = v['featured'] == true;

              return DataRow(
                cells: [
                  // Vehicle
                  DataCell(
                    Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: MM.brandBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                              Icons.directions_car_rounded,
                              color: MM.brandBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${v['make'] ?? ''} ${v['model'] ?? ''}',
                              style: const TextStyle(
                                  color: MM.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            Text('ID: ${id.length > 8 ? id.substring(0, 8) : id}…',
                                style: const TextStyle(
                                    color: MM.textMuted,
                                    fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Year
                  DataCell(Text(v['year']?.toString() ?? '—',
                      style: const TextStyle(color: MM.textSub))),
                  // Price
                  DataCell(Text(
                    v['price'] != null
                        ? '\$${_formatNumber(v['price'])}' : '—',
                    style: const TextStyle(
                        color: MM.accentGreen,
                        fontWeight: FontWeight.w600),
                  )),
                  // Mileage
                  DataCell(Text(
                    v['mileage'] != null
                        ? '${_formatNumber(v['mileage'])} mi' : '—',
                    style: const TextStyle(color: MM.textSub),
                  )),
                  // Status badge
                  DataCell(_StatusBadge(status)),
                  // Featured toggle
                  DataCell(
                    GestureDetector(
                      onTap: () => _toggleFeatured(
                          id, !isFeatured, label),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isFeatured
                              ? MM.accentAmber.withOpacity(0.12)
                              : MM.bgSurface,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isFeatured
                                ? MM.accentAmber.withOpacity(0.35)
                                : MM.border,
                          ),
                        ),
                        child: Icon(
                          isFeatured
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isFeatured
                              ? MM.accentAmber : MM.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  // Actions
                  DataCell(
                    Theme(
                      data: ThemeData.dark().copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: MM.bgSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: MM.border),
                          ),
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: MM.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: MM.border),
                          ),
                          child: const Icon(
                              Icons.more_horiz_rounded,
                              color: MM.textSub, size: 18),
                        ),
                        onSelected: (value) async {
                          switch (value) {
                            case 'view':
                              _showToast('View page coming soon.');
                              break;
                            case 'edit':
                              _showToast('Edit page coming soon.');
                              break;
                            case 'available':
                              await _updateStatus(
                                  id, 'available', label);
                              break;
                            case 'reserved':
                              await _updateStatus(
                                  id, 'reserved', label);
                              break;
                            case 'sold':
                              await _updateStatus(
                                  id, 'sold', label);
                              break;
                            case 'feature':
                              await _toggleFeatured(
                                  id, true, label);
                              break;
                            case 'unfeature':
                              await _toggleFeatured(
                                  id, false, label);
                              break;
                            case 'delete':
                              await _deleteVehicle(id, label);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          _menuItem('view',      'View details',
                              Icons.visibility_outlined,    MM.textSub),
                          _menuItem('edit',      'Edit vehicle',
                              Icons.edit_outlined,           MM.brandBlue),
                          const PopupMenuDivider(),
                          _menuItem('available', 'Mark Available',
                              Icons.check_circle_outline,   MM.accentGreen),
                          _menuItem('reserved',  'Mark Reserved',
                              Icons.event_outlined,         MM.accentAmber),
                          _menuItem('sold',      'Mark Sold',
                              Icons.sell_outlined,          MM.accentRed),
                          const PopupMenuDivider(),
                          _menuItem('feature',   'Add to featured',
                              Icons.star_outline_rounded,   MM.accentAmber),
                          _menuItem('unfeature', 'Remove featured',
                              Icons.star_border_rounded,    MM.textSub),
                          const PopupMenuDivider(),
                          _menuItem('delete',    'Delete vehicle',
                              Icons.delete_outline_rounded, MM.accentRed),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: color == MM.textSub ? MM.textPrimary : color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── States
  Widget _buildLoader() {
    return const Center(
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
          Text('Loading inventory…',
              style: TextStyle(color: MM.textSub, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: MM.textMuted, size: 52),
          const SizedBox(height: 16),
          const Text('Could not load inventory.',
              style: TextStyle(
                  color: MM.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Check your connection and try again.',
              style: TextStyle(color: MM.textSub, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: loadInventory,
            style: ElevatedButton.styleFrom(
              backgroundColor: MM.brandBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 18),
            label: const Text('Try again',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered =
        _searchQuery.isNotEmpty || _selectedStatus != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: MM.bgSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MM.border),
              ),
              child: const Icon(Icons.directions_car_rounded,
                  color: MM.textMuted, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'No vehicles match your filters.'
                  : 'No vehicles in inventory yet.',
              style: const TextStyle(
                  color: MM.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try adjusting your search or filter.'
                  : 'Add your first vehicle to get started.',
              style: const TextStyle(
                  color: MM.textSub, fontSize: 13),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(
                    builder: (context) => const AddVehiclePage(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: MM.brandBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Add Vehicle',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers
  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final n = int.tryParse(value.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────
//  Status Badge — shared widget
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = MM.statusColor(status);
    final label = MM.statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}