import 'package:flutter/foundation.dart';

/// Mock subscription service for development/testing
/// This provides the same interface as SubscriptionService but without in_app_purchase dependency
class MockSubscriptionService extends ChangeNotifier {
  bool _isSubscribed = false;
  bool _isTrialActive = true; // Start with trial active for testing
  DateTime? _trialStartDate;
  int _trialDays = 7;
  bool _isLoading = false;

  MockSubscriptionService() {
    _trialStartDate = DateTime.now();
  }

  // Getters
  bool get isSubscribed => _isSubscribed;
  bool get isTrialActive => _isTrialActive;
  bool get hasAccess => _isSubscribed || _isTrialActive;
  bool get isLoading => _isLoading;

  // Stream for premium access
  Stream<bool> hasPremiumAccess() async* {
    yield hasAccess;
  }

  // Subscription status text
  String getSubscriptionStatusText() {
    if (_isSubscribed) {
      return 'Premium Active';
    } else if (_isTrialActive) {
      return 'Free Trial Active';
    } else {
      return 'Free Plan';
    }
  }

  // Trial days remaining
  int getTrialDaysRemaining() {
    if (!_isTrialActive) return 0;
    
    final daysSinceStart = DateTime.now().difference(_trialStartDate!).inDays;
    return (_trialDays - daysSinceStart).clamp(0, _trialDays);
  }

  // Mock methods for testing
  Future<void> startTrial() async {
    _isTrialActive = true;
    _trialStartDate = DateTime.now();
    notifyListeners();
  }

  Future<void> subscribe() async {
    _isSubscribed = true;
    _isTrialActive = false;
    notifyListeners();
  }

  Future<void> cancelSubscription() async {
    _isSubscribed = false;
    _isTrialActive = false;
    notifyListeners();
  }

  Future<void> endTrial() async {
    _isTrialActive = false;
    notifyListeners();
  }

  // Mock product details
  String? get monthlyProduct => 'mock_monthly_product';
  
  // Mock purchase methods
  Future<void> purchaseSubscription() async {
    _isLoading = true;
    notifyListeners();
    
    // Simulate purchase delay
    await Future.delayed(const Duration(seconds: 2));
    
    _isSubscribed = true;
    _isTrialActive = false;
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> restorePurchases() async {
    _isLoading = true;
    notifyListeners();
    
    // Simulate restore delay
    await Future.delayed(const Duration(seconds: 1));
    
    // For mock, just set as subscribed
    _isSubscribed = true;
    _isTrialActive = false;
    _isLoading = false;
    notifyListeners();
  }
}
