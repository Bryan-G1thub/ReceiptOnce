import 'dart:async';

import 'package:flutter/material.dart';

void main() {
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receiptItems = [
      _ReceiptItem(
        merchant: 'Whole Foods Market',
        date: 'Jan 17, 2026',
        amount: '\$87.43',
        category: 'Food',
        categoryColor: const Color(0xFF46A047),
        icon: Icons.store_outlined,
        gradient: const [Color(0xFFF1E7D0), Color(0xFFC9B79A)],
      ),
      _ReceiptItem(
        merchant: 'Shell Gas Station',
        date: 'Jan 16, 2026',
        amount: '\$52.10',
        category: 'Transport',
        categoryColor: const Color(0xFF2D86F0),
        icon: Icons.local_gas_station_outlined,
        gradient: const [Color(0xFFE8D7C5), Color(0xFFB59374)],
      ),
      _ReceiptItem(
        merchant: 'Amazon',
        date: 'Jan 14, 2026',
        amount: '\$124.99',
        category: 'Shopping',
        categoryColor: const Color(0xFF8B2BBE),
        icon: Icons.shopping_bag_outlined,
        gradient: const [Color(0xFFE7E3F5), Color(0xFFC0B6DE)],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Container(
              height: 180,
              color: _headerGreen,
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ReceiptOnce',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SummaryCard(),
                  const SizedBox(height: 20),
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
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReceiptsHubPage(),
                            ),
                          );
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
                  ...receiptItems.map((item) => _ReceiptListItem(item: item)),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReceiptsHubPage(),
                        ),
                      );
                    },
                  ),
                  const _NavItem(
                    icon: Icons.menu,
                    label: 'Menu',
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CameraCapturePage(),
                    ),
                  );
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
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
          const Text(
            '\$264.52',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _MetricTile(
                  icon: Icons.receipt_long,
                  label: 'Receipts',
                  value: '3',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.trending_up,
                  label: 'Top',
                  value: 'Food',
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
                Row(
                  children: [
                    Text(
                      item.date,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _mutedText,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF45A146),
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptsHubPage extends StatelessWidget {
  const ReceiptsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkText,
        elevation: 0,
        title: const Text(
          'Receipts',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ManualEntryPage(),
            ),
          );
        },
        backgroundColor: _headerGreen,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text(
          'Enter manually',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const Center(
        child: Text(
          'Receipts hub',
          style: TextStyle(
            color: _mutedText,
            fontSize: 16,
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
  final MockOcrService _ocrService = MockOcrService();
  Timer? _slowTimer;
  bool _isProcessing = false;
  bool _showSlowNotice = false;
  bool _cameraReady = false;

  @override
  void dispose() {
    _slowTimer?.cancel();
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scan receipts automatically'),
          content: const Text(
            "Next, we'll open your camera so you can snap the receipt.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
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
    setState(() {
      _cameraReady = true;
    });
  }

  Future<bool> _requestCameraPermission() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return true;
  }

  Future<void> _handleUsePhoto() async {
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

    final result = await _ocrService.readReceipt();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan receipt'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      _cameraReady
                          ? 'Camera preview'
                          : 'Opening camera...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cameraReady ? _handleUsePhoto : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _headerGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Use this photo',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const ManualEntryPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Enter manually',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return Scaffold(
      backgroundColor: _lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkText,
        elevation: 0,
        title: const Text(
          'Review receipt',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Receipt photo',
                  style: TextStyle(color: _mutedText),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InputField(
              label: 'Merchant',
              controller: _merchantController,
            ),
            const SizedBox(height: 12),
            _InputField(
              label: 'Total',
              controller: _totalController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _InputField(
              label: 'Date',
              controller: _dateController,
            ),
            const SizedBox(height: 12),
            _InputField(
              label: 'Category',
              controller: _categoryController,
            ),
            if (confidence < 0.2) ...[
              const SizedBox(height: 16),
              SizedBox(
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
            ],
          ],
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: _lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkText,
        elevation: 0,
        title: const Text(
          'Enter receipt',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Open settings'),
                          ),
                        );
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
            ),
            const SizedBox(height: 12),
            _InputField(
              label: 'Total',
              controller: _totalController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _InputField(
              label: 'Date',
              controller: _dateController,
            ),
            const SizedBox(height: 12),
            _InputField(
              label: 'Category',
              controller: _categoryController,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _headerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save receipt',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
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
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class ReceiptDraft {
  final String merchant;
  final String total;
  final String date;
  final String category;
  final String rawText;
  final double confidence;

  const ReceiptDraft({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
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
        confidence: result.confidence,
      );
    }
    return ReceiptDraft(
      merchant: result.merchant,
      total: result.total,
      date: result.date,
      category: result.category,
      rawText: result.rawText,
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
  final double confidence;

  const OcrResult({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
    required this.confidence,
  });
}

class MockOcrService {
  Future<OcrResult> readReceipt() async {
    await Future.delayed(const Duration(seconds: 2));
    return const OcrResult(
      merchant: 'Whole Foods Market',
      total: '\$87.43',
      date: 'Jan 17, 2026',
      category: 'Food',
      rawText: 'TOTAL 87.43\nWHOLE FOODS MARKET\nJan 17 2026',
      confidence: 0.45,
    );
  }
}
