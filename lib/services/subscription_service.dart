import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService extends ChangeNotifier {
  static const String _monthlySubscriptionId = 'jumpz_monthly_premium';
  static const String _trialPeriodDays = '7';
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  bool _isAvailable = false;
  bool _isLoading = false;
  bool _isSubscribed = false;
  bool _isTrialActive = false;
  bool _isTrialExpired = false;
  DateTime? _trialStartDate;
  DateTime? _subscriptionExpiryDate;
  String? _errorMessage;
  
  // Getters
  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isSubscribed => _isSubscribed;
  bool get isTrialActive => _isTrialActive;
  bool get isTrialExpired => _isTrialExpired;
  bool get hasAccess => _isSubscribed || _isTrialActive;
  String? get errorMessage => _errorMessage;
  DateTime? get trialStartDate => _trialStartDate;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  
  // Subscription product details
  ProductDetails? _monthlyProduct;
  ProductDetails? get monthlyProduct => _monthlyProduct;
  
  SubscriptionService() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Check if in-app purchases are available
      _isAvailable = await _inAppPurchase.isAvailable();
      
      if (!_isAvailable) {
        _errorMessage = 'In-app purchases are not available on this device';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Set up purchase listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: _onPurchaseStreamDone,
        onError: _onPurchaseStreamError,
      );
      
      // Load products
      await _loadProducts();
      
      // Check current subscription status
      await _checkSubscriptionStatus();
      
    } catch (e) {
      _errorMessage = 'Failed to initialize subscription service: $e';
      print('❌ Subscription service initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = {_monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('❌ Products not found: ${response.notFoundIDs}');
      }
      
      if (response.productDetails.isNotEmpty) {
        _monthlyProduct = response.productDetails.first;
        print('✅ Monthly subscription product loaded: ${_monthlyProduct?.title}');
      }
    } catch (e) {
      print('❌ Error loading products: $e');
      _errorMessage = 'Failed to load subscription products';
    }
  }
  
  Future<void> _checkSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Check Firestore for subscription status
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _isSubscribed = data['isSubscribed'] ?? false;
        _isTrialActive = data['isTrialActive'] ?? false;
        _isTrialExpired = data['isTrialExpired'] ?? false;
        _trialStartDate = data['trialStartDate']?.toDate();
        _subscriptionExpiryDate = data['subscriptionExpiryDate']?.toDate();
        
        // Check if trial has expired
        if (_isTrialActive && _trialStartDate != null) {
          final trialEndDate = _trialStartDate!.add(const Duration(days: 7));
          if (DateTime.now().isAfter(trialEndDate)) {
            _isTrialActive = false;
            _isTrialExpired = true;
            await _updateSubscriptionStatus();
          }
        }
        
        // Check if subscription has expired
        if (_isSubscribed && _subscriptionExpiryDate != null) {
          if (DateTime.now().isAfter(_subscriptionExpiryDate!)) {
            _isSubscribed = false;
            await _updateSubscriptionStatus();
          }
        }
      } else {
        // New user - start trial
        await _startTrial();
      }
    } catch (e) {
      print('❌ Error checking subscription status: $e');
    }
  }
  
  Future<void> _startTrial() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      _trialStartDate = DateTime.now();
      _isTrialActive = true;
      _isTrialExpired = false;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'isTrialActive': true,
        'trialStartDate': _trialStartDate,
        'isTrialExpired': false,
        'isSubscribed': false,
      }, SetOptions(merge: true));
      
      print('✅ 7-day free trial started');
      notifyListeners();
    } catch (e) {
      print('❌ Error starting trial: $e');
    }
  }
  
  Future<void> purchaseSubscription() async {
    if (_monthlyProduct == null) {
      _errorMessage = 'Subscription product not available';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: _monthlyProduct!);
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (!success) {
        _errorMessage = 'Failed to initiate purchase';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Purchase failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> restorePurchases() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _errorMessage = 'Failed to restore purchases: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _showPendingUI();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _errorMessage = purchaseDetails.error?.message ?? 'Purchase failed';
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _verifyPurchase(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }
  
  void _onPurchaseStreamDone() {
    _subscription?.cancel();
    _subscription = null;
  }
  
  void _onPurchaseStreamError(IAPError error) {
    _errorMessage = error.message;
    _isLoading = false;
    notifyListeners();
  }
  
  void _showPendingUI() {
    // Handle pending purchase UI
    print('🔄 Purchase pending...');
  }
  
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.productID == _monthlySubscriptionId) {
        // Verify with your backend if needed
        await _updateSubscriptionStatus();
        _isLoading = false;
        notifyListeners();
        print('✅ Subscription purchase verified');
      }
    } catch (e) {
      _errorMessage = 'Failed to verify purchase: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _updateSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isSubscribed': _isSubscribed,
        'isTrialActive': _isTrialActive,
        'isTrialExpired': _isTrialExpired,
        'trialStartDate': _trialStartDate,
        'subscriptionExpiryDate': _subscriptionExpiryDate,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating subscription status: $e');
    }
  }
  
  String getTrialDaysRemaining() {
    if (!_isTrialActive || _trialStartDate == null) return '0';
    
    final trialEndDate = _trialStartDate!.add(const Duration(days: 7));
    final daysRemaining = trialEndDate.difference(DateTime.now()).inDays;
    return daysRemaining > 0 ? daysRemaining.toString() : '0';
  }
  
  String getSubscriptionStatusText() {
    if (_isSubscribed) {
      return 'Premium Active';
    } else if (_isTrialActive) {
      final daysRemaining = getTrialDaysRemaining();
      return 'Free Trial ($daysRemaining days left)';
    } else if (_isTrialExpired) {
      return 'Trial Expired';
    } else {
      return 'Not Subscribed';
    }
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

