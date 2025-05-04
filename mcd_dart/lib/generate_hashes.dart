import 'dart:io';
import 'package:args/args.dart';
import 'package:fast_log/fast_log.dart';
import 'package:mcd_dart/mcd_dart.dart';

/// Utility to generate perceptual hash database from reference card images
void main(List<String> arguments) async {
  // Parse command-line arguments
  ArgParser parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Directory containing reference card images', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Path to output hash file', defaultsTo: 'reference_phash.dat')
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help message', defaultsTo: false);

  try {
    ArgResults results = parser.parse(arguments);

    if (results['help'] as bool) {
      printUsage(parser);
      exit(0);
    }

    // Get parameters
    String inputDir = results['input'] as String;
    String outputFile = results['output'] as String;
    bool verbose = results['verbose'] as bool;

    // Check if input directory exists
    final dir = Directory(inputDir);
    if (!await dir.exists()) {
      error('Error: Input directory does not exist: $inputDir');
      exit(1);
    }

    // Initialize the card detector
    MagicCardDetector detector = MagicCardDetector();
    detector.verbose = verbose;

    info('Reading reference images from $inputDir');
    try {
      await detector.readAndAdjustReferenceImages(inputDir);
      info('Loaded ${detector.referenceImages.length} reference images');
    } catch (e) {
      error('Error reading reference images: $e');
      exit(1);
    }

    // Export hash data
    info('Exporting reference hash data to $outputFile');
    try {
      await detector.exportReferenceData(outputFile);
      info('Hash database successfully exported');
    } catch (e) {
      error('Error exporting hash data: $e');
      exit(1);
    }

    success('Done!');
  } catch (e) {
    error('Error: $e');
    printUsage(parser);
    exit(1);
  }
}

void printUsage(ArgParser parser) {
  info('Magic Card Detector - Hash Generator');
  info('This tool generates a perceptual hash database from reference card images.');
  info('The hash database can be used by the detector for faster card recognition.');
  info('Usage: generate_hashes [options]');
  info(parser.usage);
}