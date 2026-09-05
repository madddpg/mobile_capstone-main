/// Define the current environment
enum Environment { dev, staging, prod }

class ApiConfig {
  /// Toggle this to switch between environments (Dev vs Production)
  static const Environment currentEnv = Environment.prod;

  /// Dynamically computes the correct Base URL based on environment
  static String get baseUrl {
    switch (currentEnv) {
      case Environment.prod:
        // Production Cloud Function
        return 'https://us-central1-iconstruct-58a87.cloudfunctions.net/api';
      case Environment.staging:
        return 'https://api.yourstagingdomain.com/api';
      case Environment.dev:
        // Adjust this if you use an emulator (e.g., http://10.0.2.2:5001/...)
        return 'https://us-central1-iconstruct-58a87.cloudfunctions.net/api';
    }
  }

  /// Specific endpoints
  static String get authUrl => baseUrl;
}
