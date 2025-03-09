import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../models/vn_bank_qr.dart';
import '../../services/qr_service.dart';
import '../../services/permission_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  final List<String> _productIds = [
    'premium_monthly',
    'premium_yearly',
    'premium_lifetime',
  ];

  bool _isAvailable = false;
  bool _isPurchasing = false;
  bool _isLoading = true;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Bank donation variables
  final TextEditingController _donationAmountController =
      TextEditingController();
  final String _bankName = "Timo";
  final String _accountNumber = "0947890450";
  final String _accountName = "NGUYEN QUANG TRUONG";
  double _donationAmount = 50000;
  bool _showQrCode = false;
  bool _isLoadingQR = false;
  String? _qrImageUrl;
  String? _bankId;

  // Add debounce timer
  Timer? _debounceTimer;

  // Add a flag to track download status
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _donationAmountController.text = _donationAmount.toStringAsFixed(0);
    _initIAP();
    _initBankId();

    // Auto generate QR when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateQRCode());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _donationAmountController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initIAP() async {
    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        await _getProducts();
        _subscription = _iap.purchaseStream.listen(_listenToPurchaseUpdated);
      }
    } catch (e) {
      debugPrint('Error initializing IAP: $e');
      _isAvailable = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getProducts() async {
    try {
      final response = await _iap.queryProductDetails(_productIds.toSet());
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Missing products: ${response.notFoundIDs}');
      }

      if (mounted) {
        setState(() {
          _products =
              response.productDetails..sort(
                (a, b) => _extractPrice(
                  a.rawPrice,
                ).compareTo(_extractPrice(b.rawPrice)),
              );
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
  }

  double _extractPrice(dynamic rawPrice) {
    if (rawPrice is double) return rawPrice;
    if (rawPrice is int) return rawPrice.toDouble();
    return 0.0;
  }

  void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() => _isPurchasing = true);
      } else {
        setState(() => _isPurchasing = false);
        if (purchaseDetails.status == PurchaseStatus.error) {
          _handlePurchaseError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyPurchase(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.activatePremium(
        purchaseDetails.productID,
        purchaseDetails.purchaseID ?? 'unknown',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify purchase: $e')),
        );
      }
    }
  }

  void _handlePurchaseError(IAPError error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: ${error.message}')),
      );
    }
  }

  Future<void> _buyProduct(ProductDetails product) async {
    if (_isPurchasing) return;

    try {
      setState(() => _isPurchasing = true);
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  Future<void> _initBankId() async {
    // Try to get bankId from API, or use fallback
    _bankId = await QRService.getBankIdFromName(_bankName);
    if (_bankId == null) {
      _bankId = QRService.getFallbackBankId(_bankName);
    }
  }

  Future<void> _generateQRCode() async {
    setState(() {
      _isLoadingQR = true;
      _showQrCode = true;
    });

    try {
      // Ensure bank ID is initialized
      if (_bankId == null) {
        await _initBankId();
      }

      // Generate QR code URL
      _qrImageUrl = QRService.generateVietQRUrl(
        bankId: _bankId!,
        accountNumber: _accountNumber,
        accountName: _accountName,
        amount: _donationAmount,
        message: 'Donate NotesApp',
      );
    } catch (e) {
      debugPrint('Error generating QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating QR code: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQR = false;
        });
      }
    }
  }

  // Function to download QR image to gallery
  Future<void> _downloadQRImage() async {
    if (_qrImageUrl == null) return;

    try {
      setState(() {
        _isDownloading = true;
      });

      // Sử dụng service mới để xin quyền
      final hasPermission = await PermissionService.requestPhotosPermission(
        context,
      );
      if (!hasPermission) {
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // Tải ảnh từ URL
      final response = await Dio().get(
        _qrImageUrl!,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data);

      // Lưu ảnh vào thư mục tạm
      final tempDir = await getTemporaryDirectory();
      final fileName =
          "QR_${_bankName}_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Lưu ảnh vào thư viện
      if (Platform.isAndroid) {
        // Android implementation
        final result = await _saveImageToGallery(file.path);
        if (result) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã lưu mã QR vào thư viện ảnh'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else if (Platform.isIOS) {
        // iOS implementation
        final result = await _saveImageToGallery(file.path);
        if (result) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã lưu mã QR vào thư viện ảnh'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }

      // Xóa file tạm
      await file.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu mã QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  // Platform channel method để lưu ảnh
  Future<bool> _saveImageToGallery(String filePath) async {
    try {
      // Gọi method channel để thêm vào gallery
      final methodChannel = MethodChannel('app_note/gallery_saver');
      final bool? result = await methodChannel.invokeMethod(
        'saveImageToGallery',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (e) {
      // Fallback khi method channel không hoạt động: mở chia sẻ để lưu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể lưu trực tiếp. Hãy sử dụng tính năng chia sẻ để lưu ảnh',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isPremium = authProvider.isPremium;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Premium Features'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Upgrade'), Tab(text: 'Donate')],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSubscriptionContent(context, isPremium),
            _buildDonationContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionContent(BuildContext context, bool isPremium) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return isPremium
        ? _buildPremiumContent(context)
        : _buildUpgradeContent(context);
  }

  Widget _buildPremiumContent(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPremiumHeader(),
          const SizedBox(height: 24),
          _buildPremiumFeatures(),
          const SizedBox(height: 24),
          _buildRestoreButton(),
        ],
      ),
    );
  }

  Widget _buildUpgradeContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUpgradeHeader(),
          const SizedBox(height: 24),
          ..._products.map((product) => _buildProductCard(product)),
          const SizedBox(height: 32),
          _buildRestoreButton(),
          _buildSubscriptionTerms(),
        ],
      ),
    );
  }

  Widget _buildDonationContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDonationHeader(),
          _buildAmountSelector(),
          _buildCustomAmountField(),
          // QR code will automatically be shown below
          _buildQrDisplay(),
        ],
      ),
    );
  }

  // IMPLEMENTATION OF MISSING METHODS

  Widget _buildPremiumHeader() {
    final authProvider = Provider.of<AuthProvider>(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.deepPurple.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.star, size: 72, color: Colors.yellow),
          const SizedBox(height: 16),
          const Text(
            'You\'re Premium!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Subscription: ${authProvider.premiumType ?? 'Active'}',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          if (authProvider.premiumExpiryDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires: ${DateFormat('MMM d, yyyy').format(authProvider.premiumExpiryDate!)}',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premium Benefits',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _premiumFeatureCard(
          icon: Icons.format_paint,
          title: 'Advanced Formatting',
          description: 'Access to rich text formatting options for your notes.',
        ),
        _premiumFeatureCard(
          icon: Icons.cloud_upload,
          title: 'Unlimited Cloud Storage',
          description: 'Never worry about storage limits for your notes.',
        ),
        _premiumFeatureCard(
          icon: Icons.folder_special,
          title: 'Categories & Tags',
          description: 'Organize your notes with custom categories and tags.',
        ),
        _premiumFeatureCard(
          icon: Icons.lock,
          title: 'Password Protected Notes',
          description: 'Add extra security to your sensitive notes.',
        ),
        _premiumFeatureCard(
          icon: Icons.devices,
          title: 'Sync Across Devices',
          description: 'Access your notes from any device seamlessly.',
        ),
      ],
    );
  }

  Widget _premiumFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: Colors.purple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return ElevatedButton(
      onPressed: _restorePurchases,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      child: const Text('Restore Purchases'),
    );
  }

  Widget _buildUpgradeHeader() {
    return Column(
      children: [
        const Text(
          'Upgrade to Premium',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock all premium features',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    bool isYearly = product.id.contains('yearly');
    bool isLifetime = product.id.contains('lifetime');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _buyProduct(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (isYearly)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                isLifetime
                    ? 'Lifetime'
                    : isYearly
                    ? 'Yearly'
                    : 'Monthly',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.price,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isLifetime)
                    Text(
                      isYearly ? '/year' : '/month',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (isYearly)
                Text(
                  'Save 33% compared to monthly',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _buyProduct(product),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: isYearly ? Colors.purple : null,
                  foregroundColor: isYearly ? Colors.white : null,
                ),
                child:
                    _isPurchasing
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(isLifetime ? 'Buy Now' : 'Subscribe'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionTerms() {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: Text(
        'Subscriptions will automatically renew unless canceled at least 24 hours before the end of the current period. You can cancel anytime in your app store settings.',
        style: TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDonationHeader() {
    return Column(
      children: [
        const Text(
          'Support Development',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'If you enjoy using this app, please consider supporting its continued development with a donation.',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAmountSelector() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Donation Amount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40, // Fixed height for the scrollable row
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _amountButton('10K', 10000),
                    const SizedBox(width: 8),
                    _amountButton('20K', 20000),
                    const SizedBox(width: 8),
                    _amountButton('50K', 50000),
                    const SizedBox(width: 8),
                    _amountButton('100K', 100000),
                    const SizedBox(width: 8),
                    _amountButton('200K', 200000),
                    const SizedBox(width: 8),
                    _amountButton('500K', 500000),
                    const SizedBox(width: 8),
                    _amountButton('1000K', 1000000),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountButton(String label, double amount) {
    final isSelected = _donationAmount == amount;

    return GestureDetector(
      onTap: () {
        setState(() {
          _donationAmount = amount;
          _donationAmountController.text = amount.toStringAsFixed(0);
        });

        // Generate QR code when a preset amount is selected
        _generateQRCode();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountField() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Amount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _donationAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter amount (VND)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.monetization_on),
                suffixText: 'VND',
              ),
              onChanged: (value) {
                try {
                  setState(() {
                    _donationAmount = double.parse(value);
                  });

                  // Debounce the QR generation to avoid excessive API calls
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                    if (mounted) {
                      _generateQRCode();
                    }
                  });
                } catch (_) {
                  // Handle parsing error
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Replace the QR Generator button with a status indicator
  Widget _buildQrGenerator() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'QR Code Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                if (_isLoadingQR)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isLoadingQR
                  ? 'Generating QR code...'
                  : 'QR code ready for scanning',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrDisplay() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Bank Transfer QR Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // QR Code - moved above bank details
            if (_isLoadingQR)
              const CircularProgressIndicator()
            else if (_qrImageUrl != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _qrImageUrl!,
                      height: 250,
                      width: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 250,
                          width: 250,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text(
                              'Error loading QR code',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Copy QR URL button
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _qrImageUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('QR URL copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy URL'),
                      ),
                      // Download QR image button
                      TextButton.icon(
                        onPressed: _isDownloading ? null : _downloadQRImage,
                        icon:
                            _isDownloading
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.download, size: 16),
                        label: Text(
                          _isDownloading ? 'Saving...' : 'Save to Gallery',
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              // Fallback to QR Flutter if URL generation failed
              QrImageView(
                data:
                    VNBankQR(
                      bankName: _bankName,
                      accountNumber: _accountNumber,
                      accountName: _accountName,
                      amount: _donationAmount,
                      message: "Donate NotesApp",
                    ).generateVietQR(),
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                errorStateBuilder:
                    (context, error) => Text(
                      'Error generating QR code: ${error.toString()}',
                      style: const TextStyle(color: Colors.red),
                    ),
              ),
            const SizedBox(height: 16),
            // const Text(
            //   'Scan this QR code with your banking app to complete the transfer',
            //   textAlign: TextAlign.center,
            //   style: TextStyle(fontStyle: FontStyle.italic),
            // ),
            // const SizedBox(height: 24),
            // Bank details text - moved below QR code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _bankDetailRow('Bank Name', _bankName),
                  _bankDetailRow('Account Number', _accountNumber),
                  _bankDetailRow('Account Name', _accountName),
                  _bankDetailRow(
                    'Amount',
                    '${NumberFormat("#,###").format(_donationAmount)} VND',
                  ),
                  _bankDetailRow('Message', 'Donate NotesApp'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Thank you message
            const Column(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 48),
                SizedBox(height: 8),
                Text(
                  'Thank You For Your Support!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Your donation helps us continue developing new features and improvements.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with fixed width
          SizedBox(
            width: 120, // Fixed width for labels
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Value with flexible width
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text that can wrap or use ellipsis
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Copy button (not flexible, fixed size)
                if (value.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
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
