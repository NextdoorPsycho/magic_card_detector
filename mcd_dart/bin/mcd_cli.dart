import 'package:interact/interact.dart';
import 'dart:io';
import 'package:mcd_dart/cli/cli_exports.dart';

void main() {
  print('Magic Card Detector CLI');
  print('======================');

  final int mainSelection =
      Select(
        prompt: 'Select an operation:',
        options: ['Generate Set Hashes', 'Extract Cards', 'Exit'],
      ).interact();

  switch (mainSelection) {
    case 0:
      _generateSetHashes();
      break;
    case 1:
      _extractCards();
      break;
    case 2:
      print('Exiting...');
      exit(0);
  }
}

void _generateSetHashes() {
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

  // Run the hash generation with the configured parameters
  final bool success = HashGenerator.generateHashes(
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

void _extractCards() {
  // Step 1: Set selection
  final List<String> availableSets = ['All', 'LEA', 'DSK', 'Other'];
  final int setIndex =
      Select(
        prompt: 'Select a set (defaults to All):',
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
