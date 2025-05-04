import 'dart:io';
import 'package:path/path.dart' as path;

class Config {
  // Reference image settings
  static const String defaultHashesDirectory = 'assets/set_hashes';
  static const String defaultReferenceHashFile = 'alpha_reference_phash.dat';
  
  // Processing settings
  static const double defaultHashSeparationThreshold = 4.0;
  static const int defaultThresholdLevel = 70;
  static const int maxImageSize = 1000;
  
  // Image file extensions
  static const List<String> supportedImageExtensions = ['.jpg', '.jpeg', '.png'];
  
  // Output path for results
  static const String defaultResultsDirectory = 'assets/out';
  
  /// Get the absolute path to the set hashes directory
  static String getSetHashesDirectory() {
    // Get the script directory
    final String scriptDir = Directory.current.path;
    return path.join(scriptDir, defaultHashesDirectory);
  }
  
  /// Get all available set hash files
  static List<File> getAvailableSetHashes() {
    final String hashesDir = getSetHashesDirectory();
    
    try {
      final Directory hashesDirectory = Directory(hashesDir);
      if (!hashesDirectory.existsSync()) {
        print('Warning: Set hashes directory does not exist: $hashesDir');
        return [];
      }
      
      final List<File> files = hashesDirectory
          .listSync()
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dat'))
          .toList();
      
      return files;
    } catch (e) {
      print('Error reading set hashes directory: $e');
      return [];
    }
  }
  
  /// Get the default reference hash file path
  static String getDefaultReferenceHashPath() {
    return path.join(getSetHashesDirectory(), defaultReferenceHashFile);
  }
}