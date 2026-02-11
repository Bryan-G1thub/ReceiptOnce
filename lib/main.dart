import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'data/receipt.dart';
import 'data/receipt_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReceiptOnceApp());
}

class ReceiptOnceApp extends StatelessWidget {
  const ReceiptOnceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReceiptOnce',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _headerGreen,
          primary: _headerGreen,
        ),
        scaffoldBackgroundColor: _lightBackground,
        useMaterial3: true,
      ),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

const Color _headerGreen = Color(0xFF1F8A5B);
const Color _lightBackground = Color(0xFFF4F5F7);
const Color _darkText = Color(0xFF232323);
const Color _mutedText = Color(0xFF7B7B7B);

class MainShellController {
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);

  static void setTab(int index) {
    tabIndex.value = index;
  }

  static void notifyDataChanged() {
    refreshTick.value++;
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();
  final GlobalKey<_ReceiptsHubPageState> _receiptsKey =
      GlobalKey<_ReceiptsHubPageState>();
  final GlobalKey<_MenuPageState> _menuKey = GlobalKey<_MenuPageState>();
  int _activeIndex = 0;
  late final VoidCallback _tabListener;

  Future<void> _openCamera() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
    _homeKey.currentState?.refresh();
    _receiptsKey.currentState?.refresh();
  }

  @override
  void initState() {
    super.initState();
    _tabListener = () {
      if (!mounted) return;
      setState(() {
        _activeIndex = MainShellController.tabIndex.value;
      });
    };
    MainShellController.tabIndex.addListener(_tabListener);
  }

  @override
  void dispose() {
    MainShellController.tabIndex.removeListener(_tabListener);
    super.dispose();
  }

  void _goHome() {
    MainShellController.setTab(0);
  }

  void _goReceipts() {
    MainShellController.setTab(1);
  }

  void _goMenu() {
    MainShellController.setTab(2);
  }

  void _focusSearch() {
    MainShellController.setTab(0);
    _homeKey.currentState?.focusSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _activeIndex,
        children: [
          HomeScreen(
            key: _homeKey,
            onOpenReceipts: _goReceipts,
          ),
          ReceiptsHubPage(
            key: _receiptsKey,
            showBack: false,
          ),
          MenuPage(
            key: _menuKey,
            showBack: false,
            onOpenReceipts: _goReceipts,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F7F7),
            border: Border(
              top: BorderSide(color: Color(0xFFE3E3E3)),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_filled,
                    label: 'Home',
                    active: _activeIndex == 0,
                    onTap: _goHome,
                  ),
                  _NavItem(
                    icon: Icons.search,
                    label: 'Search',
                    onTap: _focusSearch,
                  ),
                  const SizedBox(width: 56),
                  _NavItem(
                    icon: Icons.receipt_long,
                    label: 'Receipts',
                    active: _activeIndex == 1,
                    onTap: _goReceipts,
                  ),
                  _NavItem(
                    icon: Icons.menu,
                    label: 'Menu',
                    active: _activeIndex == 2,
                    onTap: _goMenu,
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openCamera,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _headerGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenReceipts;

  const HomeScreen({super.key, this.onOpenReceipts});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ReceiptDatabase _database = ReceiptDatabase.instance;
  List<Receipt> _recentReceipts = [];
  bool _loading = true;
  int _monthTotalCents = 0;
  int _monthReceiptCount = 0;
  String _topCategory = 'Other';
  int _scansLeft = 10;
  bool _isPro = false;
  late final VoidCallback _dataListener;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    MainShellController.refreshTick.removeListener(_dataListener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dataListener = () {
      if (mounted) {
        _loadHomeData();
      }
    };
    MainShellController.refreshTick.addListener(_dataListener);
    _loadHomeData();
  }

  Future<void> refresh() async {
    await _loadHomeData();
  }

  void focusSearch() {
    FocusScope.of(context).requestFocus(_searchFocus);
  }

  Future<void> _openEditReceipt(Receipt receipt) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditReceiptPage(receipt: receipt),
      ),
    );
    if (updated == true && mounted) {
      await _loadHomeData();
      MainShellController.notifyDataChanged();
    }
  }

  Future<void> _confirmDeleteReceipt(Receipt receipt) async {
    final id = receipt.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: const Text('This will remove the receipt permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deleteReceipt(id);
    if (!mounted) return;
    await _loadHomeData();
    MainShellController.notifyDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt deleted.')),
    );
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _loading = true;
    });
    final receipts = await _database.fetchReceipts();
    final isPro = await _database.isPro();
    final scanCount = await _database.getScanCount();
    final now = DateTime.now();
    final monthReceipts = receipts.where((receipt) {
      final createdAt = DateTime.tryParse(receipt.createdAt);
      if (createdAt == null) return false;
      return createdAt.year == now.year && createdAt.month == now.month;
    }).toList();
    final monthTotal = monthReceipts.fold<int>(
      0,
      (sum, receipt) => sum + (receipt.totalCents ?? 0),
    );
    final topCategory = _topCategoryFromReceipts(monthReceipts);
    if (!mounted) return;
    setState(() {
      _recentReceipts = receipts.take(3).toList();
      _monthTotalCents = monthTotal;
      _monthReceiptCount = monthReceipts.length;
      _topCategory = topCategory;
      _scansLeft = (10 - scanCount).clamp(0, 10);
      _isPro = isPro;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_searchFocus.hasFocus) {
          _searchFocus.unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
            children: [
              Container(
                width: double.infinity,
                color: _headerGreen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ReceiptOnce',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 18),
                      _SummaryCard(
                        totalCents: _monthTotalCents,
                        receiptCount: _monthReceiptCount,
                        topCategory: _topCategory,
                        scansLeft: _scansLeft,
                        isPro: _isPro,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(
                      controller: _searchController,
                      focusNode: _searchFocus,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'Recent Receipts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _darkText,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          if (widget.onOpenReceipts != null) {
                            widget.onOpenReceipts!();
                          } else {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReceiptsHubPage(),
                              ),
                            );
                            await _loadHomeData();
                          }
                        },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _headerGreen,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(
                            color: _headerGreen,
                          ),
                        ),
                      )
                    else if (_recentReceipts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: _EmptyHomeState(),
                      )
                    else
                      ..._recentReceipts.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReceiptCard(
                            receipt: item,
                            onEdit: () => _openEditReceipt(item),
                            onDelete: () => _confirmDeleteReceipt(item),
                          ),
                        ),
                      ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalCents;
  final int receiptCount;
  final String topCategory;
  final int scansLeft;
  final bool isPro;

  const _SummaryCard({
    required this.totalCents,
    required this.receiptCount,
    required this.topCategory,
    required this.scansLeft,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    final totalText = _formatCents(totalCents);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "You've spent this month",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFC6C6C6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            totalText == '--' ? '\$0.00' : totalText,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.receipt_long,
                  label: 'Receipts',
                  value: '$receiptCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.trending_up,
                  label: 'Top',
                  value: topCategory.isEmpty ? 'Other' : topCategory,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPro ? 'Pro active' : '$scansLeft free scans left',
                  style: const TextStyle(
                    color: Color(0xFFD9D9D9),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB8B8B8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB5B5B5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFEFEFEF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9E9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search receipts...',
          hintStyle: TextStyle(color: _mutedText),
          icon: Icon(Icons.search, color: _headerGreen),
        ),
      ),
    );
  }
}

class _ReceiptsSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _ReceiptsSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search by merchant, category, date, or amount',
          hintStyle: TextStyle(color: _mutedText),
          icon: Icon(Icons.search, color: _headerGreen),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String label;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E2E2)),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _FreeTierBanner extends StatelessWidget {
  final int scansLeft;

  const _FreeTierBanner({required this.scansLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F4ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBE7D7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, color: _headerGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$scansLeft free scans left before upgrade',
              style: const TextStyle(
                color: Color(0xFF1D5A3E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradePill extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Go Pro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EmptyReceiptsState extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;

  const _EmptyReceiptsState({
    required this.onScan,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F3EE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.receipt_long,
            size: 34,
            color: _headerGreen,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No receipts yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _darkText,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap + to scan your first receipt.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedText,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 180,
          child: ElevatedButton.icon(
            onPressed: onScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: _headerGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text(
              'Scan receipt',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onManual,
          child: const Text(
            'Enter manually',
            style: TextStyle(color: _headerGreen),
          ),
        ),
      ],
    );
  }
}

class _PaywallFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PaywallFeatureRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _headerGreen, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatefulWidget {
  final Receipt receipt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReceiptCard({
    required this.receipt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final split = _splitDateTime(receipt.purchaseDate);
    final dateText = (split['date'] ?? '').isEmpty
        ? _receiptDateLabel(receipt)
        : split['date'] ?? '';
    final timeText = split['time'] ?? '';
    final amountText = _formatCents(receipt.totalCents);
    final savedAt = DateTime.tryParse(receipt.createdAt);
    final hasImage =
        receipt.imagePath.isNotEmpty && File(receipt.imagePath).existsSync();
    final noteText = receipt.note.trim();
    final hasNote = noteText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: const Color(0xFFE7EFEA),
                        child: hasImage
                            ? Image.file(
                                File(receipt.imagePath),
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.receipt_long,
                                color: _headerGreen,
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receipt.merchant.isEmpty
                                ? 'Untitled receipt'
                                : receipt.merchant,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _darkText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E8E8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              receipt.category.isEmpty
                                  ? 'Other'
                                  : receipt.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5F5F5F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dateText.isEmpty ? 'Date not set' : dateText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            amountText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF45A146),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: _mutedText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasNote) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      noteText,
                      maxLines: _expanded ? null : 2,
                      overflow:
                          _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE6E6E6)),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Purchase time',
                value: timeText.isEmpty ? 'Not set' : timeText,
              ),
              _DetailRow(
                label: 'Saved',
                value: savedAt == null ? 'Unknown' : _formatDate(savedAt),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _headerGreen,
                        side: const BorderSide(color: Color(0xFFDCE8E1)),
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Color(0xFFF1D6D9)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _headerGreen : _mutedText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptItem {
  final String merchant;
  final String date;
  final String amount;
  final String category;
  final Color categoryColor;
  final IconData icon;
  final List<Color> gradient;

  const _ReceiptItem({
    required this.merchant,
    required this.date,
    required this.amount,
    required this.category,
    required this.categoryColor,
    required this.icon,
    required this.gradient,
  });
}

class _ReceiptListItem extends StatelessWidget {
  final _ReceiptItem item;

  const _ReceiptListItem({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _headerGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              item.icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.merchant,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5F5F5F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                item.amount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF45A146),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDataListItem extends StatelessWidget {
  final Receipt receipt;

  const _ReceiptDataListItem({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final amountText = _formatCents(receipt.totalCents);
    final dateText = _receiptDateLabel(receipt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _headerGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: receipt.imagePath.isNotEmpty && File(receipt.imagePath).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(
                      File(receipt.imagePath),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.merchant.isEmpty ? 'Untitled receipt' : receipt.merchant,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    receipt.category.isEmpty ? 'Other' : receipt.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5F5F5F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateText.isEmpty ? 'Date not set' : dateText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                amountText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF45A146),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeState extends StatelessWidget {
  const _EmptyHomeState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: const [
          Icon(Icons.receipt_long, color: _headerGreen, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No receipts yet. Tap + to scan your first one.',
              style: TextStyle(color: _mutedText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptsHubPage extends StatefulWidget {
  final bool showBack;

  const ReceiptsHubPage({super.key, this.showBack = true});

  @override
  State<ReceiptsHubPage> createState() => _ReceiptsHubPageState();
}

class _ReceiptsHubPageState extends State<ReceiptsHubPage> {
  final ReceiptDatabase _database = ReceiptDatabase.instance;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = const [
    'All',
    'Food',
    'Transport',
    'Shopping',
    'Office',
    'Other',
  ];
  final List<String> _sortOptions = const [
    'Newest',
    'Oldest',
    'Amount high to low',
    'Amount low to high',
  ];
  String _activeCategory = 'All';
  String _activeSort = 'Newest';
  List<Receipt> _visibleReceipts = [];
  bool _loading = true;
  bool _isPro = false;
  int _scansLeft = 10;
  int _searchRequest = 0;
  late final VoidCallback _dataListener;

  @override
  void initState() {
    super.initState();
    _dataListener = () {
      if (mounted) {
        _loadReceipts();
      }
    };
    MainShellController.refreshTick.addListener(_dataListener);
    _searchController.addListener(_applyFilters);
    _loadReceipts();
  }

  Future<void> refresh() async {
    await _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    MainShellController.refreshTick.removeListener(_dataListener);
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _loading = true;
    });
    final isPro = await _database.isPro();
    final scanCount = await _database.getScanCount();
    await _refreshVisibleReceipts(showLoading: true);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _isPro = isPro;
      _scansLeft = (10 - scanCount).clamp(0, 10);
    });
  }

  void _applyFilters() {
    _refreshVisibleReceipts();
  }

  Future<void> _refreshVisibleReceipts({bool showLoading = false}) async {
    final requestId = ++_searchRequest;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }
    final receipts = await _database.searchReceipts(
      query: _searchController.text.trim(),
      category: _activeCategory,
      sort: _activeSort,
    );
    if (!mounted || requestId != _searchRequest) return;
    setState(() {
      _visibleReceipts = receipts;
      if (showLoading) {
        _loading = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBackground,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CameraCapturePage(),
            ),
          );
          if (mounted) {
            _loadReceipts();
          }
        },
        backgroundColor: _headerGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadReceipts,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _PageHeader(
                    title: 'Receipts',
                    onBack:
                        widget.showBack ? () => Navigator.of(context).pop() : null,
                    showBack: widget.showBack,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IconButton(
                          icon: Icons.download_rounded,
                          iconColor: _headerGreen,
                          onTap: _exportReceipts,
                        ),
                        if (!_isPro) ...[
                          const SizedBox(width: 8),
                          _UpgradePill(onTap: _openPaywall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isPro)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _FreeTierBanner(scansLeft: _scansLeft),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ReceiptsSearchField(controller: _searchController),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FilterDropdown(
                          value: _activeCategory,
                          items: _categories,
                          label: 'Category',
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _activeCategory = value;
                            });
                            _refreshVisibleReceipts();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FilterDropdown(
                          value: _activeSort,
                          items: _sortOptions,
                          label: 'Sort',
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _activeSort = value;
                            });
                            _refreshVisibleReceipts();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 12),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _headerGreen,
                    ),
                  ),
                )
              else if (_visibleReceipts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: _EmptyReceiptsState(
                      onScan: _handleEmptyScan,
                      onManual: _handleEmptyManual,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final receipt = _visibleReceipts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReceiptCard(
                            receipt: receipt,
                            onEdit: () => _openEditReceipt(receipt),
                            onDelete: () => _confirmDeleteReceipt(receipt),
                          ),
                        );
                      },
                      childCount: _visibleReceipts.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportReceipts() async {
    final receipts = await _database.fetchReceipts();
    if (receipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipts to export yet.')),
      );
      return;
    }
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        'Merchant,Total,Purchase Date,Category,Note,Created At',
      );
      for (final receipt in receipts) {
        buffer.writeln(
          [
            _csvValue(receipt.merchant),
            _csvValue(_formatCents(receipt.totalCents)),
            _csvValue(receipt.purchaseDate),
            _csvValue(receipt.category),
            _csvValue(receipt.note),
            _csvValue(receipt.createdAt),
          ].join(','),
        );
      }
      final dir = await getTemporaryDirectory();
      final filename = 'receiptonce-export-${DateTime.now().millisecondsSinceEpoch}.csv';
      final path = p.join(dir.path, filename);
      await File(path).writeAsString(buffer.toString());
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'ReceiptOnce export',
        text: 'Your ReceiptOnce export is attached.',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export receipts.')),
      );
    }
  }

  Future<void> _openEditReceipt(Receipt receipt) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditReceiptPage(receipt: receipt),
      ),
    );
    if (updated == true && mounted) {
      _loadReceipts();
      MainShellController.notifyDataChanged();
    }
  }

  Future<void> _confirmDeleteReceipt(Receipt receipt) async {
    final id = receipt.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: const Text('This will remove the receipt permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deleteReceipt(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt deleted.')),
    );
    _loadReceipts();
    MainShellController.notifyDataChanged();
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallPage()),
    );
    if (mounted) {
      _loadReceipts();
    }
  }

  Future<void> _handleEmptyScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraCapturePage(),
      ),
    );
    if (mounted) {
      _loadReceipts();
    }
  }

  Future<void> _handleEmptyManual() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManualEntryPage(),
      ),
    );
    if (mounted) {
      _loadReceipts();
    }
  }
}

class ReceiptDetailPage extends StatefulWidget {
  final Receipt receipt;

  const ReceiptDetailPage({super.key, required this.receipt});

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final amountText = _formatCents(receipt.totalCents);
    final split = _splitDateTime(receipt.purchaseDate);
    final dateText = split['date'] ?? '';
    final timeText = split['time'] ?? '';
    final savedAt = DateTime.tryParse(receipt.createdAt);
    final hasImage =
        receipt.imagePath.isNotEmpty && File(receipt.imagePath).existsSync();

    return Scaffold(
      backgroundColor: _lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(
                title: 'Receipt details',
                onBack: () => Navigator.of(context).pop(),
                trailing: _IconButton(
                  icon: Icons.edit_outlined,
                  onTap: _handleEdit,
                ),
              ),
              const SizedBox(height: 16),
              if (hasImage)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceiptImageViewer(
                          imagePath: receipt.imagePath,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(receipt.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              if (hasImage) const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.merchant.isEmpty
                          ? 'Untitled receipt'
                          : receipt.merchant,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      amountText == '--' ? '\$0.00' : amountText,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF45A146),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Category',
                      value: receipt.category.isEmpty ? 'Other' : receipt.category,
                    ),
                    _DetailRow(
                      label: 'Purchase date',
                      value: dateText.isEmpty ? 'Not set' : dateText,
                    ),
                    _DetailRow(
                      label: 'Purchase time',
                      value: timeText.isEmpty ? 'Not set' : timeText,
                    ),
                    _DetailRow(
                      label: 'Saved',
                      value: savedAt == null ? 'Unknown' : _formatDate(savedAt),
                    ),
                  ],
                ),
              ),
              if (receipt.note.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Note',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        receipt.note,
                        style: const TextStyle(color: _darkText),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Edit receipt',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : _handleDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                    backgroundColor: Colors.white,
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEdit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditReceiptPage(receipt: widget.receipt),
      ),
    );
    if (updated == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleDelete() async {
    if (_isDeleting) return;
    final id = widget.receipt.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: const Text('This will remove the receipt permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _isDeleting = true;
    });
    await ReceiptDatabase.instance.deleteReceipt(id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    MainShellController.notifyDataChanged();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class EditReceiptPage extends StatefulWidget {
  final Receipt receipt;

  const EditReceiptPage({super.key, required this.receipt});

  @override
  State<EditReceiptPage> createState() => _EditReceiptPageState();
}

class _EditReceiptPageState extends State<EditReceiptPage> {
  late final TextEditingController _merchantController;
  late final TextEditingController _totalController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final split = _splitDateTime(widget.receipt.purchaseDate);
    _merchantController = TextEditingController(text: widget.receipt.merchant);
    _totalController = TextEditingController(
      text: widget.receipt.totalCents == null
          ? ''
          : (widget.receipt.totalCents! / 100).toStringAsFixed(2),
    );
    _dateController = TextEditingController(text: split['date'] ?? '');
    _timeController = TextEditingController(text: split['time'] ?? '');
    _categoryController = TextEditingController(text: widget.receipt.category);
    _noteController = TextEditingController(text: widget.receipt.note);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.receipt.imagePath.isNotEmpty &&
        File(widget.receipt.imagePath).existsSync();
    return WillPopScope(
      onWillPop: () async {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _lightBackground,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _headerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  title: 'Edit receipt',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                if (hasImage)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReceiptImageViewer(
                            imagePath: widget.receipt.imagePath,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          File(widget.receipt.imagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                if (hasImage) const SizedBox(height: 16),
                _InputField(
                  label: 'Merchant',
                  controller: _merchantController,
                  icon: Icons.storefront,
                  iconColor: _headerGreen,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Total',
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  icon: Icons.payments_outlined,
                  iconColor: _headerGreen,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        label: 'Purchase date',
                        controller: _dateController,
                        icon: Icons.calendar_today_outlined,
                        iconColor: _headerGreen,
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InputField(
                        label: 'Purchase time',
                        controller: _timeController,
                        icon: Icons.access_time,
                        iconColor: _headerGreen,
                        readOnly: true,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Category',
                  controller: _categoryController,
                  icon: Icons.sell_outlined,
                  iconColor: _headerGreen,
                ),
                const SizedBox(height: 16),
                _InputField(
                  label: 'Note (optional)',
                  controller: _noteController,
                  icon: Icons.edit_note,
                  iconColor: _headerGreen,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: _isSaving ? null : _handleDelete,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1D6D9)),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      final merchant = _merchantController.text.trim();
      final totalText = _totalController.text.trim();
      final purchaseDate = _combineDateTime(
        _dateController.text,
        _timeController.text,
      );
      final categoryText = _categoryController.text.trim();
      final category = categoryText.isEmpty ? 'Other' : categoryText;
      final totalCents = _parseTotalCents(totalText);
      final note = _noteController.text.trim();
      final updated = widget.receipt.copyWith(
        merchant: merchant,
        totalCents: totalCents,
        purchaseDate: purchaseDate,
        category: category,
        note: note,
      );
      final rows = await ReceiptDatabase.instance.updateReceipt(updated);
      if (!mounted) return;
      if (rows == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this receipt.')),
        );
        return;
      }
      Navigator.of(context).pop(true);
      MainShellController.notifyDataChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this receipt.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final id = widget.receipt.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: const Text('This will remove the receipt permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ReceiptDatabase.instance.deleteReceipt(id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _dateController.text = _formatDate(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    _timeController.text = _formatTimeOfDay(context, picked);
  }
}

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  static const String _proProductId = 'receiptonce_pro';
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _product;
  bool _processing = false;
  bool _loadingProduct = true;
  bool _storeAvailable = false;
  String? _storeError;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription =
        _iap.purchaseStream.listen(_handlePurchaseUpdates, onError: (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase failed. Try again.')),
      );
    });
    _loadStore();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStore() async {
    final available = await _iap.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _loadingProduct = false;
        _storeAvailable = false;
        _storeError = 'Store unavailable right now.';
      });
      return;
    }
    final response = await _iap.queryProductDetails({_proProductId});
    if (!mounted) return;
    if (response.error != null) {
      setState(() {
        _loadingProduct = false;
        _storeAvailable = false;
        _storeError = response.error!.message;
      });
      return;
    }
    if (response.productDetails.isEmpty) {
      setState(() {
        _loadingProduct = false;
        _storeAvailable = false;
        _storeError = 'Product not found. Check store IDs.';
      });
      return;
    }
    setState(() {
      _product = response.productDetails.first;
      _loadingProduct = false;
      _storeAvailable = true;
    });
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) {
          setState(() {
            _processing = true;
          });
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _processing = false;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase failed.')),
          );
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _deliverPro();
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverPro() async {
    await ReceiptDatabase.instance.setPro(true);
    if (!mounted) return;
    setState(() {
      _processing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ReceiptOnce Pro unlocked.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _startPurchase() async {
    if (_processing || !_storeAvailable || _product == null) return;
    setState(() {
      _processing = true;
    });
    final purchaseParam = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    final priceDisplay = _product?.price ?? '\$4.99';
    return Scaffold(
      backgroundColor: _headerGreen,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Price tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _headerGreen.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_offer,
                              color: _headerGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lifetime Access',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _mutedText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                priceDisplay,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: _darkText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Title
                    const Text(
                      'ReceiptOnce Pro',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Keep every receipt in one place and export whenever tax season arrives.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Features
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        children: const [
                          _PaywallFeatureRowDark(
                            icon: Icons.all_inclusive,
                            text: 'Unlimited receipt scans',
                          ),
                          SizedBox(height: 16),
                          _PaywallFeatureRowDark(
                            icon: Icons.cloud_download_outlined,
                            text: 'Export CSV anytime',
                          ),
                          SizedBox(height: 16),
                          _PaywallFeatureRowDark(
                            icon: Icons.lock_open_outlined,
                            text: 'One-time purchase, no subscriptions',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Loading indicator
                    if (_loadingProduct)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    // Error message
                    if (_storeError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _storeError!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    // Purchase button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _processing || !_storeAvailable
                            ? null
                            : _startPurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _headerGreen,
                          disabledBackgroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _headerGreen,
                                ),
                              )
                            : const Text(
                                'Unlock Pro',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pay once, own forever',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // TODO: Remove after testing
                    TextButton(
                      onPressed: () async {
                        await ReceiptDatabase.instance.resetScanCount();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('DEV: 10 free scans restored')),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text(
                        'DEV: Reset scans',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallFeatureRowDark extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PaywallFeatureRowDark({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class MenuPage extends StatefulWidget {
  final bool showBack;
  final VoidCallback? onOpenReceipts;

  const MenuPage({
    super.key,
    this.showBack = true,
    this.onOpenReceipts,
  });

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool _loading = true;
  bool _isPro = false;
  int _scanCount = 0;
  late final VoidCallback _dataListener;

  @override
  void initState() {
    super.initState();
    _dataListener = () {
      if (mounted) {
        _loadMenuData();
      }
    };
    MainShellController.refreshTick.addListener(_dataListener);
    _loadMenuData();
  }

  @override
  void dispose() {
    MainShellController.refreshTick.removeListener(_dataListener);
    super.dispose();
  }

  Future<void> refresh() async {
    await _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() {
      _loading = true;
    });
    final isPro = await ReceiptDatabase.instance.isPro();
    final scanCount = await ReceiptDatabase.instance.getScanCount();
    if (!mounted) return;
    setState(() {
      _isPro = isPro;
      _scanCount = scanCount;
      _loading = false;
    });
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallPage()),
    );
    if (mounted) {
      _loadMenuData();
    }
  }

  Future<void> _openReceipts() async {
    if (widget.onOpenReceipts != null) {
      widget.onOpenReceipts!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReceiptsHubPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scansLeft = (10 - _scanCount).clamp(0, 10);
    return Scaffold(
      backgroundColor: _lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(
                title: 'Menu',
                onBack: widget.showBack ? () => Navigator.of(context).pop() : null,
                showBack: widget.showBack,
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: _headerGreen),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isPro ? 'Plan: Pro' : 'Plan: Free',
                        style: const TextStyle(
                          fontSize: 14,
                          color: _mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_isPro) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$scansLeft free scans left',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPro ? null : _openPaywall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isPro ? 'Pro active' : 'Upgrade to Pro',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openReceipts,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _darkText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E2E2)),
                    backgroundColor: Colors.white,
                  ),
                  child: const Text('View receipts'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  static bool _hasShownExplainer = false;
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  final List<XFile> _selectedImages = [];
  int _activeImageIndex = 0;
  Timer? _slowTimer;
  bool _isProcessing = false;
  bool _showSlowNotice = false;
  bool _cameraReady = false;
  bool _cameraInitFailed = false;
  bool _showingTips = false;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _cameraController?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_startFlow);
  }

  Future<void> _startFlow() async {
    if (!_hasShownExplainer) {
      _hasShownExplainer = true;
      await _showTipsDialog();
    }

    final granted = await _requestCameraPermission();
    if (!mounted) return;
    if (!granted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ManualEntryPage(
            showPermissionNotice: true,
          ),
        ),
      );
      return;
    }
    await _initializeCamera();
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> _requestGalleryPermission() async {
    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) return true;
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraReady = false;
            _cameraInitFailed = true;
          });
        }
        return;
      }
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _cameraInitFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraReady = false;
          _cameraInitFailed = true;
        });
      }
    }
  }

  Future<void> _showTipsDialog() async {
    if (_showingTips) return;
    setState(() {
      _showingTips = true;
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan receipts automatically',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Next, we'll open your camera. For best results:",
                style: TextStyle(color: _mutedText),
              ),
              const SizedBox(height: 12),
              _TipRow(
                icon: Icons.light_mode,
                text: 'Use good lighting and avoid glare.',
              ),
              const SizedBox(height: 8),
              _TipRow(
                icon: Icons.crop,
                text: 'Fit the full receipt in the frame.',
              ),
              const SizedBox(height: 8),
              _TipRow(
                icon: Icons.contrast,
                text: 'Keep text sharp with high contrast.',
              ),
              const SizedBox(height: 8),
              _TipRow(
                icon: Icons.photo_library,
                text: 'Import a photo from your gallery anytime.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Prefer manual entry? Tap “Enter manually” below.',
                style: TextStyle(color: _mutedText),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _showingTips = false;
      });
    }
  }

  Future<void> _handleUsePhoto() async {
    if (_selectedImages.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _showSlowNotice = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isProcessing) {
        setState(() {
          _showSlowNotice = true;
        });
      }
    });

    try {
      final result = await _ocrService.readReceipt(
        _selectedImages.map((image) => image.path).toList(),
      );
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptEditorPage(
            draft: ReceiptDraft.fromOcr(result),
          ),
        ),
      );
    } catch (_) {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read this receipt.')),
      );
    }
  }

  Future<void> _handleCapture() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      final file = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _selectedImages.add(file);
        _activeImageIndex = _selectedImages.length - 1;
      });
    } catch (_) {}
  }

  Future<void> _handleImportPhoto() async {
    final granted = await _requestGalleryPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allow photo access to import images.')),
      );
      return;
    }
    final files = await _imagePicker.pickMultiImage();
    if (!mounted) return;
    if (files.isEmpty) {
      final single = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (single == null) return;
      setState(() {
        _selectedImages.add(single);
        _activeImageIndex = _selectedImages.length - 1;
      });
      return;
    }
    setState(() {
      _selectedImages.addAll(files);
      _activeImageIndex = _selectedImages.length - 1;
    });
  }

  Widget _buildPreview() {
    if (_selectedImages.isNotEmpty) {
      return Image.file(
        File(_selectedImages[_activeImageIndex].path),
        fit: BoxFit.cover,
      );
    }
    if (_cameraController?.value.isInitialized ?? false) {
      final controller = _cameraController!;
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 0,
          height: controller.value.previewSize?.width ?? 0,
          child: CameraPreview(controller),
        ),
      );
    }
    if (_cameraInitFailed) {
      return const Center(
        child: Text(
          'Camera unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return const Center(
      child: Text(
        'Opening camera...',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reserve space for controls at the bottom by keeping the preview
    // a bit smaller than the full height. The whole page is scrollable
    // so we avoid bottom overflow on shorter screens.
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = screenHeight * 0.6;
    return Scaffold(
      backgroundColor: _lightBackground,
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        _IconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Scan receipt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                        ),
                        const Spacer(),
                        _IconButton(
                          icon: Icons.help_outline,
                          onTap: _showTipsDialog,
                          iconColor: _headerGreen,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: previewHeight,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEDED),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD6D6D6)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPreview(),
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _selectedImages.isEmpty
                                    ? GestureDetector(
                                        onTap:
                                            _cameraReady ? _handleCapture : null,
                                        child: Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color:
                                                _headerGreen.withOpacity(0.18),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  _headerGreen.withOpacity(0.6),
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: _headerGreen,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_selectedImages.length} photo${_selectedImages.length == 1 ? '' : 's'} selected',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty)
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final image = _selectedImages[index];
                          final isActive = index == _activeImageIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeImageIndex = index;
                              });
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? _headerGreen
                                      : const Color(0xFFD0D0D0),
                                  width: isActive ? 2 : 1,
                                ),
                                image: DecorationImage(
                                  image: FileImage(File(image.path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: _selectedImages.length,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: _selectedImages.isEmpty
                        ? Row(
                            children: [
                              Expanded(
                                child: _ActionCard(
                                  icon: Icons.photo_library_outlined,
                                  label: 'Import photo',
                                  onTap: _handleImportPhoto,
                                  dark: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionCard(
                                  icon: Icons.edit_outlined,
                                  label: 'Enter manually',
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ManualEntryPage(),
                                      ),
                                    );
                                  },
                                  dark: true,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleUsePhoto,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _headerGreen,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    'Scan ${_selectedImages.length} photo${_selectedImages.length == 1 ? '' : 's'}',
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionCard(
                                      icon: Icons.add_photo_alternate_outlined,
                                      label: 'Add photo',
                                      onTap: _handleImportPhoto,
                                      dark: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ActionCard(
                                      icon: Icons.edit_outlined,
                                      label: 'Enter manually',
                                      onTap: () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ManualEntryPage(),
                                          ),
                                        );
                                      },
                                      dark: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Reading receipt...',
                        style: TextStyle(color: Colors.white),
                      ),
                      if (_showSlowNotice)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'This is taking longer than usual...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReceiptEditorPage extends StatefulWidget {
  final ReceiptDraft draft;

  const ReceiptEditorPage({super.key, required this.draft});

  @override
  State<ReceiptEditorPage> createState() => _ReceiptEditorPageState();
}

class _ReceiptEditorPageState extends State<ReceiptEditorPage> {
  late final TextEditingController _merchantController;
  late final TextEditingController _totalController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final split = _splitDateTime(widget.draft.date);
    _merchantController = TextEditingController(text: widget.draft.merchant);
    _totalController = TextEditingController(text: widget.draft.total);
    _dateController = TextEditingController(text: split['date'] ?? '');
    _timeController = TextEditingController(text: split['time'] ?? '');
    _categoryController = TextEditingController(text: widget.draft.category);
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confidence = widget.draft.confidence;
    String helperText = 'Please verify the details below.';
    if (confidence < 0.2) {
      helperText = "We couldn't read this one. Please fill it in.";
    } else if (confidence < 0.6) {
      helperText = 'We filled what we could — please double-check.';
    }
    return WillPopScope(
      onWillPop: () async {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _lightBackground,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _headerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm receipt',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  title: 'Review receipt',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: widget.draft.imagePath.isNotEmpty
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReceiptImageViewer(
                                imagePath: widget.draft.imagePath,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: widget.draft.imagePath.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(widget.draft.imagePath),
                                  fit: BoxFit.cover,
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Tap to zoom',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Text(
                                'Receipt photo',
                                style: TextStyle(color: _mutedText),
                              ),
                            ),
                    ),
                  ),
                ),
                if (widget.draft.rawText.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.draft.rawText),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('OCR text copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy OCR'),
                      style: TextButton.styleFrom(
                        foregroundColor: _mutedText,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F4ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    helperText,
                    style: const TextStyle(
                      color: Color(0xFF1D5A3E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _InputField(
                  label: 'Merchant',
                  controller: _merchantController,
                  icon: Icons.storefront,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Total',
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        label: 'Purchase date',
                        controller: _dateController,
                        icon: Icons.calendar_today_outlined,
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InputField(
                        label: 'Purchase time',
                        controller: _timeController,
                        icon: Icons.access_time,
                        readOnly: true,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Category',
                  controller: _categoryController,
                  icon: Icons.sell_outlined,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Note (optional)',
                  controller: _noteController,
                  icon: Icons.edit_note,
                  maxLines: 3,
                ),
                if (confidence < 0.2)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const ManualEntryPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _headerGreen,
                          side: BorderSide(color: _headerGreen),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Enter manually'),
                      ),
                    ),
                  ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      final merchant = _merchantController.text.trim();
      final totalText = _totalController.text.trim();
      final purchaseDate = _combineDateTime(
        _dateController.text,
        _timeController.text,
      );
      final categoryText = _categoryController.text.trim();
      final category = categoryText.isEmpty ? 'Other' : categoryText;
      final totalCents = _parseTotalCents(totalText);
      final note = _noteController.text.trim();
      final receipt = Receipt(
        merchant: merchant,
        totalCents: totalCents,
        purchaseDate: purchaseDate,
        category: category,
        imagePath: widget.draft.imagePath,
        rawText: widget.draft.rawText,
        note: note,
        createdAt: DateTime.now().toIso8601String(),
      );
      final database = ReceiptDatabase.instance;
      final isPro = await database.isPro();
      if (!isPro) {
        final scanCount = await database.getScanCount();
        if (scanCount >= 10) {
          if (!mounted) return;
          final shouldUpgrade = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Free scans used'),
              content: const Text(
                'You have used all 10 free scans. Upgrade to keep scanning receipts.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerGreen,
                  ),
                  child: const Text(
                    'Upgrade',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
          if (shouldUpgrade == true && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallPage()),
            );
          }
          return;
        }
      }
      await database.insertReceipt(receipt);
      if (!isPro) {
        await database.incrementScanCount();
      }
      MainShellController.notifyDataChanged();
      if (!mounted) return;
      MainShellController.setTab(1);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this receipt.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _dateController.text = _formatDate(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    _timeController.text = _formatTimeOfDay(context, picked);
  }
}

class ManualEntryPage extends StatefulWidget {
  final bool showPermissionNotice;

  const ManualEntryPage({super.key, this.showPermissionNotice = false});

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _lightBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  title: 'Enter receipt',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                if (widget.showPermissionNotice)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F1E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Color(0xFF7A6A2E)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Camera permission is off. Enable it in Settings to scan.',
                            style: TextStyle(
                              color: Color(0xFF7A6A2E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            openAppSettings();
                          },
                          child: const Text('Settings'),
                        ),
                      ],
                    ),
                  ),
                if (widget.showPermissionNotice) const SizedBox(height: 16),
                _InputField(
                  label: 'Merchant',
                  controller: _merchantController,
                  icon: Icons.storefront,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Total',
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        label: 'Purchase date',
                        controller: _dateController,
                        icon: Icons.calendar_today_outlined,
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InputField(
                        label: 'Purchase time',
                        controller: _timeController,
                        icon: Icons.access_time,
                        readOnly: true,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Category',
                  controller: _categoryController,
                  icon: Icons.sell_outlined,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Note (optional)',
                  controller: _noteController,
                  icon: Icons.edit_note,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _headerGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save receipt',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      final merchant = _merchantController.text.trim();
      final totalText = _totalController.text.trim();
      final purchaseDate = _combineDateTime(
        _dateController.text,
        _timeController.text,
      );
      final categoryText = _categoryController.text.trim();
      final category = categoryText.isEmpty ? 'Other' : categoryText;
      final totalCents = _parseTotalCents(totalText);
      final note = _noteController.text.trim();
      final receipt = Receipt(
        merchant: merchant,
        totalCents: totalCents,
        purchaseDate: purchaseDate,
        category: category,
        imagePath: '',
        rawText: '',
        note: note,
        createdAt: DateTime.now().toIso8601String(),
      );
      await ReceiptDatabase.instance.insertReceipt(receipt);
      MainShellController.notifyDataChanged();
      if (!mounted) return;
      MainShellController.setTab(1);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this receipt.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _dateController.text = _formatDate(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    _timeController.text = _formatTimeOfDay(context, picked);
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;

  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.icon,
    this.iconColor,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A4A4A),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF1F1F1),
            prefixIcon: icon == null
                ? null
                : Icon(
                    icon,
                    color: iconColor ?? const Color(0xFF9A9A9A),
                    size: 20,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _headerGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF2A2A2A) : Colors.white;
    final border = dark ? const Color(0xFF3A3A3A) : const Color(0xFFE2E2E2);
    final textColor = dark ? const Color(0xFFF1F1F1) : _darkText;
    final iconColor = dark ? const Color(0xFFB6B6B6) : _headerGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;

  const _PageHeader({
    required this.title,
    this.onBack,
    this.trailing,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    if (showBack && onBack == null) {
      throw ArgumentError('onBack is required when showBack is true.');
    }
    return Row(
      children: [
        if (showBack)
          _IconButton(
            icon: Icons.arrow_back,
            onTap: onBack!,
          )
        else
          const SizedBox(width: 36, height: 36),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: Icon(icon, color: iconColor ?? _darkText, size: 20),
      ),
    );
  }
}

int? _parseTotalCents(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null) return null;
  return (value * 100).round();
}

String _formatCents(int? cents) {
  if (cents == null) return '--';
  final value = cents / 100;
  return '\$${value.toStringAsFixed(2)}';
}

String _receiptDateLabel(Receipt receipt) {
  final dateText = receipt.purchaseDate.trim();
  if (dateText.isNotEmpty) return dateText;
  final createdAt = DateTime.tryParse(receipt.createdAt);
  if (createdAt == null) return '';
  return _formatDate(createdAt);
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}

Map<String, String> _splitDateTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return {'date': '', 'time': ''};
  }
  final parts = trimmed.split('•');
  if (parts.length == 1) {
    return {'date': trimmed, 'time': ''};
  }
  return {
    'date': parts.first.trim(),
    'time': parts.sublist(1).join('•').trim(),
  };
}

String _combineDateTime(String date, String time) {
  final trimmedDate = date.trim();
  final trimmedTime = time.trim();
  if (trimmedDate.isEmpty) return '';
  if (trimmedTime.isEmpty) return trimmedDate;
  return '$trimmedDate • $trimmedTime';
}

String _formatTimeOfDay(BuildContext context, TimeOfDay time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: false,
  );
}

String _csvValue(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _topCategoryFromReceipts(List<Receipt> receipts) {
  if (receipts.isEmpty) return 'Other';
  final counts = <String, int>{};
  for (final receipt in receipts) {
    final key = receipt.category.isEmpty ? 'Other' : receipt.category;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.first.key;
}

class ReceiptDraft {
  final String merchant;
  final String total;
  final String date;
  final String category;
  final String rawText;
  final String imagePath;
  final String capturedAt;
  final double confidence;

  const ReceiptDraft({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
    required this.imagePath,
    required this.capturedAt,
    required this.confidence,
  });

  factory ReceiptDraft.fromOcr(OcrResult result) {
    if (result.confidence < 0.2) {
      return ReceiptDraft(
        merchant: '',
        total: '',
        date: '',
        category: '',
        rawText: result.rawText,
        imagePath: result.imagePath,
        capturedAt: result.capturedAt,
        confidence: result.confidence,
      );
    }
    return ReceiptDraft(
      merchant: result.merchant,
      total: result.total,
      date: result.date,
      category: result.category,
      rawText: result.rawText,
      imagePath: result.imagePath,
      capturedAt: result.capturedAt,
      confidence: result.confidence,
    );
  }
}

class OcrResult {
  final String merchant;
  final String total;
  final String date;
  final String category;
  final String rawText;
  final String imagePath;
  final String capturedAt;
  final double confidence;

  const OcrResult({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
    required this.imagePath,
    required this.capturedAt,
    required this.confidence,
  });
}

class _OcrLine {
  final String text;
  final int index;
  final int total;

  const _OcrLine({
    required this.text,
    required this.index,
    required this.total,
  });

  double get positionRatio {
    if (total <= 1) return 0;
    return index / (total - 1);
  }
}

class _AmountCandidate {
  final double value;
  final int lineIndex;

  const _AmountCandidate({
    required this.value,
    required this.lineIndex,
  });
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  Future<OcrResult> readReceipt(List<String> imagePaths) async {
    final buffer = StringBuffer();
    for (final path in imagePaths) {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _recognizer.processImage(inputImage);
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln(recognizedText.text);
    }
    final rawText = buffer.toString();
    final imagePath = imagePaths.isNotEmpty ? imagePaths.first : '';
    return _parseReceipt(rawText, imagePath);
  }

  void dispose() {
    _recognizer.close();
  }

  OcrResult _parseReceipt(String rawText, String imagePath) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final ocrLines = List.generate(
      lines.length,
      (index) => _OcrLine(text: lines[index], index: index, total: lines.length),
    );
    final merchant = _guessMerchant(ocrLines);
    final total = _guessTotal(ocrLines);
    final date = _guessDate(ocrLines);
    final category = _guessCategory(merchant);
    final confidence = _estimateConfidence(rawText);
    return OcrResult(
      merchant: merchant,
      total: total,
      date: date,
      category: category,
      rawText: rawText,
      imagePath: imagePath,
      capturedAt: DateTime.now().toIso8601String(),
      confidence: confidence,
    );
  }

  String _guessMerchant(List<_OcrLine> lines) {
    final topLines = lines.where((line) => line.positionRatio <= 0.2).toList();
    final candidates = _filterMerchantCandidates(
      topLines.isNotEmpty ? topLines : lines,
    );
    final known = _findKnownMerchant(lines);
    if (known != null) return known;
    final fromDomain = _merchantFromDomain(lines);
    if (fromDomain != null) return fromDomain;
    if (candidates.isEmpty) {
      return lines.isNotEmpty ? _normalizeMerchant(lines.first.text) : '';
    }
    return _normalizeKnownMerchant(
      _normalizeMerchant(_pickBestMerchantLine(candidates)),
    );
  }

  String _normalizeMerchant(String value) {
    return value.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  List<_OcrLine> _filterMerchantCandidates(List<_OcrLine> lines) {
    return lines
        .where((line) {
          if (line.positionRatio > 0.25) return false;
          final text = line.text;
          if (_isLikelyTimestamp(text)) return false;
          if (_isMostlyNumbers(text)) return false;
          if (_isLikelyUrl(text)) return false;
          if (_containsDate(text)) return false;
          if (_isLikelyAddress(text)) return false;
          final upper = text.toUpperCase();
          if (upper.contains('RECEIPT') ||
              upper.contains('STORE') ||
              upper.contains('CASHIER') ||
              upper.contains('TERMINAL') ||
              upper.contains('DEBIT') ||
              upper.contains('CREDIT') ||
              upper.contains('CARD') ||
              upper.contains('TEND') ||
              upper.contains('SAVINGS') ||
              upper.contains('PAYMENTS') ||
              upper.contains('COUPONS') ||
              upper.contains('APPROVAL') ||
              upper.contains('TAX') ||
              upper.contains('WELCOME') ||
              upper.contains('TABLE') ||
              upper.contains('FEEDBACK') ||
              upper.contains('SURVEY') ||
              upper.contains('THANK') ||
              upper.contains('ID#') ||
              upper.contains('ID #') ||
              upper.contains('LOW PRICES') ||
              upper.contains('GET MORE DONE') ||
              upper.contains('DID WE NAIL IT') ||
              upper.contains('SALE')) {
            return false;
          }
          if (upper.contains('TOTAL') ||
              upper.contains('BALANCE') ||
              upper.contains('SUBTOTAL')) {
            return false;
          }
          return RegExp(r'[A-Za-z]').hasMatch(text);
        })
        .toList();
  }

  String _guessTotal(List<_OcrLine> lines) {
    const keywords = [
      'TOTAL',
      'BALANCE DUE',
      'AMOUNT DUE',
      'GRAND TOTAL',
      'TOTAL DUE',
    ];
    final keywordLineIndexes = <int>{};
    final candidates = <_AmountCandidate>[];
    final candidateText = <int, String>{};
    for (final line in lines) {
      final upper = line.text.toUpperCase();
      if (keywords.any((keyword) => upper.contains(keyword))) {
        keywordLineIndexes.add(line.index);
      }
      final amounts = _extractAmounts(line.text);
      if (amounts.isNotEmpty) {
        for (final value in amounts) {
          candidates.add(_AmountCandidate(value: value, lineIndex: line.index));
          candidateText[line.index] = line.text;
        }
      }
    }
    if (candidates.isEmpty) return '';

    final totalLines = lines.isEmpty ? 1 : lines.length;
    final bottomStart = (totalLines * 0.7).floor();
    final inBottom = candidates.where((c) => c.lineIndex >= bottomStart).toList();
    final withKeyword = candidates.where((c) {
      return keywordLineIndexes.any((idx) => (idx - c.lineIndex).abs() <= 1);
    }).toList();
    final bottomWithKeyword = inBottom.where((c) {
      return keywordLineIndexes.any((idx) => (idx - c.lineIndex).abs() <= 1);
    }).toList();

    final strongTotals = candidates.where((c) {
      final text = (candidateText[c.lineIndex] ?? '').toUpperCase();
      if (!text.contains('TOTAL')) return false;
      if (text.contains('SUBTOTAL') ||
          text.contains('SAVINGS') ||
          text.contains('TAX') ||
          text.contains('BAL') ||
          text.contains('BEGIN') ||
          text.contains('END') ||
          text.contains('ACCOUNT') ||
          text.contains('TEND') ||
          text.contains('CHANGE') ||
          text.contains('DEBIT') ||
          text.contains('CREDIT')) {
        return false;
      }
      return true;
    }).toList();

    double? bestMatch;
    bestMatch = _pickLargestAmount(strongTotals);
    bestMatch ??= _pickLargestAmount(bottomWithKeyword);
    bestMatch ??= _pickLargestAmount(inBottom);
    bestMatch ??= _pickLargestAmount(withKeyword);
    bestMatch ??= _pickLargestAmount(candidates);
    if (bestMatch == null) return '';
    return '\$${bestMatch.toStringAsFixed(2)}';
  }

  List<double> _extractAmounts(String text) {
    final matches = RegExp(r'(\$?\d{1,3}(?:[,\d]{0,})\.\d{2})')
        .allMatches(text);
    return matches
        .map((match) => match.group(1) ?? '')
        .map((value) => value.replaceAll('\$', '').replaceAll(',', ''))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
  }

  double _maxDouble(double a, double b) => a > b ? a : b;

  String _guessDate(List<_OcrLine> lines) {
    final topLines =
        lines.where((line) => line.positionRatio <= 0.2).toList();
    final topResult = _scanForDate(topLines);
    if (topResult.isNotEmpty) return topResult;
    final bottomResult = _scanForDateFromBottom(lines);
    if (bottomResult.isNotEmpty) return bottomResult;
    return _scanForDate(lines);
  }

  String _scanForDateFromBottom(List<_OcrLine> lines) {
    if (lines.isEmpty) return '';
    final start = (lines.length * 0.7).floor();
    final tail = lines.sublist(start);
    return _scanForDate(tail);
  }

  String _scanForDate(List<_OcrLine> lines) {
    String? foundDate;
    String? foundTime;
    for (final line in lines) {
      final upper = line.text.toUpperCase();
      if (upper.contains('SINCE') || upper.contains('SAVINGS')) {
        continue;
      }
      final dateMatch =
          RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})').firstMatch(line.text);
      final monthNameMatch = RegExp(
        r'\b(January|February|March|April|May|June|July|August|September|Sept|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2})(?:,)?\s+(\d{2,4})\b',
        caseSensitive: false,
      ).firstMatch(line.text);
      final dayMonthNameMatch = RegExp(
        r'\b(\d{1,2})[ -/](January|February|March|April|May|June|July|August|September|Sept|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ -/](\d{2,4})\b',
        caseSensitive: false,
      ).firstMatch(line.text);
      if (foundDate == null) {
        if (dateMatch != null) {
          foundDate = dateMatch.group(1);
        } else if (monthNameMatch != null) {
          final monthName = monthNameMatch.group(1) ?? '';
          final day = monthNameMatch.group(2) ?? '';
          final year = monthNameMatch.group(3) ?? '';
          foundDate = '$monthName $day, $year';
        } else if (dayMonthNameMatch != null) {
          final day = dayMonthNameMatch.group(1) ?? '';
          final monthName = dayMonthNameMatch.group(2) ?? '';
          final year = dayMonthNameMatch.group(3) ?? '';
          foundDate = '$day-$monthName-$year';
        }
      }
      final timeMatch =
          RegExp(r'\b(\d{1,2}:\d{2}(?::\d{2})?)\b').firstMatch(line.text);
      if (timeMatch != null && foundTime == null) {
        final timeValue = timeMatch.group(1) ?? '';
        final meridiem = _extractMeridiem(line.text);
        foundTime = meridiem == null ? timeValue : '$timeValue $meridiem';
      }
      if (foundDate != null) {
        foundTime ??= _findNearbyTime(lines, line.index);
        final formatted = _formatDateTime(foundDate!, foundTime);
        if (formatted.isNotEmpty) return formatted;
      }
    }
    return foundDate == null ? '' : _formatDateTime(foundDate!, foundTime);
  }

  String? _findNearbyTime(List<_OcrLine> lines, int dateLineIndex) {
    final matches = <_OcrLine>[];
    for (final line in lines) {
      if ((line.index - dateLineIndex).abs() <= 2) {
        matches.add(line);
      }
    }
    if (matches.isEmpty && lines.isNotEmpty) {
      matches.add(lines.first);
    }
    for (final candidate in matches) {
      final timeMatch =
          RegExp(r'\b(\d{1,2}:\d{2}(?::\d{2})?)\b').firstMatch(candidate.text);
      if (timeMatch != null) {
        final timeValue = timeMatch.group(1) ?? '';
        final meridiem = _extractMeridiem(candidate.text);
        return meridiem == null ? timeValue : '$timeValue $meridiem';
      }
    }
    return null;
  }

  String _guessCategory(String merchant) {
    final value = merchant.toLowerCase();
    if (value.contains('whole foods') ||
        value.contains('market') ||
        value.contains('restaurant') ||
        value.contains('cafe')) {
      return 'Food';
    }
    if (value.contains('shell') ||
        value.contains('gas') ||
        value.contains('fuel') ||
        value.contains('uber') ||
        value.contains('lyft')) {
      return 'Transport';
    }
    if (value.contains('amazon') ||
        value.contains('store') ||
        value.contains('shop')) {
      return 'Shopping';
    }
    return 'Other';
  }

  double _estimateConfidence(String rawText) {
    final length = rawText.replaceAll(RegExp(r'\s+'), '').length;
    if (length < 30) return 0.15;
    if (length < 60) return 0.4;
    return 0.7;
  }

  bool _isMostlyNumbers(String line) {
    final digits = RegExp(r'\d').allMatches(line).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    return digits > letters * 2;
  }

  bool _isLikelyTimestamp(String line) {
    return RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?\b').hasMatch(line) ||
        RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').hasMatch(line);
  }

  bool _isLikelyUrl(String line) {
    final lower = line.toLowerCase();
    return lower.contains('http') ||
        lower.contains('www.') ||
        lower.contains('.com') ||
        lower.contains('.net') ||
        lower.contains('.org');
  }

  bool _containsDate(String line) {
    final numeric = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line);
    final monthName = RegExp(
      r'\b(January|February|March|April|May|June|July|August|September|Sept|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b',
      caseSensitive: false,
    ).hasMatch(line);
    return numeric || monthName;
  }

  bool _isLikelyAddress(String line) {
    final lower = line.toLowerCase();
    if (RegExp(r'\b\d{5}(-\d{4})?\b').hasMatch(lower)) {
      return true;
    }
    return lower.contains(' street') ||
        lower.contains(' st ') ||
        lower.contains(' avenue') ||
        lower.contains(' ave ') ||
        lower.contains(' road') ||
        lower.contains(' rd ') ||
        lower.contains(' boulevard') ||
        lower.contains(' blvd') ||
        lower.contains(' drive') ||
        lower.contains(' dr ') ||
        lower.contains(' lane') ||
        lower.contains(' ln ') ||
        lower.contains(' suite') ||
        lower.contains(' ste ');
  }

  String _pickBestMerchantLine(List<_OcrLine> lines) {
    if (lines.isEmpty) return '';
    final scored = lines.map((line) {
      final text = line.text;
      final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
      final digits = RegExp(r'\d').allMatches(text).length;
      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final upper = text.toUpperCase();
      var score = letters * 2 - digits * 2;
      score += ((1 - line.positionRatio) * 18).round();
      score += text.length >= 4 ? 6 : -8;
      if (words.length <= 2) score += 2;
      if (upper.contains('RECEIPT') ||
          upper.contains('TABLE') ||
          upper.contains('TOTAL') ||
          upper.contains('SUBTOTAL') ||
          upper.contains('VAT') ||
          upper.contains('TIP') ||
          upper.contains('SURVEY') ||
          upper.contains('FEEDBACK') ||
          upper.contains('THANK') ||
          upper.contains('APPROVAL') ||
          upper.contains('COUPON') ||
          upper.contains('CHANGE') ||
          upper.contains('CASH') ||
          upper.contains('CARD') ||
          upper.contains('ACCOUNT') ||
          upper.contains('GET MORE DONE') ||
          upper.contains('DID WE NAIL IT')) {
        score -= 10;
      }
      if (words.length >= 3) score -= 3;
      return MapEntry(text, score);
    }).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.first.key;
  }

  String _normalizeKnownMerchant(String merchant) {
    final normalized = merchant.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final known = <String, String>{
      'WALMART': 'Walmart',
      'WALMARTSUPERCENTER': 'Walmart',
      'TARGET': 'Target',
      'AMAZON': 'Amazon',
      'COSTCO': 'Costco',
      'STARBUCKS': 'Starbucks',
      'WHOLEFOODS': 'Whole Foods Market',
      'MEIJER': 'Meijer',
      'MEIJERCOM': 'Meijer',
      'MEIJERSAVINGS': 'Meijer',
      'PCMARKETOFCHOICE': 'PC Market of Choice',
    };
    for (final entry in known.entries) {
      if (_isSimilar(normalized, entry.key)) {
        return entry.value;
      }
    }
    return merchant;
  }

  bool _isSimilar(String a, String b) {
    if (a == b) return true;
    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return false;
    return (1 - distance / maxLen) >= 0.8;
  }

  int _levenshtein(String s, String t) {
    final sLen = s.length;
    final tLen = t.length;
    final dp = List.generate(sLen + 1, (_) => List.filled(tLen + 1, 0));
    for (var i = 0; i <= sLen; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= tLen; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= sLen; i++) {
      for (var j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[sLen][tLen];
  }

  String _formatDateTime(String datePart, String? timePart) {
    final numericMatch = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})')
        .firstMatch(datePart);
    int month = 0;
    int day = 0;
    int year = 0;
    if (numericMatch != null) {
      month = int.tryParse(numericMatch.group(1) ?? '') ?? 0;
      day = int.tryParse(numericMatch.group(2) ?? '') ?? 0;
      year = int.tryParse(numericMatch.group(3) ?? '') ?? 0;
    } else {
      final monthNameMatch = RegExp(
        r'\b(January|February|March|April|May|June|July|August|September|Sept|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2})(?:,)?\s+(\d{2,4})\b',
        caseSensitive: false,
      ).firstMatch(datePart);
      final dayMonthNameMatch = RegExp(
        r'\b(\d{1,2})[ -/](January|February|March|April|May|June|July|August|September|Sept|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ -/](\d{2,4})\b',
        caseSensitive: false,
      ).firstMatch(datePart);
      if (monthNameMatch != null) {
        month = _monthIndexFromName(monthNameMatch.group(1) ?? '');
        day = int.tryParse(monthNameMatch.group(2) ?? '') ?? 0;
        year = int.tryParse(monthNameMatch.group(3) ?? '') ?? 0;
      } else if (dayMonthNameMatch != null) {
        day = int.tryParse(dayMonthNameMatch.group(1) ?? '') ?? 0;
        month = _monthIndexFromName(dayMonthNameMatch.group(2) ?? '');
        year = int.tryParse(dayMonthNameMatch.group(3) ?? '') ?? 0;
      } else {
        return '';
      }
    }

    if (year < 100) {
      year = year >= 70 ? 1900 + year : 2000 + year;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return '';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (timePart == null) {
      return '${months[month - 1]} $day, $year';
    }
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?')
        .firstMatch(timePart);
    if (timeMatch == null) {
      return '${months[month - 1]} $day, $year';
    }
    var hour = int.tryParse(timeMatch.group(1) ?? '') ?? 0;
    final minute = timeMatch.group(2) ?? '00';
    final meridiem = _extractMeridiem(timePart);
    final isPm = meridiem == null ? hour >= 12 : meridiem == 'PM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final suffix = isPm ? 'PM' : 'AM';
    return '${months[month - 1]} $day, $year • $hour:$minute $suffix';
  }

  String? _extractMeridiem(String text) {
    final match =
        RegExp(r'\b(AM|PM)\b', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    return match.group(1)?.toUpperCase();
  }

  String? _findKnownMerchant(List<_OcrLine> lines) {
    for (final line in lines) {
      final normalized = _normalizeKnownMerchant(_normalizeMerchant(line.text));
      if (normalized.toLowerCase() != line.text.toLowerCase()) {
        return normalized;
      }
    }
    return null;
  }

  String? _merchantFromDomain(List<_OcrLine> lines) {
    for (final line in lines) {
      final lower = line.text.toLowerCase();
      final match = RegExp(r'([a-z0-9-]+)\.com').firstMatch(lower);
      if (match == null) continue;
      final domain = match.group(1) ?? '';
      if (domain.isEmpty) continue;
      if (domain.contains('walmart')) return 'Walmart';
      if (domain.contains('target')) return 'Target';
      if (domain.contains('homedepot')) return 'Home Depot';
      if (domain.contains('costco')) return 'Costco';
      if (domain.contains('meijer')) return 'Meijer';
      final cleaned = domain.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
      final words = cleaned
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .toList();
      if (words.isEmpty) return null;
      return words.join(' ');
    }
    return null;
  }

  int _monthIndexFromName(String name) {
    final upper = name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final short = upper.length >= 3 ? upper.substring(0, 3) : upper;
    const map = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'SEPT': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };
    return map[short] ?? map[upper] ?? 0;
  }

  double? _pickLargestAmount(List<_AmountCandidate> candidates) {
    if (candidates.isEmpty) return null;
    var best = candidates.first.value;
    for (final candidate in candidates.skip(1)) {
      if (candidate.value > best) {
        best = candidate.value;
      }
    }
    return best;
  }
}

class ReceiptImageViewer extends StatelessWidget {
  final String imagePath;

  const ReceiptImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Center(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}
