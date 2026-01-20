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

const Color _headerGreen = Color(0xFF2F5B36);
const Color _lightBackground = Color(0xFFF4F5F7);
const Color _darkText = Color(0xFF232323);
const Color _mutedText = Color(0xFF7B7B7B);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final receiptItems = [
      _ReceiptItem(
        merchant: 'Whole Foods Market',
        date: 'Jan 17, 2026',
        amount: '\$87.43',
        category: 'Food',
        categoryColor: const Color(0xFF46A047),
        icon: Icons.store,
        gradient: const [Color(0xFFF1E7D0), Color(0xFFC9B79A)],
      ),
      _ReceiptItem(
        merchant: 'Shell Gas Station',
        date: 'Jan 16, 2026',
        amount: '\$52.10',
        category: 'Transport',
        categoryColor: const Color(0xFF2D86F0),
        icon: Icons.local_gas_station,
        gradient: const [Color(0xFFE8D7C5), Color(0xFFB59374)],
      ),
      _ReceiptItem(
        merchant: 'Amazon',
        date: 'Jan 14, 2026',
        amount: '\$124.99',
        category: 'Shopping',
        categoryColor: const Color(0xFF8B2BBE),
        icon: Icons.shopping_bag,
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
                  const _SearchBar(),
                  const SizedBox(height: 20),
                  const Text(
                    'Recent Receipts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
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
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _NavItem(
                    icon: Icons.home_filled,
                    label: 'Home',
                    active: true,
                  ),
                  _NavItem(
                    icon: Icons.search,
                    label: 'Search',
                  ),
                  SizedBox(width: 56),
                  _NavItem(
                    icon: Icons.share_outlined,
                    label: 'Share',
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                  ),
                ],
              ),
              Container(
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
        color: Colors.white,
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
              color: _mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '\$264.52',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: _darkText,
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
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: _mutedText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _darkText,
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
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const TextField(
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

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _headerGreen : _mutedText;
    return Column(
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: item.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(item.icon, color: _darkText),
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
