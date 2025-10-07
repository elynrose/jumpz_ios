import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../services/subscription_service.dart';
import '../services/mock_subscription_service.dart';
import 'subscription_screen.dart';

class SubscriptionGateScreen extends StatelessWidget {
  final String feature;
  final Widget? child;
  
  const SubscriptionGateScreen({
    super.key,
    required this.feature,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MockSubscriptionService>(
      builder: (context, subscriptionService, _) {
        if (subscriptionService.hasAccess) {
          return child ?? const SizedBox.shrink();
        }
        
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Premium Feature',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    '$feature is a premium feature. Upgrade to unlock unlimited access.',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Features Preview
                  _buildFeaturesPreview(),
                  
                  const SizedBox(height: 40),
                  
                  // Subscribe Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionScreen(),
                          ),
                        );
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
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Trial Info
                  if (subscriptionService.isTrialActive)
                    _buildTrialInfo(subscriptionService),
                  
                  const SizedBox(height: 24),
                  
                  // Close Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFeaturesPreview() {
    final features = [
      'Unlimited jump tracking',
      'Camera jump detection',
      'Photo capture with stats',
      'Advanced analytics',
    ];
    
    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFFFFD700),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              feature,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
  
  Widget _buildTrialInfo(MockSubscriptionService subscriptionService) {
    final daysRemaining = subscriptionService.getTrialDaysRemaining();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        'Free Trial: $daysRemaining days left',
        style: const TextStyle(
          fontSize: 14,
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

