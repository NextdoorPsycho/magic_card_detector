import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:mcd_dart/utils/scryfall_client.dart';

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
  static Future<bool> generateHashes(
    String setCode,
    String source,
    int parallelism,
    bool cleanup,
  ) async {
    print('Generating hashes for set: $setCode');
    print('Using source: $source');
    print('Running with parallelism: $parallelism');

    // Define paths
    final Directory tempDir = Directory(path.join('.', 'temp_$setCode'));
    final String outputPath = path.join(
      'assets',
      'set_hashes',
      '${setCode.toLowerCase()}_reference_phash.dat',
    );
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

        // Download card images from Scryfall
        try {
          final int totalCards = await _downloadCardsFromScryfall(
            setCode,
            tempDir.path,
            parallelism,
          );
          print('Successfully downloaded $totalCards cards from Scryfall');
          imagePath = tempDir.path;
        } catch (e) {
          print('Error downloading cards from Scryfall: $e');
          return false;
        }
      } else {
        // Use local images
        print('Reading card images from local storage...');
        imagePath = path.join('assets', 'in');

        // Check if directory exists and contains images
        final Directory inputDir = Directory(imagePath);
        if (!inputDir.existsSync()) {
          print('Error: Local input directory does not exist: $imagePath');
          return false;
        }

        final List<FileSystemEntity> files = inputDir.listSync();
        final List<FileSystemEntity> imageFiles =
            files.where((file) {
              final String extension = path.extension(file.path).toLowerCase();
              return extension == '.jpg' ||
                  extension == '.jpeg' ||
                  extension == '.png';
            }).toList();

        if (imageFiles.isEmpty) {
          print('Error: No image files found in local directory: $imagePath');
          return false;
        }

        print('Found ${imageFiles.length} image files in local directory');
      }

      // Run Python script to generate hashes
      print('Generating perceptual hashes...');
      final bool verbose = true; // Set to true for verbose output

      // Use Flython to integrate with the Python script
      print('Initializing Python integration...');
      try {
        await _generateHashesWithPython(
          imagePath,
          outputPath,
          setCode,
          verbose,
        );
      } catch (e) {
        print('Error running Python hash generation: $e');
        return false;
      }

      // Clean up if requested
      if (cleanup && tempDir.existsSync() && source == 'Scryfall') {
        print('Cleaning up temporary files...');
        tempDir.deleteSync(recursive: true);
      }

      print('Hash generation completed successfully!');
      print('Hash data saved to: $outputPath');
      return true;
    } catch (e) {
      print('Error during hash generation: $e');
      return false;
    }
  }

  /// Download card images from Scryfall API
  ///
  /// [setCode] - The set code (e.g., LEA, DSK)
  /// [outputDir] - Directory to save downloaded images
  /// [parallelism] - Number of parallel downloads
  ///
  /// Returns the number of cards downloaded
  static Future<int> _downloadCardsFromScryfall(
    String setCode,
    String outputDir,
    int parallelism,
  ) async {
    print('Downloading cards from set: $setCode');
    print('Using parallelism: $parallelism');

    try {
      // Use the ScryfallClient to download images
      final List<String> downloadedFiles =
          await ScryfallClient.downloadSetImages(
            setCode,
            outputDir,
            parallelism,
            (current, total, cardName) {
              // Update progress
              if (current % 10 == 0 || current == total) {
                print('Progress: $current/$total - Processing: $cardName');
              }
            },
          );

      print('Downloaded ${downloadedFiles.length} card images to: $outputDir');
      return downloadedFiles.length;
    } catch (e) {
      print('Error downloading from Scryfall: $e');
      rethrow;
    }
  }

  /// Generate hashes using Python integration
  ///
  /// [imagePath] - Path to the directory containing card images
  /// [outputPath] - Path to save the hash data
  /// [setCode] - The set code (e.g., LEA, DSK)
  /// [verbose] - Whether to show verbose output
  static Future<void> _generateHashesWithPython(
    String imagePath,
    String outputPath,
    String setCode,
    bool verbose,
  ) async {
    print('Generating hashes using Python integration...');

    try {
      // Check which Python script to use
      final File superEnhancedScript = File(
        path.join('bin', 'python', 'enhanced_hash_generator.py'),
      );
      final File enhancedScript = File(
        path.join('bin', 'python', 'generate_hash.py'),
      );

      if (superEnhancedScript.existsSync()) {
        // Use the metadata-enhanced hash generator
        print('Using metadata-enhanced hash generator...');
        final result = Process.runSync('python3', [
          superEnhancedScript.path,
          '--set-path', imagePath,
          '--output', outputPath,
          '--set-code',
          setCode
              .toUpperCase(), // Pass the set code for Scryfall metadata lookup
          '--store-names', // Make sure card names are stored in the hash
          '--json', // Generate a JSON metadata file alongside the hash data
          if (verbose) '--verbose',
        ]);

        if (result.exitCode != 0) {
          print('Error running Python script:');
          print(result.stderr);
          throw Exception('Python script execution failed: ${result.stderr}');
        }

        print(result.stdout);
      } else if (enhancedScript.existsSync()) {
        // Use enhanced script that directly connects to mcd_python library
        print('Using enhanced hash generator...');
        final result = Process.runSync('python3', [
          enhancedScript.path,
          '--set-path',
          imagePath,
          '--output',
          outputPath,
          if (verbose) '--verbose',
        ]);

        if (result.exitCode != 0) {
          print('Error running Python script:');
          print(result.stderr);
          throw Exception('Python script execution failed: ${result.stderr}');
        }

        print(result.stdout);
      } else {
        // Use legacy script (original implementation)
        print('Using legacy hash generator...');
        final result = Process.runSync('python3', [
          path.join('bin', 'generate_hash.py'),
          '--set-path',
          imagePath,
          '--output',
          outputPath,
          if (verbose) '--verbose',
        ]);

        if (result.exitCode != 0) {
          print('Error running Python script:');
          print(result.stderr);
          throw Exception('Python script execution failed: ${result.stderr}');
        }

        print(result.stdout);
      }
    } catch (e) {
      print('Error executing Python script: $e');
      rethrow;
    }
  }
}
