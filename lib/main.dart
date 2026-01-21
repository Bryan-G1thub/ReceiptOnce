import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

const Color _headerGreen = Color(0xFF1F8A5B);
const Color _lightBackground = Color(0xFFF4F5F7);
const Color _darkText = Color(0xFF232323);
const Color _mutedText = Color(0xFF7B7B7B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadHomeData();
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
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReceiptsHubPage(),
                            ),
                          );
                          await _loadHomeData();
                          _searchFocus.unfocus();
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
                      ..._recentReceipts
                          .map((item) => _ReceiptDataListItem(receipt: item)),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
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
                    const _NavItem(
                      icon: Icons.home_filled,
                      label: 'Home',
                      active: true,
                    ),
                    _NavItem(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: () {
                        FocusScope.of(context).requestFocus(_searchFocus);
                      },
                    ),
                    const SizedBox(width: 56),
                    _NavItem(
                      icon: Icons.receipt_long,
                      label: 'Receipts',
                      onTap: () async {
                        FocusScope.of(context).unfocus();
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReceiptsHubPage(),
                          ),
                        );
                        await _loadHomeData();
                        _searchFocus.unfocus();
                      },
                    ),
                    const _NavItem(
                      icon: Icons.menu,
                      label: 'Menu',
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CameraCapturePage(),
                      ),
                    );
                    await _loadHomeData();
                    _searchFocus.unfocus();
                  },
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
          hintText: 'Search by merchant, category, or date',
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

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;

  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final dateText = _receiptDateLabel(receipt);
    final amountText = _formatCents(receipt.totalCents);
    final hasImage =
        receipt.imagePath.isNotEmpty && File(receipt.imagePath).existsSync();

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
      child: Row(
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
                  receipt.merchant.isEmpty ? 'Untitled receipt' : receipt.merchant,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            width: 96,
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
  const ReceiptsHubPage({super.key});

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
  List<Receipt> _receipts = [];
  List<Receipt> _visibleReceipts = [];
  bool _loading = true;
  bool _isPro = false;
  int _scansLeft = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _loading = true;
    });
    final receipts = await _database.fetchReceipts();
    final isPro = await _database.isPro();
    final scanCount = await _database.getScanCount();
    if (!mounted) return;
    setState(() {
      _receipts = receipts;
      _visibleReceipts = _filterReceipts(receipts);
      _loading = false;
      _isPro = isPro;
      _scansLeft = (10 - scanCount).clamp(0, 10);
    });
  }

  void _applyFilters() {
    setState(() {
      _visibleReceipts = _filterReceipts(_receipts);
    });
  }

  List<Receipt> _filterReceipts(List<Receipt> receipts) {
    final query = _searchController.text.trim().toLowerCase();
    var results = receipts.where((receipt) {
      if (_activeCategory != 'All' && receipt.category != _activeCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return receipt.merchant.toLowerCase().contains(query) ||
          receipt.category.toLowerCase().contains(query) ||
          receipt.purchaseDate.toLowerCase().contains(query);
    }).toList();
    results.sort(_sortComparator);
    return results;
  }

  int _sortComparator(Receipt a, Receipt b) {
    switch (_activeSort) {
      case 'Oldest':
        return _createdAtValue(a).compareTo(_createdAtValue(b));
      case 'Amount high to low':
        return _amountValue(b).compareTo(_amountValue(a));
      case 'Amount low to high':
        return _amountValue(a).compareTo(_amountValue(b));
      case 'Newest':
      default:
        return _createdAtValue(b).compareTo(_createdAtValue(a));
    }
  }

  DateTime _createdAtValue(Receipt receipt) {
    return DateTime.tryParse(receipt.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _amountValue(Receipt receipt) {
    return receipt.totalCents ?? -1;
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
                    onBack: () => Navigator.of(context).pop(),
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
                              _visibleReceipts = _filterReceipts(_receipts);
                            });
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
                              _visibleReceipts = _filterReceipts(_receipts);
                            });
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
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReceiptCard(receipt: _visibleReceipts[index]),
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
    if (_receipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipts to export yet.')),
      );
      return;
    }
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        'Merchant,Total,Purchase Date,Category,Created At',
      );
      for (final receipt in _receipts) {
        buffer.writeln(
          [
            _csvValue(receipt.merchant),
            _csvValue(_formatCents(receipt.totalCents)),
            _csvValue(receipt.purchaseDate),
            _csvValue(receipt.category),
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

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool _processing = false;

  Future<void> _unlockPro() async {
    if (_processing) return;
    setState(() {
      _processing = true;
    });
    await ReceiptDatabase.instance.setPro(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ReceiptOnce Pro unlocked.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(
                title: 'ReceiptOnce Pro',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Unlock unlimited scans',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _darkText,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Keep every receipt in one place and export whenever tax season arrives.',
                      style: TextStyle(color: _mutedText),
                    ),
                    SizedBox(height: 16),
                    _PaywallFeatureRow(
                      icon: Icons.all_inclusive,
                      text: 'Unlimited receipt scans',
                    ),
                    SizedBox(height: 10),
                    _PaywallFeatureRow(
                      icon: Icons.cloud_download_outlined,
                      text: 'Export CSV anytime',
                    ),
                    SizedBox(height: 10),
                    _PaywallFeatureRow(
                      icon: Icons.analytics_outlined,
                      text: 'Full summaries and insights',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _unlockPro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Unlock lifetime access',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'One-time purchase • No subscriptions',
                  style: TextStyle(color: _mutedText),
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
  late final TextEditingController _categoryController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.draft.merchant);
    _totalController = TextEditingController(text: widget.draft.total);
    _dateController = TextEditingController(text: widget.draft.date);
    _categoryController = TextEditingController(text: widget.draft.category);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
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
                _InputField(
                  label: 'Purchase date/time',
                  controller: _dateController,
                  icon: Icons.event,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Category',
                  controller: _categoryController,
                  icon: Icons.sell_outlined,
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
      final purchaseDate = _dateController.text.trim();
      final categoryText = _categoryController.text.trim();
      final category = categoryText.isEmpty ? 'Other' : categoryText;
      final totalCents = _parseTotalCents(totalText);
      final receipt = Receipt(
        merchant: merchant,
        totalCents: totalCents,
        purchaseDate: purchaseDate,
        category: category,
        imagePath: widget.draft.imagePath,
        rawText: widget.draft.rawText,
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
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ReceiptsHubPage()),
        (route) => route.isFirst,
      );
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
  final TextEditingController _categoryController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
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
                _InputField(
                  label: 'Purchase date/time',
                  controller: _dateController,
                  icon: Icons.event,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Category',
                  controller: _categoryController,
                  icon: Icons.sell_outlined,
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
      final purchaseDate = _dateController.text.trim();
      final categoryText = _categoryController.text.trim();
      final category = categoryText.isEmpty ? 'Other' : categoryText;
      final totalCents = _parseTotalCents(totalText);
      final receipt = Receipt(
        merchant: merchant,
        totalCents: totalCents,
        purchaseDate: purchaseDate,
        category: category,
        imagePath: '',
        rawText: '',
        createdAt: DateTime.now().toIso8601String(),
      );
      await ReceiptDatabase.instance.insertReceipt(receipt);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ReceiptsHubPage()),
        (route) => route.isFirst,
      );
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
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final IconData? icon;

  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.icon,
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
                    color: const Color(0xFF9A9A9A),
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
  final VoidCallback onBack;
  final Widget? trailing;

  const _PageHeader({
    required this.title,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(
          icon: Icons.arrow_back,
          onTap: onBack,
        ),
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
    final merchant = _guessMerchant(lines);
    final total = _guessTotal(lines);
    final date = _guessDate(lines);
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

  String _guessMerchant(List<String> lines) {
    final cleanedLines = lines.where((line) {
      if (_isLikelyTimestamp(line)) return false;
      if (_isMostlyNumbers(line)) return false;
      if (_isLikelyUrl(line)) return false;
      final upper = line.toUpperCase();
      if (upper.contains('TOTAL') ||
          upper.contains('BALANCE') ||
          upper.contains('SUBTOTAL')) {
        return false;
      }
      return RegExp(r'[A-Za-z]').hasMatch(line);
    }).toList();
    if (cleanedLines.isEmpty) {
      return lines.isNotEmpty ? _normalizeMerchant(lines.first) : '';
    }
    final candidate = _pickBestMerchant(cleanedLines);
    return _normalizeKnownMerchant(candidate);
  }

  String _normalizeMerchant(String value) {
    return value.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String _guessTotal(List<String> lines) {
    const keywords = [
      'TOTAL',
      'BALANCE DUE',
      'AMOUNT DUE',
      'GRAND TOTAL',
      'TOTAL DUE',
    ];
    double? bestMatch;
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (keywords.any((keyword) => upper.contains(keyword))) {
        final amounts = _extractAmounts(line);
        if (amounts.isNotEmpty) {
          final candidate = amounts.reduce(_maxDouble);
          bestMatch = bestMatch == null ? candidate : _maxDouble(bestMatch, candidate);
        }
      }
    }
    bestMatch ??= _extractAmounts(lines.join(' ')).fold<double?>(
      null,
      (current, value) => current == null ? value : _maxDouble(current, value),
    );
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

  String _guessDate(List<String> lines) {
    String? foundDate;
    String? foundTime;
    for (final line in lines) {
      final dateMatch = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})')
          .firstMatch(line);
      if (dateMatch != null && foundDate == null) {
        foundDate = dateMatch.group(1);
      }
      final timeMatch =
          RegExp(r'\b(\d{1,2}:\d{2}(?::\d{2})?)\b').firstMatch(line);
      if (timeMatch != null && foundTime == null) {
        foundTime = timeMatch.group(1);
      }
      if (foundDate != null) {
        final formatted = _formatDateTime(foundDate!, foundTime);
        if (formatted.isNotEmpty) return formatted;
      }
    }
    return foundDate == null ? '' : _formatDateTime(foundDate!, foundTime);
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

  String _pickBestMerchant(List<String> lines) {
    if (lines.isEmpty) return '';
    final scored = lines.map((line) {
      final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
      final digits = RegExp(r'\d').allMatches(line).length;
      final score = letters - digits;
      return MapEntry(line, score);
    }).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    return _normalizeMerchant(scored.first.key);
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
    final dateMatch = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})')
        .firstMatch(datePart);
    if (dateMatch == null) return '';
    final month = int.tryParse(dateMatch.group(1) ?? '') ?? 0;
    final day = int.tryParse(dateMatch.group(2) ?? '') ?? 0;
    var year = int.tryParse(dateMatch.group(3) ?? '') ?? 0;
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
    final isPm = hour >= 12;
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final suffix = isPm ? 'PM' : 'AM';
    return '${months[month - 1]} $day, $year • $hour:$minute $suffix';
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
