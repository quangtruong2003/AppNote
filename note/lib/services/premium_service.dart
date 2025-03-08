import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/purchase_result.dart';
import 'dart:async';

class PremiumService {
  // Singleton pattern
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Product IDs
  static const String _monthlySubscriptionId = 'premium_monthly';
  static const String _yearlySubscriptionId = 'premium_yearly';

  // Stream of purchase updates
  Stream<List<PurchaseDetails>> get purchaseUpdated => _iap.purchaseStream;

  // Initialize in-app purchases
  Future<bool> initPurchases() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      return false;
    }

    const Set<String> kIds = {_monthlySubscriptionId, _yearlySubscriptionId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      kIds,
    );

    return response.productDetails.isNotEmpty;
  }

  // Get available products
  Future<List<ProductDetails>> getProducts(List<String> productIds) async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds.toSet(),
      );

      if (response.error != null) {
        debugPrint("Error querying products: ${response.error}");
        return [];
      }

      return response.productDetails;
    } catch (e) {
      debugPrint("Failed to get products: $e");
      return [];
    }
  }

  // Start a purchase
  Future<PurchaseResult> purchaseProduct(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // For consumable products use buyConsumable
      bool purchased = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!purchased) {
        return PurchaseResult(
          success: false,
          message: 'Purchase could not be initiated',
        );
      }

      // Actual purchase result will be delivered via the purchaseStream
      return PurchaseResult(
        success: true,
        message: 'Purchase initiated successfully',
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        message: 'Purchase failed: ${e.toString()}',
      );
    }
  }

  // Complete a purchase
  Future<void> completePurchase(
    PurchaseDetails purchaseDetails,
    String userId,
  ) async {
    await _iap.completePurchase(purchaseDetails);

    // Calculate expiry based on subscription type
    DateTime expiry;
    if (purchaseDetails.productID == _monthlySubscriptionId) {
      expiry = DateTime.now().add(const Duration(days: 30));
    } else {
      expiry = DateTime.now().add(const Duration(days: 365));
    }

    // Update user's premium status in Firestore
    await _firestore.collection('users').doc(userId).update({
      'isPremium': true,
      'premiumExpiry': Timestamp.fromDate(expiry),
    });
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // Check if user has valid premium subscription
  Future<bool> checkPremiumStatus(UserModel user) async {
    if (!user.isPremium) return false;
    if (user.premiumExpiry == null) return false;

    return user.premiumExpiry!.isAfter(DateTime.now());
  }
}
