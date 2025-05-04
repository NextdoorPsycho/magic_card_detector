import 'dart:io';
import 'package:mcd_dart/mcd_dart.dart';

/// Test script for loading multiple set hashes
void main() async {
  final detector = MagicCardDetector(outputPath: 'assets/out');
  
  // Test loading individual hash file
  await detector.readPrehashReferenceData(Config.getDefaultReferenceHashPath());
  print('Loaded ${detector.referenceImages.length} cards from default hash file');
  
  // Clear the reference images
  detector.referenceImages.clear();
  
  // Test loading all available set hashes
  await detector.loadAllSetHashes();
  print('Loaded ${detector.referenceImages.length} cards from all set hashes');
}