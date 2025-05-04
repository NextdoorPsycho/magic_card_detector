import 'dart:math' as math;
import 'package:image/image.dart';
import 'package:mcd_dart/image/processing.dart';

import 'card.dart';
import '../geometry/polygons.dart';
import '../utils/image_hash.dart';

class ReferenceImage {
  final String name;
  final Image? original;
  Image? adjusted;
  ImageHash? phash;

  ReferenceImage(this.name, this.original, {this.phash}) {
    if (original != null) {
      histogramAdjust();
      calculatePhash();
    }
  }

  void calculatePhash() {
    if (adjusted != null) {
      // Create a copy of the image to manipulate
      Image imgForHash = adjusted!.clone();
      
      // Convert to proper format for hashing
      phash = ImageHash.createPerceptualHash(imgForHash);
    }
  }

  void histogramAdjust() {
    if (original != null) {
      // Convert to LAB-like space for processing
      // This is an approximation as Dart doesn't have direct LAB conversion
      adjusted = adjustContrast(original!);
    }
  }
}

class TestImage {
  final String name;
  final Image original;
  Image? adjusted;
  ImageHash? phash;
  bool visual = false;
  List<CardCandidate> candidateList = [];

  TestImage(this.name, this.original) {
    histogramAdjust();
  }

  void histogramAdjust() {
    // Apply contrast enhancement as a substitute for CLAHE
    adjusted = adjustContrast(original);
  }

  void markFragments() {
    // Find duplicates and mark one as fragment
    for (int i = 0; i < candidateList.length; i++) {
      for (int j = 0; j < candidateList.length; j++) {
        CardCandidate candidate = candidateList[i];
        CardCandidate otherCandidate = candidateList[j];
        
        if (candidate.isFragment || otherCandidate.isFragment) {
          continue;
        }
        
        if ((candidate.isRecognized || otherCandidate.isRecognized) && 
            i != j) {
          // Calculate intersection area
          Polygon? intersection = candidate.boundingQuad.intersection(otherCandidate.boundingQuad);
          if (intersection == null) continue;
          
          double iArea = intersection.area();
          double minArea = math.min(candidate.boundingQuad.area(), otherCandidate.boundingQuad.area());
          
          if (iArea > 0.5 * minArea) {
            if (candidate.isRecognized && otherCandidate.isRecognized) {
              if (candidate.recognitionScore < otherCandidate.recognitionScore) {
                candidate.isFragment = true;
              } else {
                otherCandidate.isFragment = true;
              }
            } else {
              if (candidate.isRecognized) {
                otherCandidate.isFragment = true;
              } else {
                candidate.isFragment = true;
              }
            }
          }
        }
      }
    }
  }

  Image plotImageWithRecognized() {
    // Create a copy of the original for drawing
    Image result = original.clone();
    
    // Draw bounding quadrilateral and labels for each recognized card
    for (CardCandidate candidate in candidateList) {
      if (!candidate.isFragment) {
        // Draw the bounding quadrilateral
        drawPolygon(result, candidate.boundingQuad, colorGreen);
        
        // Add a label with the card name
        Point2D center = candidate.boundingQuad.centroid();
        drawText(
          result,
          candidate.name,
          center.x.round(),
          center.y.round(),
          candidate.isRecognized ? colorWhite : colorRed,
        );
      }
    }
    
    return result;
  }

  List<CardCandidate> returnRecognized() {
    return candidateList
        .where((CardCandidate candidate) => candidate.isRecognized && !candidate.isFragment)
        .toList();
  }

  void discardUnrecognizedCandidates() {
    List<CardCandidate> recognized = returnRecognized();
    candidateList.clear();
    candidateList.addAll(recognized);
  }

  bool mayContainMoreCards() {
    List<CardCandidate> recognized = returnRecognized();
    
    if (recognized.isEmpty) {
      return true;
    }
    
    double totalArea = 0.0;
    double minArea = 1.0;
    
    for (CardCandidate card in recognized) {
      totalArea += card.imageAreaFraction;
      if (card.imageAreaFraction < minArea) {
        minArea = card.imageAreaFraction;
      }
    }
    
    return totalArea + 1.5 * minArea < 1.0;
  }
}


// Basic color definitions for drawing
final colorGreen = ColorRgb8(0, 255, 0);
final colorWhite = ColorRgb8(255, 255, 255);
final colorRed = ColorRgb8(255, 0, 0);

// Helper to draw a polygon on an image
void drawPolygon(Image image, Polygon polygon, ColorRgb8 color) {
  List<Point2D> vertices = polygon.vertices;
  for (int i = 0; i < vertices.length; i++) {
    Point2D start = vertices[i];
    Point2D end = vertices[(i + 1) % vertices.length];
    
    // Use the image package's drawLine function
    drawLine(
      image,
      x1: start.x.round(),
      y1: start.y.round(),
      x2: end.x.round(),
      y2: end.y.round(),
      color: color,
    );
  }
}

// Draw a basic string on an image
void drawText(Image image, String text, int x, int y, ColorRgb8 color) {
  int fontSize = 12;  // Approximate font size
  int textWidth = text.length * fontSize ~/ 2;
  
  // Draw a simple rectangle background
  ColorRgb8 bgColor = color == colorWhite 
      ? ColorRgb8(0, 0, 0) 
      : ColorRgb8(255, 255, 255);
  
  // Draw the background rectangle
  fillRect(
    image,
    x1: x - textWidth ~/ 2,
    y1: y - fontSize ~/ 2,
    x2: x + textWidth ~/ 2,
    y2: y + fontSize ~/ 2,
    color: bgColor,
  );
  
  // Draw the text in a simple way
  // Skip using font for now, since we'll just use simple rectangles
  
  // Center the text
  int startX = x - textWidth ~/ 2;
  int startY = y - fontSize ~/ 2;
  
  for (int i = 0; i < text.length; i++) {
    // Draw a simple colored rectangle for each character (simplified approach)
    fillRect(
      image,
      x1: startX + i * (fontSize ~/ 2),
      y1: startY,
      x2: startX + (i + 1) * (fontSize ~/ 2),
      y2: startY + fontSize,
      color: color,
    );
  }
}