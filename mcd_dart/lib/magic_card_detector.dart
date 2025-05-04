import 'dart:io';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as path;
import 'package:mcd_dart/mcd_dart.dart';

void main(List<String> arguments) async {
  // Parse command-line arguments
  ArgParser parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Path to input image or directory', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Path to output directory', defaultsTo: Config.defaultResultsDirectory)
    ..addOption('reference', abbr: 'r', help: 'Path to reference hash file', defaultsTo: Config.getDefaultReferenceHashPath())
    ..addFlag('all-sets', abbr: 'a', help: 'Load all available set hashes', defaultsTo: false)
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output', defaultsTo: false)
    ..addFlag('visual', abbr: 'd', help: 'Enable visualization (requires GUI)', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help message', defaultsTo: false);

  try {
    ArgResults results = parser.parse(arguments);

    if (results['help'] as bool) {
      printUsage(parser);
      exit(0);
    }

    // Get parameters
    String inputPath = results['input'] as String;
    String outputPath = results['output'] as String;
    String refHashPath = results['reference'] as String;
    bool loadAllSets = results['all-sets'] as bool;
    bool verbose = results['verbose'] as bool;
    bool visual = results['visual'] as bool;

    // Create output directory if it doesn't exist
    Directory outputDir = Directory(outputPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
      info('Created output directory: $outputPath');
    }

    // Initialize the card detector
    MagicCardDetector detector = MagicCardDetector(outputPath: outputPath);
    detector.verbose = verbose;
    detector.visual = visual;

    // Load reference data
    try {
      if (loadAllSets) {
        info('Loading all available set hashes...');
        await detector.loadAllSetHashes();
      } else {
        info('Loading reference hash file: $refHashPath');
        await detector.readPrehashReferenceData(refHashPath);
      }
      
      info('Loaded ${detector.referenceImages.length} reference cards in total.');
    } catch (e) {
      error('Error loading reference data: $e');
      error('Please make sure the reference hash file(s) exist and are valid.');
      exit(1);
    }

    // Check if input is a file or directory
    File inputFile = File(inputPath);
    Directory inputDir = Directory(inputPath);
    
    if (await inputFile.exists()) {
      // Process a single image
      info('Processing single image: $inputPath');
      
      try {
        Uint8List bytes = await inputFile.readAsBytes();
        List<Uint8List> results = await detector.processImage(bytes, path.basename(inputPath));
        
        // Save original and annotated images
        String name = path.basenameWithoutExtension(inputPath);
        
        await File(path.join(outputPath, '${name}_original.jpg')).writeAsBytes(results[0]);
        await File(path.join(outputPath, '${name}_result.jpg')).writeAsBytes(results[1]);
        
        success('Processing complete. Results saved to $outputPath');
      } catch (e) {
        error('Error processing image: $e');
        exit(1);
      }
    } else if (await inputDir.exists()) {
      // Process a directory of images
      info('Processing images in directory: $inputPath');
      
      try {
        await detector.readAndAdjustTestImages(inputPath);
        await detector.runRecognition();
        
        success('Processing complete. Results saved to $outputPath');
      } catch (e) {
        error('Error processing images: $e');
        exit(1);
      }
    } else {
      error('Error: Input path does not exist: $inputPath');
      exit(1);
    }
  } catch (e) {
    error('Error: $e');
    printUsage(parser);
    exit(1);
  }
}

void printUsage(ArgParser parser) {
  info('Magic Card Detector - Dart Implementation');
  info('Usage: magic_card_detector [options]');
  info(parser.usage);
}