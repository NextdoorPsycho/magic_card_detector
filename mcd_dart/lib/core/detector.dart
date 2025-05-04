import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;

import 'package:image/image.dart';
import 'package:mcd_dart/mcd_dart.dart';
import 'package:path/path.dart' as path;

import '../models/image.dart';
// Import when needed
// import '../models/card.dart';
import '../image/processing.dart';
import '../utils/image_hash.dart';
import '../utils/config.dart';
import 'recognition.dart';

class MagicCardDetector {
  String? outputPath;
  List<ReferenceImage> referenceImages = [];
  List<TestImage> testImages = [];
  
  bool verbose = false;
  bool visual = false;
  
  double hashSeparationThr = 4.0;
  int thrLvl = 70;
  
  MagicCardDetector({this.outputPath});
  
  Future<void> exportReferenceData(String path) async {
    // Export the hash and card name data for future use
    List<Map<String, dynamic>> hashData = [];
    
    for (var image in referenceImages) {
      if (image.phash != null) {
        hashData.add({
          'name': image.name,
          'hash': image.phash!.hashValue,
        });
      }
    }
    
    final jsonData = jsonEncode(hashData);
    await File(path).writeAsString(jsonData);
  }
  
  Future<void> readPrehashReferenceData(String path) async {
    print('Reading prehashed data from $path');
    print('...');
    
    try {
      final content = await File(path).readAsString();
      final List<dynamic> data = jsonDecode(content);
      
      for (var item in data) {
        final hash = ImageHash(item['hash'] as int);
        referenceImages.add(
          ReferenceImage(item['name'], null, phash: hash)
        );
      }
      
      print('Done. Loaded ${referenceImages.length} reference cards from $path.');
    } catch (e) {
      print('Error reading reference data: $e');
      rethrow;
    }
  }
  
  /// Loads all available set hash files from the assets/set_hashes directory
  Future<void> loadAllSetHashes() async {
    print('Loading all available set hashes...');
    
    try {
      final hashFiles = Config.getAvailableSetHashes();
      
      if (hashFiles.isEmpty) {
        print('No hash files found in ${Config.getSetHashesDirectory()}');
        return;
      }
      
      int totalCards = 0;
      for (var file in hashFiles) {
        final initialCount = referenceImages.length;
        await readPrehashReferenceData(file.path);
        final newCards = referenceImages.length - initialCount;
        totalCards += newCards;
        print('Loaded $newCards cards from ${path.basename(file.path)}');
      }
      
      print('Total cards loaded from all set hashes: $totalCards');
    } catch (e) {
      print('Error loading set hashes: $e');
      rethrow;
    }
  }
  
  Future<void> readAndAdjustReferenceImages(String directory) async {
    print('Reading images from $directory');
    print('...');
    
    final Directory dir = Directory(directory);
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<File> imageFiles = entities
        .whereType<File>()
        .where((File file) => file.path.toLowerCase().endsWith('.jpg'))
        .toList();
    
    for (File file in imageFiles) {
      final Uint8List bytes = await file.readAsBytes();
      final Image? img = decodeImage(bytes);
      
      if (img != null) {
        final String name = path.basename(file.path);
        referenceImages.add(ReferenceImage(name, img));
      }
    }
    
    print('Done. Loaded ${referenceImages.length} reference cards.');
  }
  
  Future<void> readAndAdjustTestImages(String directory) async {
    print('Reading images from $directory');
    print('...');
    
    final int maxSize = 1000;
    
    final Directory dir = Directory(directory);
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<File> imageFiles = entities
        .whereType<File>()
        .where((File file) => file.path.toLowerCase().endsWith('.jpg'))
        .toList();
    
    for (File file in imageFiles) {
      final Uint8List bytes = await file.readAsBytes();
      Image? img = decodeImage(bytes);
      
      if (img != null) {
        // Resize if needed
        if (math.min(img.width, img.height) > maxSize) {
          final double scalef = maxSize / math.min(img.width, img.height);
          img = copyResize(
            img,
            width: (img.width * scalef).toInt(),
            height: (img.height * scalef).toInt(),
            interpolation: Interpolation.average
          );
        }
        
        final String name = path.basename(file.path);
        testImages.add(TestImage(name, img));
      }
    }
    
    print('Done. Loaded ${testImages.length} test images.');
  }
  
  RecognitionResult recognizeSegment(Image imageSegment) {
    // Wrapper for different recognition algorithms
    return phashCompare(
      imageSegment, 
      referenceImages,
      hashSeparationThr: hashSeparationThr,
      verbose: verbose
    );
  }
  
  void recognizeCardsInImage(TestImage testImage, String contouringMode) {
    print('Segmenting card candidates out of the image...');
    print('Using $contouringMode algorithm.');
    
    testImage.candidateList.clear();
    segmentImage(testImage, contouringMode: contouringMode);
    
    print('Done. Found ${testImage.candidateList.length} candidates.');
    print('Recognizing candidates.');
    
    for (int iCand = 0; iCand < testImage.candidateList.length; iCand++) {
      CardCandidate candidate = testImage.candidateList[iCand];
      
      if (verbose) {
        print('${iCand + 1} / ${testImage.candidateList.length}');
      }
      
      // Easy fragment / duplicate detection
      bool isFragment = false;
      for (CardCandidate otherCandidate in testImage.candidateList) {
        if (otherCandidate.isRecognized && !otherCandidate.isFragment) {
          if (otherCandidate.contains(candidate)) {
            candidate.isFragment = true;
            isFragment = true;
            break;
          }
        }
      }
      
      if (!isFragment) {
        // Recognize the segment
        final RecognitionResult result = recognizeSegment(candidate.image);
        candidate.isRecognized = result.isRecognized;
        candidate.recognitionScore = result.recognitionScore;
        candidate.name = result.cardName;
      }
    }
    
    print('Done. Found ${testImage.returnRecognized().length} cards.');
    if (verbose) {
      for (CardCandidate card in testImage.returnRecognized()) {
        print('${card.name}; S = ${card.recognitionScore}');
      }
    }
    
    print('Removing duplicates...');
    // Final fragment detection
    testImage.markFragments();
    print('Done.');
  }
  
  Future<List<Uint8List>> processImage(Uint8List imageBytes, String imageName) async {
    print('\n--- Processing Image: $imageName ---');
    
    // Decode the image
    final Image? image = decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Create a temporary TestImage
    final TestImage testImage = TestImage(imageName, image);
    
    // Try different algorithms
    final List<String> algList = ['adaptive', 'rgb'];
    
    for (String alg in algList) {
      recognizeCardsInImage(testImage, alg);
      testImage.discardUnrecognizedCandidates();
      
      // Stop if we've found enough cards or exhausted search potential
      if (!testImage.mayContainMoreCards() || 
          testImage.returnRecognized().length > 5) {
        break;
      }
    }
    
    // Generate result images
    print('Generating result images...');
    
    // Original image bytes
    final Uint8List originalBytes = encodeJpg(testImage.original);
    
    // Annotated image
    final Image annotatedImage = testImage.plotImageWithRecognized();
    final Uint8List annotatedBytes = encodeJpg(annotatedImage);
    
    print('Done.');
    
    // Return both images
    return [originalBytes, annotatedBytes];
  }
  
  Future<void> runRecognition([List<int>? imageIndices]) async {
    // The top-level image recognition method
    final List<int> indices = imageIndices ?? List<int>.generate(testImages.length, (int i) => i);
    
    for (int i in indices) {
      final TestImage testImage = testImages[i];
      print('Accessing image ${testImage.name}');
      
      if (visual) {
        print('Original image displayed');
      }
      
      final List<String> algList = ['adaptive', 'rgb'];
      
      for (String alg in algList) {
        recognizeCardsInImage(testImage, alg);
        testImage.discardUnrecognizedCandidates();
        
        if (!testImage.mayContainMoreCards() || 
            testImage.returnRecognized().length > 5) {
          break;
        }
      }
      
      print('Plotting and saving the results...');
      
      // Create annotated image
      final Image resultImage = testImage.plotImageWithRecognized();
      
      // Save to file if output path is provided
      if (outputPath != null) {
        final String fileName = testImage.name.contains('.jpg') 
            ? testImage.name.split('.jpg')[0] 
            : testImage.name;
        
        final String outFileName = path.join(
          outputPath!, 
          'MTG_card_recognition_results_$fileName.jpg'
        );
        
        final File outFile = File(outFileName);
        await outFile.writeAsBytes(encodeJpg(resultImage));
      }
      
      print('Done.');
      
      // Print recognized cards
      final List<CardCandidate> recognizedList = testImage.returnRecognized();
      print('Recognized cards (${recognizedList.length} cards):');
      for (CardCandidate card in recognizedList) {
        print('${card.name} - with score ${card.recognitionScore}');
      }
    }
    
    print('Recognition done.');
  }
}