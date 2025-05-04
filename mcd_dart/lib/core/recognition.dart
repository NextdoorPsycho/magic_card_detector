import 'dart:math' as math;
import 'package:image/image.dart';

import '../models/image.dart';
import '../utils/image_hash.dart';

class RecognitionResult {
  final bool isRecognized;
  final double recognitionScore;
  final String cardName;
  
  RecognitionResult(this.isRecognized, this.recognitionScore, this.cardName);
}

List<double> phashDiff(List<ReferenceImage> referenceImages, ImageHash phashIm) {
  // Calculate the difference between the given hash and each reference image hash
  List<double> diff = List.filled(referenceImages.length, 0.0);
  
  for (int i = 0; i < referenceImages.length; i++) {
    // Calculate the hash distance
    if (referenceImages[i].phash != null) {
      diff[i] = phashIm.distanceTo(referenceImages[i].phash!);
    } else {
      diff[i] = double.infinity;
    }
  }
  
  return diff;
}

RecognitionResult phashCompare(
  Image imSeg, 
  List<ReferenceImage> referenceImages, 
  {double hashSeparationThr = 4.0, 
  bool verbose = false}
) {
  String cardName = 'unknown';
  bool isRecognized = false;
  double recognitionScore = 0.0;
  
  // Try different rotations
  List<double> rotations = [0.0, 90.0, 180.0, 270.0];
  
  List<double> d0Dist = List.filled(rotations.length, 0.0);
  List<List<double>> d0 = List.generate(
    referenceImages.length, 
    (_) => List.filled(rotations.length, 0.0)
  );
  
  for (int j = 0; j < rotations.length; j++) {
    // Apply rotation to the image
    Image rotatedImage;
    if (rotations[j].abs() > 1e-5) {
      rotatedImage = copyRotate(imSeg, angle: rotations[j].toInt());
    } else {
      rotatedImage = imSeg.clone();
    }
    
    // Calculate perceptual hash
    ImageHash phashIm = ImageHash.createPerceptualHash(rotatedImage);
    
    // Calculate differences with all reference images
    d0.asMap().forEach((i, row) {
      row[j] = phashDiff(referenceImages, phashIm)[i];
    });
    
    // Calculate statistical distance
    double minDiff = double.infinity;
    for (var row in d0) {
      if (row[j] < minDiff) {
        minDiff = row[j];
      }
    }
    
    // Create a list of differences excluding the minimum
    List<double> d0Filtered = [];
    for (var row in d0) {
      if (row[j] > minDiff) {
        d0Filtered.add(row[j]);
      }
    }
    
    // Calculate average and standard deviation
    double d0Ave = calculateAverage(d0Filtered);
    double d0Std = calculateStdDev(d0Filtered, d0Ave);
    
    // Calculate statistical distance
    d0Dist[j] = (d0Std > 0) ? (d0Ave - minDiff) / d0Std : 0;
    
    if (verbose) {
      print('Phash statistical distance: ${d0Dist[j]}');
    }
    
    // Check if this rotation gives the best recognition result
    if (d0Dist[j] > hashSeparationThr && 
        d0Dist.indexOf(d0Dist.reduce(math.max)) == j) {
      
      // Find index of minimum difference
      int minIndex = 0;
      double minVal = double.infinity;
      
      for (int i = 0; i < d0.length; i++) {
        if (d0[i][j] < minVal) {
          minVal = d0[i][j];
          minIndex = i;
        }
      }
      
      // Get card name from reference image
      String fullName = referenceImages[minIndex].name;
      cardName = fullName.contains('.jpg') 
          ? fullName.split('.jpg')[0] 
          : fullName;
      
      isRecognized = true;
      recognitionScore = d0Dist[j] / hashSeparationThr;
      break;
    }
  }
  
  return RecognitionResult(isRecognized, recognitionScore, cardName);
}

// Helper statistical functions
double calculateAverage(List<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

double calculateStdDev(List<double> values, double average) {
  if (values.isEmpty) return 0;
  double sumSquaredDiff = values.fold(0, (sum, val) => sum + math.pow(val - average, 2));
  return math.sqrt(sumSquaredDiff / values.length);
}