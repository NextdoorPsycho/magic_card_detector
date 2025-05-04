import 'dart:io';
import 'package:args/args.dart';
import 'package:mcd_dart/mcd_dart.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

const String version = '0.0.1';
final Logger _logger = Logger('MCD-CLI');

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag(
      'visual',
      negatable: false,
      help: 'Show visual output (if supported by platform).',
    )
    ..addFlag(
      'version', 
      negatable: false, 
      help: 'Print the tool version.'
    )
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Path containing images to be analyzed',
      valueHelp: 'directory',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output path for results',
      valueHelp: 'directory',
    )
    ..addOption(
      'phash',
      help: 'Pre-calculated phash reference file',
      valueHelp: 'file',
      defaultsTo: 'alpha_reference_phash.dat',
    )
    ..addOption(
      'threshold',
      help: 'Recognition threshold value',
      valueHelp: 'value',
      defaultsTo: '4.0',
    );
}

void printUsage(ArgParser argParser) {
  print('Magic Card Detector Dart CLI');
  print('===========================');
  print('Detects and recognizes Magic: The Gathering cards in images');
  print('');
  print('Usage: dart mcd_dart.dart --input <path> --output <path> [options]');
  print('');
  print(argParser.usage);
}

Future<void> main(List<String> arguments) async {
  // Setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    bool verbose = false;
    bool visual = false;

    // Process the common flags
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }
    
    if (results.flag('version')) {
      print('Magic Card Detector version: $version');
      return;
    }
    
    if (results.flag('verbose')) {
      verbose = true;
      Logger.root.level = Level.FINE;
    }
    
    if (results.flag('visual')) {
      visual = true;
    }
    
    // Check for required options
    String? inputPath = results['input'] as String?;
    String? outputPath = results['output'] as String?;
    
    if (inputPath == null || outputPath == null) {
      print('Error: Both --input and --output options are required.');
      print('');
      printUsage(argParser);
      exit(1);
    }
    
    // Parse other options
    String phashPath = results['phash'] as String;
    double threshold = double.tryParse(results['threshold'] as String) ?? 4.0;
    
    // Create output directory if it doesn't exist
    Directory(outputPath).createSync(recursive: true);
    
    _logger.info('Starting Magic Card Detector...');
    _logger.info('Input path: $inputPath');
    _logger.info('Output path: $outputPath');
    _logger.info('pHash file: $phashPath');
    _logger.info('Threshold: $threshold');
    
    // Initialize detector
    final detector = MagicCardDetector(outputPath: outputPath);
    detector.verbose = verbose;
    detector.visual = visual;
    detector.hashSeparationThreshold = threshold;
    
    // Load reference data
    try {
      _logger.info('Loading reference data...');
      await detector.readPrehashReferenceData(phashPath);
    } catch (e) {
      _logger.severe('Failed to load reference data: $e');
      exit(1);
    }
    
    // Load test images
    try {
      _logger.info('Loading test images...');
      await detector.readAndAdjustTestImages(inputPath);
    } catch (e) {
      _logger.severe('Failed to load test images: $e');
      exit(1);
    }
    
    // Run recognition
    try {
      _logger.info('Running card detection and recognition...');
      await detector.runRecognition();
      _logger.info('Processing complete!');
    } catch (e) {
      _logger.severe('Error during recognition: $e');
      exit(1);
    }
    
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided
    print('Error: ${e.message}');
    print('');
    printUsage(argParser);
    exit(1);
  } catch (e) {
    _logger.severe('Unexpected error: $e');
    exit(1);
  }
}
