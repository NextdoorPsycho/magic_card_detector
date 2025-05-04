import 'dart:io';
import 'package:args/args.dart';
import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as path;
import 'package:mcd_dart/mcd_dart.dart';

/// Utility to generate perceptual hash database from Scryfall card images by set code
void main(List<String> arguments) async {
  // Parse command-line arguments
  ArgParser parser = ArgParser()
    ..addOption('set', abbr: 's', help: 'Set code (e.g., "DSK", "LTR", "MOM")', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Path to output hash file', defaultsTo: Config.getDefaultReferenceHashPath())
    ..addOption('tempdir', abbr: 't', help: 'Temporary directory to store downloaded images', defaultsTo: 'temp_images')
    ..addFlag('keep-images', help: 'Keep downloaded images after hash generation', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help message', defaultsTo: false);

  try {
    ArgResults results = parser.parse(arguments);

    if (results['help'] as bool) {
      printUsage(parser);
      exit(0);
    }

    // Get parameters
    String setCode = results['set'] as String;
    String outputFile = results['output'] as String;
    String tempDir = results['tempdir'] as String;
    bool keepImages = results['keep-images'] as bool;
    
    // Always use verbose output
    bool verbose = true;
    
    // Always modify the output path to include the set name
    final hashesDir = Config.getSetHashesDirectory();
    outputFile = path.join(hashesDir, '${setCode.toLowerCase()}_reference_phash.dat');
    info('Using output file: $outputFile');

    // Create a temporary directory for downloaded images
    final tempDirectory = Directory(tempDir);
    if (await tempDirectory.exists()) {
      info('Clearing temporary directory: ${tempDirectory.path}');
      await tempDirectory.delete(recursive: true);
    }
    await tempDirectory.create(recursive: true);
    info('Created temporary directory: ${tempDirectory.path}');

    // Initialize the Scryfall client
    final scryfallClient = ScryfallClient(verbose: verbose);
    info('Initialized Scryfall client');

    try {
      // Download images for the specified set
      info('Downloading images for set: $setCode');
      final downloadedFiles = await scryfallClient.downloadSetImages(
        setCode, 
        tempDirectory.path,
        size: ImageSize.large,
      );
      info('Downloaded ${downloadedFiles.length} images for set $setCode');

      if (downloadedFiles.isEmpty) {
        error('No images were downloaded. Please check your set code.');
        exit(1);
      }

      // Initialize the card detector
      MagicCardDetector detector = MagicCardDetector();
      detector.verbose = verbose;

      // Process the downloaded images
      info('Processing downloaded images...');
      await detector.readAndAdjustReferenceImages(tempDirectory.path);
      info('Processed ${detector.referenceImages.length} reference images');

      // Export hash data
      info('Exporting reference hash data to $outputFile');
      try {
        // Create output directory if it doesn't exist
        final outputDir = Directory(path.dirname(outputFile));
        if (!await outputDir.exists()) {
          await outputDir.create(recursive: true);
          info('Created output directory: ${outputDir.path}');
        }
        
        await detector.exportReferenceData(outputFile);
        info('Hash database successfully exported with ${detector.referenceImages.length} cards');
      } catch (e) {
        error('Error exporting hash data: $e');
        exit(1);
      }

      // Clean up downloaded images if not keeping them
      if (!keepImages) {
        info('Cleaning up temporary images...');
        await tempDirectory.delete(recursive: true);
        info('Temporary directory removed');
      } else {
        info('Keeping downloaded images in: ${tempDirectory.path}');
      }

      // Clean up resources
      scryfallClient.close();
      success('Done! Hash database created successfully for set $setCode');
    } catch (e) {
      error('Error: $e');
      // Clean up on error
      scryfallClient.close();
      if (!keepImages && await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
      exit(1);
    }
  } catch (e) {
    error('Error: $e');
    printUsage(parser);
    exit(1);
  }
}

void printUsage(ArgParser parser) {
  info('Magic Card Detector - Hash Generator (Scryfall)');
  info('Usage: generate_hashes_from_scryfall --set=<SET_CODE> [options]');
  info(parser.usage);
}