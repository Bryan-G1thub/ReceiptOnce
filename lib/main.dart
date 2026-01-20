import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
                    children: const [
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
                      _SummaryCard(),
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
          Flexible(
            child: Text(
              item.amount,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF45A146),
              ),
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
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  XFile? _selectedImage;
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
    if (_selectedImage == null) return;
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
      final result = await _ocrService.readReceipt(_selectedImage!.path);
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
        _selectedImage = file;
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
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (file == null) return;
    setState(() {
      _selectedImage = file;
    });
  }

  Widget _buildPreview() {
    if (_selectedImage != null) {
      return Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.cover,
      );
    }
    if (_cameraController?.value.isInitialized ?? false) {
      final controller = _cameraController!;
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan receipt'),
        actions: [
          IconButton(
            tooltip: 'Tips',
            onPressed: _showTipsDialog,
            icon: const Icon(Icons.help_outline),
          ),
        ],
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _buildPreview(),
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
                        onPressed: _selectedImage == null
                            ? (_cameraReady ? _handleCapture : null)
                            : _handleUsePhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _headerGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _selectedImage == null
                              ? 'Capture receipt'
                              : 'Use this photo',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _selectedImage == null
                            ? _handleImportPhoto
                            : () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _selectedImage == null ? 'Import photo' : 'Retake',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_selectedImage == null)
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
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _handleImportPhoto,
                            child: const Text(
                              'Import another',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: widget.draft.imagePath.isNotEmpty
                    ? Image.file(
                        File(widget.draft.imagePath),
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Text(
                          'Receipt photo',
                          style: TextStyle(color: _mutedText),
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

class ReceiptDraft {
  final String merchant;
  final String total;
  final String date;
  final String category;
  final String rawText;
  final String imagePath;
  final double confidence;

  const ReceiptDraft({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
    required this.imagePath,
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
  final double confidence;

  const OcrResult({
    required this.merchant,
    required this.total,
    required this.date,
    required this.category,
    required this.rawText,
    required this.imagePath,
    required this.confidence,
  });
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  Future<OcrResult> readReceipt(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    final rawText = recognizedText.text;
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
      confidence: confidence,
    );
  }

  String _guessMerchant(List<String> lines) {
    for (final line in lines.take(6)) {
      final upper = line.toUpperCase();
      if (upper.contains('TOTAL') ||
          upper.contains('BALANCE') ||
          upper.contains('SUBTOTAL')) {
        continue;
      }
      if (RegExp(r'[A-Za-z]').hasMatch(line)) {
        return _normalizeMerchant(line);
      }
    }
    return lines.isNotEmpty ? _normalizeMerchant(lines.first) : '';
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
    final monthPattern =
        RegExp(r'(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)');
    for (final line in lines) {
      if (monthPattern.hasMatch(line.toUpperCase())) {
        return line;
      }
      final match = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').firstMatch(line);
      if (match != null) {
        return match.group(0) ?? '';
      }
    }
    return '';
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
}
