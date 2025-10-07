/// Utility class for calculating calories burned during jump rope sessions
/// Uses MET (Metabolic Equivalent of Task) values for accurate calculations
class CaloriesCalculator {
  // MET values for different jump rope intensities
  static const double _lightIntensityMET = 8.0;      // Light jumping
  static const double _moderateIntensityMET = 12.0;   // Moderate jumping
  static const double _intenseIntensityMET = 15.0;    // Intense jumping
  
  // Default weight in kg if user hasn't set their weight
  static const double _defaultWeight = 70.0;
  
  /// Calculates calories burned based on jump frequency and duration
  /// 
  /// [jumpCount] - Number of jumps performed
  /// [durationMinutes] - Duration of the session in minutes
  /// [weightKg] - User's weight in kilograms (defaults to 70kg)
  /// 
  /// Returns the estimated calories burned
  static double calculateCalories({
    required int jumpCount,
    required double durationMinutes,
    double? weightKg,
  }) {
    if (jumpCount <= 0 || durationMinutes <= 0) return 0.0;
    
    final weight = weightKg ?? _defaultWeight;
    final intensity = _determineIntensity(jumpCount, durationMinutes);
    final metValue = _getMETValue(intensity);
    
    // Formula: Calories = MET × weight(kg) × time(hours)
    final timeHours = durationMinutes / 60.0;
    final calories = metValue * weight * timeHours;
    
    return calories.roundToDouble();
  }
  
  /// Determines the intensity level based on jump frequency
  /// 
  /// [jumpCount] - Number of jumps performed
  /// [durationMinutes] - Duration of the session in minutes
  /// 
  /// Returns the intensity level (light, moderate, or intense)
  static JumpIntensity _determineIntensity(int jumpCount, double durationMinutes) {
    if (durationMinutes <= 0) return JumpIntensity.light;
    
    final jumpsPerMinute = jumpCount / durationMinutes;
    
    if (jumpsPerMinute < 30) {
      return JumpIntensity.light;
    } else if (jumpsPerMinute < 60) {
      return JumpIntensity.moderate;
    } else {
      return JumpIntensity.intense;
    }
  }
  
  /// Gets the MET value for the given intensity
  static double _getMETValue(JumpIntensity intensity) {
    switch (intensity) {
      case JumpIntensity.light:
        return _lightIntensityMET;
      case JumpIntensity.moderate:
        return _moderateIntensityMET;
      case JumpIntensity.intense:
        return _intenseIntensityMET;
    }
  }
  
  /// Calculates calories for a session with automatic intensity detection
  /// 
  /// [jumpCount] - Number of jumps performed
  /// [durationMinutes] - Duration of the session in minutes
  /// [weightKg] - User's weight in kilograms
  /// 
  /// Returns a map with calories and intensity information
  static Map<String, dynamic> calculateSessionCalories({
    required int jumpCount,
    required double durationMinutes,
    double? weightKg,
  }) {
    if (jumpCount <= 0 || durationMinutes <= 0) {
      return {
        'calories': 0.0,
        'intensity': JumpIntensity.light,
        'jumpsPerMinute': 0.0,
        'metValue': _lightIntensityMET,
      };
    }
    
    final weight = weightKg ?? _defaultWeight;
    final intensity = _determineIntensity(jumpCount, durationMinutes);
    final metValue = _getMETValue(intensity);
    final jumpsPerMinute = jumpCount / durationMinutes;
    
    final calories = calculateCalories(
      jumpCount: jumpCount,
      durationMinutes: durationMinutes,
      weightKg: weight,
    );
    
    return {
      'calories': calories,
      'intensity': intensity,
      'jumpsPerMinute': jumpsPerMinute,
      'metValue': metValue,
      'weight': weight,
      'duration': durationMinutes,
    };
  }
  
  /// Calculates daily calories goal based on user's weight and activity level
  /// 
  /// [weightKg] - User's weight in kilograms
  /// [activityLevel] - User's activity level (sedentary, moderate, active)
  /// 
  /// Returns the recommended daily calories goal
  static double calculateDailyCaloriesGoal({
    required double weightKg,
    ActivityLevel activityLevel = ActivityLevel.moderate,
  }) {
    // Base metabolic rate calculation (simplified)
    final bmr = 88.362 + (13.397 * weightKg) + (4.799 * 170) - (5.677 * 25); // Assuming 170cm height, 25 years old
    
    double multiplier;
    switch (activityLevel) {
      case ActivityLevel.sedentary:
        multiplier = 1.2;
        break;
      case ActivityLevel.moderate:
        multiplier = 1.55;
        break;
      case ActivityLevel.active:
        multiplier = 1.9;
        break;
    }
    
    return (bmr * multiplier).roundToDouble();
  }
  
  /// Formats calories value for display
  static String formatCalories(double calories) {
    if (calories < 1) {
      return '< 1';
    } else if (calories < 10) {
      return calories.toStringAsFixed(1);
    } else {
      return calories.round().toString();
    }
  }
  
  /// Gets intensity description for display
  static String getIntensityDescription(JumpIntensity intensity) {
    switch (intensity) {
      case JumpIntensity.light:
        return 'Light';
      case JumpIntensity.moderate:
        return 'Moderate';
      case JumpIntensity.intense:
        return 'Intense';
    }
  }
  
  /// Gets intensity color for UI display
  static int getIntensityColor(JumpIntensity intensity) {
    switch (intensity) {
      case JumpIntensity.light:
        return 0xFF4CAF50; // Green
      case JumpIntensity.moderate:
        return 0xFFFF9800; // Orange
      case JumpIntensity.intense:
        return 0xFFF44336; // Red
    }
  }
}

/// Enum for jump intensity levels
enum JumpIntensity {
  light,
  moderate,
  intense,
}

/// Enum for user activity levels
enum ActivityLevel {
  sedentary,
  moderate,
  active,
}
