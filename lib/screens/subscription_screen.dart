import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../services/subscription_service.dart';
import '../services/mock_subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Jumpz Premium',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
        body: Consumer<MockSubscriptionService>(
        builder: (context, subscriptionService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Premium Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Unlock Premium Features',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                const Text(
                  'Get unlimited access to all Jumpz features',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Features List
                _buildFeatureList(),
                
                const SizedBox(height: 40),
                
                // Pricing Card
                _buildPricingCard(subscriptionService),
                
                const SizedBox(height: 24),
                
                // Trial Info
                if (subscriptionService.isTrialActive)
                  _buildTrialInfo(subscriptionService),
                
                const SizedBox(height: 32),
                
                // Action Buttons
                _buildActionButtons(subscriptionService),
                
                const SizedBox(height: 24),
                
                // Terms and Privacy
                _buildTermsAndPrivacy(),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildFeatureList() {
    final features = [
      'Unlimited jump tracking',
      'Advanced analytics & insights',
      'Camera jump detection',
      'Photo capture with stats',
      'Goal setting & progress tracking',
      'Leaderboards & achievements',
      'Export & share progress',
      'Priority support',
    ];
    
    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFFFFD700),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                feature,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
  
  Widget _buildPricingCard(MockSubscriptionService subscriptionService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Monthly Premium',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
                '\$4.99',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'per month',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '7-Day Free Trial',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrialInfo(MockSubscriptionService subscriptionService) {
    final daysRemaining = subscriptionService.getTrialDaysRemaining();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.schedule,
            color: Colors.blue,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Free Trial Active',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$daysRemaining days remaining',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(MockSubscriptionService subscriptionService) {
    if (subscriptionService.isLoading) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      );
    }
    
    if (subscriptionService.isSubscribed) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Premium Active',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        // Subscribe Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: subscriptionService.isLoading ? null : () {
              subscriptionService.purchaseSubscription();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
            child: const Text(
              'Start Free Trial',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Restore Purchases Button
        TextButton(
          onPressed: subscriptionService.isLoading ? null : () {
            subscriptionService.restorePurchases();
          },
          child: const Text(
            'Restore Purchases',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTermsAndPrivacy() {
    return Column(
      children: [
        const Text(
          'By subscribing, you agree to our Terms of Service and Privacy Policy.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                // Open Terms of Service
              },
              child: const Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),
            const Text(
              ' • ',
              style: TextStyle(color: Colors.white54),
            ),
            TextButton(
              onPressed: () {
                // Open Privacy Policy
              },
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

