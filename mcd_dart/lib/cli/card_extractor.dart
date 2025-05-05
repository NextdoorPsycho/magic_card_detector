import 'dart:io';
import 'package:path/path.dart' as path;

/// Handles the extraction and detection of cards from images
class CardExtractor {
  /// Extracts cards from images
  ///
  /// [selectedSet] - The set to use for recognition (e.g., LEA, DSK, or 'All')
  /// [outputPath] - The path where to save processed images
  /// [inputPath] - The path containing source images
  /// [confidenceThreshold] - Minimum confidence level for recognition (50-100)
  /// [saveDebugImages] - Whether to save debug images with detections
  ///
  /// Returns true if the operation was successful, false otherwise
  static bool extractCards(
    String selectedSet,
    String outputPath,
    String inputPath,
    int confidenceThreshold,
    bool saveDebugImages,
  ) {
    print('Extracting cards from images in $inputPath');

    try {
      // Create output directory if it doesn't exist
      final Directory outputDir = Directory(outputPath);
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
        print('Created output directory: ${outputDir.path}');
      } else {
        print('Using existing output directory: ${outputDir.path}');
      }

      // Check if input directory exists
      final Directory inputDir = Directory(inputPath);
      if (!inputDir.existsSync()) {
        print('Error: Input directory does not exist: ${inputDir.path}');
        return false;
      }

      // Determine hash file path based on selected set
      String hashFilePath;
      if (selectedSet == 'All') {
        print('Using all available hash sets...');
        // Use a specific set as default for now
        hashFilePath = path.join('assets', 'set_hashes', 'dsk_reference_phash.dat');
      } else {
        print('Using hash data for set: $selectedSet');
        hashFilePath = path.join('assets', 'set_hashes', 
            '${selectedSet.toLowerCase()}_reference_phash.dat');
      }
      
      // Check if hash file exists
      final File hashFile = File(hashFilePath);
      if (!hashFile.existsSync()) {
        print('Error: Hash file does not exist: ${hashFile.path}');
        return false;
      }

      // Adjust confidence threshold to match Python script's expectations
      // The Python script expects a value around 4.0, while our UI uses 50-100%
      final double adjustedThreshold = 4.0 * confidenceThreshold / 85;
      
      // Run Python script for card detection
      print('Running card detection with threshold: ${adjustedThreshold.toStringAsFixed(2)}');
      
      final result = Process.runSync(
        'python3',
        [
          path.join('bin', 'detect_cards.py'),
          '--input-path', inputPath,
          '--output-path', outputPath,
          '--phash', hashFilePath,
          '--threshold', adjustedThreshold.toString(),
          if (saveDebugImages) '--debug-images',
          '--verbose',
        ],
      );
      
      if (result.exitCode != 0) {
        print('Error running Python script:');
        print(result.stderr);
        return false;
      }
      
      print(result.stdout);
      
      return true;
    } catch (e) {
      print('Error during card extraction: $e');
      return false;
    }
  }
}
