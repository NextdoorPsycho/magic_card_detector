import 'dart:io';
import 'dart:convert';
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
        hashFilePath = path.join(
          'assets',
          'set_hashes',
          'dsk_reference_phash.dat',
        );
      } else if (selectedSet == 'Other') {
        // Allow the user to enter a custom hash file path
        print('Enter the path to your custom hash file:');
        hashFilePath = stdin.readLineSync() ?? '';
        if (hashFilePath.isEmpty) {
          print('Error: No hash file path provided');
          return false;
        }
      } else {
        print('Using hash data for set: $selectedSet');
        hashFilePath = path.join(
          'assets',
          'set_hashes',
          '${selectedSet.toLowerCase()}_reference_phash.dat',
        );
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

      // Check which Python script to use
      final File superEnhancedScript = File(
        path.join('bin', 'python', 'enhanced_detector.py'),
      );
      final File enhancedScript = File(
        path.join('bin', 'python', 'detect_cards.py'),
      );

      if (superEnhancedScript.existsSync()) {
        // Use enhanced detector with metadata support
        print('Using metadata-enhanced card detector...');
        final result = Process.runSync('python3', [
          superEnhancedScript.path,
          '--input',
          inputPath,
          '--output',
          outputPath,
          '--hash-file',
          hashFilePath,
          '--threshold',
          adjustedThreshold.toString(),
          if (saveDebugImages) '--visual',
          if (saveDebugImages || inputPath.contains(',')) '--verbose',
        ]);

        if (result.exitCode != 0) {
          print('Error running Python script:');
          print(result.stderr);
          return false;
        }

        // Parse and display results
        try {
          final dynamic jsonResult = jsonDecode(
            result.stdout.toString().trim(),
          );
          _printEnhancedResults(jsonResult);
        } catch (e) {
          print('Error parsing JSON result: $e');
          print(result.stdout);
        }
      } else if (enhancedScript.existsSync()) {
        // Use enhanced script that directly connects to mcd_python library
        print('Using enhanced card detector...');
        final result = Process.runSync('python3', [
          enhancedScript.path,
          '--input-path',
          inputPath,
          '--output-path',
          outputPath,
          '--phash',
          hashFilePath,
          '--threshold',
          adjustedThreshold.toString(),
          if (saveDebugImages) '--debug-images',
          if (saveDebugImages) '--verbose',
        ]);

        if (result.exitCode != 0) {
          print('Error running Python script:');
          print(result.stderr);
          return false;
        }

        print(result.stdout);
      } else {
        // Use legacy detector script (original implementation)
        print('Using legacy card detector...');
        final result = Process.runSync('python3', [
          path.join('bin', 'detect_cards.py'),
          '--input-path',
          inputPath,
          '--output-path',
          outputPath,
          '--phash',
          hashFilePath,
          '--threshold',
          adjustedThreshold.toString(),
          if (saveDebugImages) '--debug-images',
          '--verbose',
        ]);

        if (result.exitCode != 0) {
          print('Error running Python script:');
          print(result.stderr);
          return false;
        }

        print(result.stdout);
      }

      return true;
    } catch (e) {
      print('Error during card extraction: $e');
      return false;
    }
  }

  /// Prints enhanced detection results with metadata
  static void _printEnhancedResults(dynamic jsonResult) {
    // Handle single image result
    if (jsonResult is Map<String, dynamic>) {
      _printEnhancedResult(jsonResult);
      return;
    }

    // Handle multiple image results
    if (jsonResult is List) {
      for (final result in jsonResult) {
        if (result is Map<String, dynamic>) {
          _printEnhancedResult(result);
        }
      }
    }
  }

  /// Prints a single enhanced detection result
  static void _printEnhancedResult(Map<String, dynamic> result) {
    final String imageName = result['image_name'] ?? 'Unknown';
    final int cardCount = result['card_count'] ?? 0;

    print('\nImage: $imageName');
    print('Cards found: $cardCount');

    if (cardCount > 0 && result.containsKey('cards')) {
      print('Recognized cards:');
      for (final card in result['cards']) {
        final String name = card['name'] ?? 'Unknown';
        final double score = card['score'] ?? 0.0;

        // Check if we have metadata
        final Map<String, dynamic>? metadata = card['metadata'];

        if (metadata != null && metadata.isNotEmpty) {
          // Print with metadata
          final String cardName = metadata['card_name'] ?? name;
          final String setCode = metadata['set_code'] ?? '';
          final String collectorNumber = metadata['collector_number'] ?? '';
          final String scryfallId = metadata['scryfall_id'] ?? '';

          print('  - $cardName (${setCode.toUpperCase()}) #$collectorNumber');
          print('    Confidence: ${(score * 100).toStringAsFixed(1)}%');

          if (scryfallId.isNotEmpty) {
            print('    Scryfall ID: $scryfallId');
            print(
              '    Scryfall URL: https://scryfall.com/card/$setCode/$collectorNumber',
            );
          }
        } else {
          // Print without metadata
          print('  - $name (confidence: ${(score * 100).toStringAsFixed(1)}%)');
        }
      }
    }

    if (result.containsKey('result_image_path') &&
        result['result_image_path'] != null) {
      print('Result image saved to: ${result['result_image_path']}');
    }
  }
}
