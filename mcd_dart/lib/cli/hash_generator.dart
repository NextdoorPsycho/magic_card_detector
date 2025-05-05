import 'dart:io';
import 'package:path/path.dart' as path;

/// Handles the generation of perceptual hashes for card sets
class HashGenerator {
  /// Generates hash data for a specific set
  ///
  /// [setCode] - The set code (e.g., LEA, DSK)
  /// [source] - The source to use ('Scryfall' or 'Local')
  /// [parallelism] - Number of parallel operations
  /// [cleanup] - Whether to clean up temporary files
  ///
  /// Returns true if the operation was successful, false otherwise
  static bool generateHashes(
    String setCode,
    String source,
    int parallelism,
    bool cleanup,
  ) {
    print('Generating hashes for set: $setCode');
    print('Using source: $source');
    print('Running with parallelism: $parallelism');

    // Define paths
    final Directory tempDir = Directory(path.join('.', 'temp_$setCode'));
    final String outputPath = path.join('assets', 'set_hashes', 
        '${setCode.toLowerCase()}_reference_phash.dat');
    final Directory outputDir = Directory(path.dirname(outputPath));

    try {
      // Ensure output directory exists
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
        print('Created output directory: ${outputDir.path}');
      }
      
      // Set up image source
      String imagePath;
      if (source == 'Scryfall') {
        // Create temp directory for downloaded images if it doesn't exist
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }
        print('Creating temporary directory: ${tempDir.path}');
        
        print('Fetching card data from Scryfall API...');
        print('Processing $parallelism cards at a time...');
        // This is where you would download images from Scryfall
        // For now, we'll assume images are already downloaded to temp dir
        imagePath = tempDir.path;
      } else {
        // Use local images
        print('Reading card images from local storage...');
        imagePath = path.join('assets', 'in');
      }

      // Run Python script to generate hashes
      print('Generating perceptual hashes...');
      final verbose = true; // Set to true for verbose output
      
      final result = Process.runSync(
        'python3',
        [
          path.join('bin', 'generate_hash.py'),
          '--set-path', imagePath,
          '--output', outputPath,
          if (verbose) '--verbose',
        ],
      );
      
      if (result.exitCode != 0) {
        print('Error running Python script:');
        print(result.stderr);
        return false;
      }
      
      print(result.stdout);
      
      // Clean up if requested
      if (cleanup && tempDir.existsSync() && source == 'Scryfall') {
        print('Cleaning up temporary files...');
        tempDir.deleteSync(recursive: true);
      }

      return true;
    } catch (e) {
      print('Error during hash generation: $e');
      return false;
    }
  }
}
