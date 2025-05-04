class Config {
  // Reference image settings
  static const String defaultReferenceHashFile = 'alpha_reference_phash.dat';
  
  // Processing settings
  static const double defaultHashSeparationThreshold = 4.0;
  static const int defaultThresholdLevel = 70;
  static const int maxImageSize = 1000;
  
  // Image file extensions
  static const List<String> supportedImageExtensions = ['.jpg', '.jpeg', '.png'];
  
  // Output path for results
  static const String defaultResultsDirectory = 'results';
}