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
  
  // Memory optimization - process rotations one at a time
  for (int j = 0; j < rotations.length; j++) {
    // Apply rotation to the image
    Image rotatedImage;
    try {
      if (rotations[j].abs() > 1e-5) {
        rotatedImage = copyRotate(imSeg, angle: rotations[j].toInt());
      } else {
        rotatedImage = imSeg.clone();
      }
      
      // Calculate perceptual hash
      ImageHash phashIm = ImageHash.createPerceptualHash(rotatedImage);
      
      // Free rotated image memory as soon as possible
      rotatedImage = Image(width: 1, height: 1); // Small dummy image
      
      // Calculate differences with all reference images
      List<double> diffs = phashDiff(referenceImages, phashIm);
      
      // Calculate statistical distance
      double minDiff = double.infinity;
      for (double diff in diffs) {
        if (diff < minDiff) {
          minDiff = diff;
        }
      }
      
      // Create a list of differences excluding the minimum
      List<double> d0Filtered = [];
      for (double diff in diffs) {
        if (diff > minDiff) {
          d0Filtered.add(diff);
        }
      }
      
      // Calculate average and standard deviation
      double d0Ave = calculateAverage(d0Filtered);
      double d0Std = calculateStdDev(d0Filtered, d0Ave);
      
      // Calculate statistical distance
      d0Dist[j] = (d0Std > 0) ? (d0Ave - minDiff) / d0Std : 0;
      
      if (verbose) {
        print('Phash statistical distance (rotation ${rotations[j]}°): ${d0Dist[j]}');
      }
      
      // Check if this rotation gives a good recognition result
      if (d0Dist[j] > hashSeparationThr) {
        // Find index of minimum difference
        int minIndex = 0;
        double minVal = double.infinity;
        
        for (int i = 0; i < diffs.length; i++) {
          if (diffs[i] < minVal) {
            minVal = diffs[i];
            minIndex = i;
          }
        }
        
        // Get card name from reference image
        String fullName = referenceImages[minIndex].name;
        String candidateName = fullName.contains('.jpg') 
            ? fullName.split('.jpg')[0] 
            : fullName;
        
        double candidateScore = d0Dist[j] / hashSeparationThr;
        
        // If this is the best rotation so far, or first recognition
        if (!isRecognized || candidateScore > recognitionScore) {
          isRecognized = true;
          recognitionScore = candidateScore;
          cardName = candidateName;
        }
      }
      
      // Force garbage collection for especially large reference sets
      if (referenceImages.length > 500) {
        print('Large reference set detected. Optimizing memory during recognition...');
      }
    } catch (e) {
      print('Error processing rotation ${rotations[j]}°: $e');
      continue;
    }
  }
  
  // One more check to see if we need to adjust recognition threshold
  if (verbose && isRecognized) {
    print('Recognized as $cardName with score $recognitionScore');
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