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

  // Bổ sung biến để kiểm soát hiển thị
  bool _hasSelectedAmount = false;

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
      _hasSelectedAmount = true;
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUpgradeHeader(),
          const SizedBox(height: 32),
          _buildPremiumFeaturesSection(),
          const SizedBox(height: 32),
          ..._products.map((product) => _buildProductCard(product)),
          const SizedBox(height: 32),
          _buildRestoreButton(),
          const SizedBox(height: 16),
          _buildSubscriptionTerms(),
        ],
      ),
    );
  }

  Widget _buildDonationContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDonationHeader(),
          const SizedBox(height: 24),
          // Chỉ hiển thị phần lựa chọn số tiền khi chưa chọn
          if (!_hasSelectedAmount) ...[
            _buildAmountSelector(),
            const SizedBox(height: 16),
            _buildCustomAmountField(),
          ],
          // Luôn hiển thị thông tin ngân hàng và mã QR
          if (_hasSelectedAmount) ...[
            _buildBankInfoSection(),
            const SizedBox(height: 16),
            _buildQrDisplay(),
          ],
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.deepPurple.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [Colors.amber, Colors.yellowAccent],
              ).createShader(bounds);
            },
            child: const Icon(
              Icons.workspace_premium,
              size: 70,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nâng cấp lên Premium',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Mở khóa toàn bộ tính năng cao cấp',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeaturesSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lợi ích Premium',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            _premiumFeatureItem(
              icon: Icons.format_paint,
              title: 'Định dạng nâng cao',
              description: 'Truy cập các tùy chọn định dạng văn bản phong phú.',
            ),
            _premiumFeatureItem(
              icon: Icons.cloud_upload,
              title: 'Lưu trữ đám mây không giới hạn',
              description: 'Không bao giờ lo lắng về giới hạn lưu trữ ghi chú.',
            ),
            _premiumFeatureItem(
              icon: Icons.folder_special,
              title: 'Danh mục & Thẻ',
              description: 'Sắp xếp ghi chú với danh mục và thẻ tùy chỉnh.',
            ),
            _premiumFeatureItem(
              icon: Icons.lock,
              title: 'Ghi chú bảo vệ bằng mật khẩu',
              description: 'Thêm lớp bảo mật cho các ghi chú nhạy cảm.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: Colors.deepPurple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    bool isYearly = product.id.contains('yearly');
    bool isLifetime = product.id.contains('lifetime');
    bool isMonthly = product.id.contains('monthly');

    Color cardColor =
        isYearly
            ? Colors.purple.shade50
            : isLifetime
            ? Colors.amber.shade50
            : Colors.white;

    Color borderColor =
        isYearly
            ? Colors.purple
            : isLifetime
            ? Colors.amber.shade700
            : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isYearly ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _buyProduct(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tiêu đề gói
                  Icon(
                    isLifetime
                        ? Icons.stars
                        : isYearly
                        ? Icons.calendar_today
                        : Icons.today,
                    color:
                        isLifetime
                            ? Colors.amber.shade700
                            : isYearly
                            ? Colors.purple
                            : Colors.blue,
                    size: 28,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isLifetime
                            ? 'Trọn đời'
                            : isYearly
                            ? 'Hàng năm'
                            : 'Hàng tháng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isLifetime
                                  ? Colors.amber.shade800
                                  : isYearly
                                  ? Colors.purple
                                  : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  // Badge tốt nhất
                  if (isYearly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'TỐT NHẤT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Giá
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.price,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color:
                          isLifetime
                              ? Colors.amber.shade800
                              : isYearly
                              ? Colors.purple
                              : Colors.blue,
                    ),
                  ),
                  if (!isLifetime)
                    Text(
                      isYearly ? '/năm' : '/tháng',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Thông tin tiết kiệm
              if (isYearly)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tiết kiệm 33% so với gói hàng tháng',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isLifetime)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Thanh toán một lần, sử dụng mãi mãi',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Nút đăng ký/mua
              ElevatedButton(
                onPressed: () => _buyProduct(product),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor:
                      isLifetime
                          ? Colors.amber.shade700
                          : isYearly
                          ? Colors.purple
                          : Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isPurchasing
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          isLifetime ? 'Mua ngay' : 'Đăng ký',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionTerms() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, color: Colors.grey, size: 20),
          SizedBox(height: 8),
          Text(
            'Đăng ký sẽ tự động gia hạn trừ khi bạn hủy ít nhất 24 giờ trước khi kết thúc chu kỳ hiện tại. Bạn có thể hủy bất kỳ lúc nào trong cài đặt cửa hàng ứng dụng.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [Colors.white, Colors.greenAccent],
              ).createShader(bounds);
            },
            child: const Icon(
              Icons.volunteer_activism,
              size: 70,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hỗ trợ phát triển',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Mỗi đóng góp giúp chúng tôi phát triển ứng dụng tốt hơn',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSelector() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payments_rounded,
                  color: Colors.teal.shade700,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Chọn số tiền ủng hộ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Vuốt qua để xem thêm các lựa chọn khác',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
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
          ],
        ),
      ),
    );
  }

  Widget _amountButton(String label, double amount) {
    final isSelected = _donationAmount == amount;
    final color = isSelected ? Colors.teal : Colors.grey.shade200;
    final textColor = isSelected ? Colors.white : Colors.black87;

    return InkWell(
      onTap: () {
        setState(() {
          _donationAmount = amount;
          _donationAmountController.text = amount.toStringAsFixed(0);
          _hasSelectedAmount = true;
        });
        _generateQRCode();
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountField() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.teal.shade700, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Số tiền tùy chỉnh',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _donationAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nhập số tiền (VND)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal.shade500, width: 2),
                ),
                prefixIcon: const Icon(Icons.monetization_on),
                suffixText: 'VND',
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: 'Ví dụ: 50000',
                helperText: 'Nhập số tiền và mã QR sẽ được tạo tự động',
              ),
              onChanged: (value) {
                try {
                  setState(() {
                    _donationAmount = double.parse(value);
                  });

                  // Debounce QR generation
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

  Widget _buildBankInfoSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: Colors.teal.shade700,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Thông tin chuyển khoản',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildBankDetailRowImproved('Ngân hàng:', _bankName),
                  const Divider(),
                  _buildBankDetailRowImproved('Số TK:', _accountNumber),
                  const Divider(),
                  _buildBankDetailRowImproved('Chủ TK:', _accountName),
                  const Divider(),
                  _buildBankDetailRowImproved(
                    'Số tiền:',
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                      decimalDigits: 0,
                    ).format(_donationAmount),
                  ),
                  const Divider(),
                  _buildBankDetailRowImproved('Nội dung:', 'Donate NotesApp'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailRowImproved(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép vào bộ nhớ'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Colors.green,
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.copy, size: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrDisplay() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: Colors.teal.shade700,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Mã QR chuyển khoản',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chỉ hiển thị nút chọn lại số tiền khi đã chọn số tiền
            if (_hasSelectedAmount)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasSelectedAmount = false;
                  });
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Chọn lại số tiền'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  side: BorderSide(color: Colors.teal.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // QR Loading Indicator
            if (_isLoadingQR)
              Column(
                children: [
                  const SizedBox(height: 40),
                  CircularProgressIndicator(color: Colors.teal.shade500),
                  const SizedBox(height: 16),
                  const Text('Đang tạo mã QR...'),
                  const SizedBox(height: 40),
                ],
              )
            // QR Image Display
            else if (_qrImageUrl != null)
              Column(
                children: [
                  // QR Code container with border
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.teal.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _qrImageUrl!,
                        height: 250,
                        width: 250,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 250,
                            width: 250,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Text(
                                'Lỗi tải mã QR',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Hướng dẫn sử dụng:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Mở app ngân hàng hoặc ví điện tử\n'
                          '2. Quét mã QR hoặc chọn "Chuyển tiền qua mã QR"\n'
                          '3. Kiểm tra thông tin và xác nhận chuyển khoản',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons - Sửa phần này để không bị tràn
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.copy,
                        label: 'Sao chép URL',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _qrImageUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép URL mã QR'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildActionButton(
                        icon: Icons.download,
                        label: 'Lưu vào Thư viện',
                        isLoading: _isDownloading,
                        onPressed: _isDownloading ? null : _downloadQRImage,
                      ),
                    ],
                  ),
                ],
              )
            // Fallback QR
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
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
                            'Lỗi tạo mã QR: ${error.toString()}',
                            style: const TextStyle(color: Colors.red),
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mã QR dự phòng (có thể không hoạt động với mọi ứng dụng)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Thank you message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade50, Colors.red.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'Cảm ơn bạn đã ủng hộ!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sự ủng hộ của bạn giúp chúng tôi tiếp tục phát triển và cải thiện ứng dụng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade50,
          foregroundColor: Colors.teal.shade700,
          side: BorderSide(color: Colors.teal.shade200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon:
            isLoading
                ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.teal.shade700,
                  ),
                )
                : Icon(icon, size: 16),
        label: Text(
          isLoading && icon == Icons.download ? 'Đang lưu...' : label,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
