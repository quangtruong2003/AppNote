import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  List<String> _consumables = [];
  bool _isPurchasing = false;
  bool _isLoading = true;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final List<String> _productIds = [
    'premium_monthly',
    'premium_yearly',
    'premium_lifetime',
  ];

  @override
  void initState() {
    super.initState();
    _initIAP();
  }

  Future<void> _initIAP() async {
    try {
      _isAvailable = await _iap.isAvailable();

      if (_isAvailable) {
        await _getProducts();
        _subscription = _iap.purchaseStream.listen(_listenToPurchaseUpdated);
      }
    } catch (e) {
      _isAvailable = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        _productIds.toSet(),
      );

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      if (mounted) {
        setState(() {
          _products = response.productDetails;
          _products.sort(
            (a, b) =>
                _extractPrice(a.rawPrice).compareTo(_extractPrice(b.rawPrice)),
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
        setState(() {
          _isPurchasing = true;
        });
      } else {
        setState(() {
          _isPurchasing = false;
        });

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
      // Here you would typically send the purchase receipt to your backend
      // for verification with Apple/Google

      // For this example, we're just assuming it's valid
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
          SnackBar(content: Text('Failed to verify purchase: ${e.toString()}')),
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

  Future<void> _buyProduct(ProductDetails productDetails) async {
    if (_isPurchasing) return;

    try {
      setState(() {
        _isPurchasing = true;
      });

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null,
      );

      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate purchase: ${e.toString()}'),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isPremium = authProvider.isPremium;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium Features')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : isPremium
              ? _buildPremiumContent(context)
              : _buildUpgradeContent(context),
    );
  }

  Widget _buildPremiumContent(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
          ),
          const SizedBox(height: 24),
          const Text(
            'Premium Benefits',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _premiumFeatureCard(
            icon: Icons.format_paint,
            title: 'Advanced Formatting',
            description:
                'Access to rich text formatting options for your notes.',
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _restorePurchases,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Restore Purchases'),
          ),
        ],
      ),
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

  Widget _buildUpgradeContent(BuildContext context) {
    return _products.isEmpty
        ? _buildNoProductsView()
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 24),
              ..._products.map((product) => _buildProductCard(product)),
              const SizedBox(height: 24),
              const Text(
                'Premium Features',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _featureItem(Icons.format_paint, 'Advanced Formatting'),
              _featureItem(Icons.cloud_upload, 'Unlimited Cloud Storage'),
              _featureItem(Icons.folder_special, 'Categories & Tags'),
              _featureItem(Icons.lock, 'Password Protected Notes'),
              _featureItem(Icons.devices, 'Sync Across Devices'),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _restorePurchases,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Restore Purchases'),
              ),
              const SizedBox(height: 32),
              const Text(
                'Subscriptions will automatically renew unless canceled at least 24 hours before the end of the current period. You can cancel anytime in your app store settings.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
  }

  Widget _buildNoProductsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Premium Plans Unavailable',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re having trouble loading our premium plans.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _initIAP();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
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

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
