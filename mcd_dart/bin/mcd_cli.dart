import 'package:interact/interact.dart';
import 'dart:io';
import 'dart:async';
import 'package:mcd_dart/cli/cli_exports.dart';
import 'package:mcd_dart/utils/command_memory.dart';

Future<void> main() async {
  print('Magic Card Detector CLI');
  print('======================');

  // Check if there's a previous command
  final bool hasPreviousCommand = CommandMemory.hasPreviousCommand();
  final String previousCommandDesc = await CommandMemory.getLastCommandDescription();
  
  // Create menu options
  final List<String> menuOptions = [
    'Generate Set Hashes',
    'Extract Cards',
  ];
  
  // Add the previous command option if available
  if (hasPreviousCommand) {
    menuOptions.insert(0, previousCommandDesc);
  }
  
  // Add exit option
  menuOptions.add('Exit');
  
  final int mainSelection =
      Select(
        prompt: 'Select an operation:',
        options: menuOptions,
      ).interact();
      
  // Calculate the adjusted index based on whether we have a previous command
  final int exitIndex = menuOptions.length - 1;
  final int extractCardsIndex = hasPreviousCommand ? 2 : 1;
  final int generateHashesIndex = hasPreviousCommand ? 1 : 0;
  
  if (hasPreviousCommand && mainSelection == 0) {
    // Run previous command
    await _runPreviousCommand();
  } else if (mainSelection == generateHashesIndex) {
    // Generate set hashes
    await _generateSetHashes();
  } else if (mainSelection == extractCardsIndex) {
    // Extract cards
    await _extractCards();
  } else if (mainSelection == exitIndex) {
    // Exit
    print('Exiting...');
    exit(0);
  }
}

/// Runs the previously saved command
Future<void> _runPreviousCommand() async {
  print('\nRunning previous command...');
  
  final Map<String, dynamic>? lastCommand = await CommandMemory.loadLastCommand();
  if (lastCommand == null) {
    print('Error: No previous command found.');
    return;
  }
  
  final String type = lastCommand['type'] as String;
  final Map<String, dynamic> params = lastCommand['parameters'] as Map<String, dynamic>;
  
  if (type == CommandMemory.typeHashGeneration) {
    // Run hash generation with saved parameters
    print('\nGenerate Set Hashes Configuration:');
    print('Set Code: ${params['setCode']}');
    print('Source: ${params['source']}');
    print('Parallelism: ${params['parallelism']}');
    print('Cleanup: ${params['cleanup'] ? 'Yes' : 'No'}');
    print('\nRunning hash generation...');
    
    final bool success = await HashGenerator.generateHashes(
      params['setCode'] as String,
      params['source'] as String,
      params['parallelism'] as int,
      params['cleanup'] as bool,
    );
    
    if (success) {
      print('Hash generation complete!');
    } else {
      print('Hash generation failed.');
    }
    
  } else if (type == CommandMemory.typeCardExtraction) {
    // Run card extraction with saved parameters
    print('\nExtract Cards Configuration:');
    print('Selected Set: ${params['selectedSet']}');
    print('Output Path: ${params['outputPath']}');
    print('Input Path: ${params['inputPath']}');
    print('Confidence Threshold: ${params['confidenceThreshold']}%');
    print('Save Debug Images: ${params['saveDebugImages'] ? 'Yes' : 'No'}');
    print('\nRunning card extraction...');
    
    final bool success = CardExtractor.extractCards(
      params['selectedSet'] as String,
      params['outputPath'] as String,
      params['inputPath'] as String,
      params['confidenceThreshold'] as int,
      params['saveDebugImages'] as bool,
    );
    
    if (success) {
      print('Card extraction complete!');
    } else {
      print('Card extraction failed.');
    }
  } else {
    print('Error: Unknown command type.');
  }
}

Future<void> _generateSetHashes() async {
  // Step 1: Ask for a setcode
  final String setCode =
      Input(
        prompt: 'Enter the set code (e.g., LEA, DSK):',
        validator: (value) {
          if (value.isEmpty) {
            return false;
          }
          return true;
        },
      ).interact();

  // Step 2: Select a source
  final int sourceIndex =
      Select(
        prompt: 'Select the source:',
        options: ['Scryfall', 'Local'],
      ).interact();
  final String source = sourceIndex == 0 ? 'Scryfall' : 'Local';

  // Step 3: Ask for parallelism
  final String parallelismInput =
      Input(
        prompt: 'Enter parallelism level (default: 10):',
        defaultValue: '10',
        validator: (value) {
          final int? intValue = int.tryParse(value);
          return intValue != null && intValue > 0;
        },
      ).interact();
  final int parallelism = int.parse(parallelismInput);

  // Step 4: Ask about cleanup
  final bool cleanup =
      Confirm(
        prompt: 'Cleanup/Delete temporary files after completion?',
        defaultValue: true,
      ).interact();

  // Display the settings and run
  print('\nGenerate Set Hashes Configuration:');
  print('Set Code: $setCode');
  print('Source: $source');
  print('Parallelism: $parallelism');
  print('Cleanup: ${cleanup ? 'Yes' : 'No'}');
  print('\nRunning hash generation...');

  // Save command to memory
  await CommandMemory.saveHashGenerationCommand(
    setCode: setCode,
    source: source,
    parallelism: parallelism,
    cleanup: cleanup,
  );

  // Run the hash generation with the configured parameters
  final bool success = await HashGenerator.generateHashes(
    setCode,
    source,
    parallelism,
    cleanup,
  );

  if (success) {
    print('Hash generation complete!');
  } else {
    print('Hash generation failed.');
  }
}

Future<void> _extractCards() async {
  // Step 1: Set selection
  final List<String> availableSets = ['All', 'LEA', 'DSK', 'Other'];
  final int setIndex =
      Select(
        prompt: 'Select a set:',
        options: availableSets,
      ).interact();
  final String selectedSet = availableSets[setIndex];

  // Step 2: Output path
  final String outputPath =
      Input(
        prompt: 'Enter output directory path:',
        defaultValue: './Out',
      ).interact();

  // Step 3: Input selection
  final String inputPath =
      Input(
        prompt: 'Enter input directory path:',
        defaultValue: './In',
      ).interact();

  // Step 4: Advanced options
  final bool showAdvanced =
      Confirm(
        prompt: 'Would you like to see advanced options?',
        defaultValue: false,
      ).interact();

  // Default advanced options
  int confidenceThreshold = 85;
  bool saveDebugImages = false;

  if (showAdvanced) {
    confidenceThreshold = AdvancedConfig.configureConfidenceThreshold();
    saveDebugImages = AdvancedConfig.configureDebugImageSaving();
  }

  // Display the settings and run
  print('\nExtract Cards Configuration:');
  print('Selected Set: $selectedSet');
  print('Output Path: $outputPath');
  print('Input Path: $inputPath');
  print('Advanced Options: ${showAdvanced ? 'Enabled' : 'Disabled'}');

  if (showAdvanced) {
    print('Confidence Threshold: $confidenceThreshold%');
    print('Save Debug Images: ${saveDebugImages ? 'Yes' : 'No'}');
  }

  print('\nRunning card extraction...');

  // Save command to memory
  await CommandMemory.saveCardExtractionCommand(
    selectedSet: selectedSet,
    outputPath: outputPath,
    inputPath: inputPath,
    confidenceThreshold: confidenceThreshold,
    saveDebugImages: saveDebugImages,
  );

  // Run the card extraction with the configured parameters
  final bool success = CardExtractor.extractCards(
    selectedSet,
    outputPath,
    inputPath,
    confidenceThreshold,
    saveDebugImages,
  );

  if (success) {
    print('Card extraction complete!');
  } else {
    print('Card extraction failed.');
  }
}
