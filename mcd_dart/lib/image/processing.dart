import 'package:image/image.dart';
import 'package:mcd_dart/mcd_dart.dart';
import 'dart:math' as math;

List<List<List<int>>> contourImageGray(Image fullImage, {String thresholding = 'adaptive'}) {
  // Convert to grayscale
  Image gray = grayscale(fullImage);
  
  // Apply thresholding
  Image thresh;
  
  if (thresholding == 'adaptive') {
    // Approximate adaptive thresholding
    int filterSize = 1 + 2 * (math.min(fullImage.width, fullImage.height) ~/ 20);
    thresh = adaptiveThreshold(gray, filterSize, 10);
  } else {
    // Simple thresholding
    thresh = threshold(gray, 70);
  }
  
  // Find contours
  return findContours(thresh);
}

List<List<List<int>>> contourImageRgb(Image fullImage) {
  // Split into RGB channels
  List<Image> channels = extractChannels(fullImage);
  
  // Apply histogram equalization and thresholding to each channel
  List<Image> thresholds = [];
  
  for (Image channelImage in channels) {
    
    // Apply clahe-like enhancement
    channelImage = adjustContrast(channelImage); 
    
    // Apply thresholding
    thresholds.add(threshold(channelImage, 110));
  }
  
  // Find contours in each threshold
  List<List<List<int>>> allContours = [];
  
  for (Image threshold in thresholds) {
    allContours.addAll(findContours(threshold));
  }
  
  return allContours;
}

List<List<List<int>>> contourImage(Image fullImage, {String mode = 'gray'}) {
  List<List<List<int>>> contours;
  
  if (mode == 'gray') {
    contours = contourImageGray(fullImage, thresholding: 'simple');
  } else if (mode == 'adaptive') {
    contours = contourImageGray(fullImage, thresholding: 'adaptive');
  } else if (mode == 'rgb') {
    contours = contourImageRgb(fullImage);
  } else if (mode == 'all') {
    contours = [
      ...contourImageGray(fullImage, thresholding: 'simple'),
      ...contourImageGray(fullImage, thresholding: 'adaptive'),
      ...contourImageRgb(fullImage)
    ];
  } else {
    throw ArgumentError('Unknown segmentation mode: $mode');
  }
  
  // Sort contours by area (largest first)
  contours.sort((List<List<int>> a, List<List<int>> b) => calculateContourArea(b).compareTo(calculateContourArea(a)));
  
  return contours;
}

void segmentImage(
  TestImage testImage, {
  String contouringMode = 'gray',
}) {
  // Create a copy of the adjusted image with memory optimization
  Image fullImage;
  try {
    // Memory optimization for large images before segmentation
    if (testImage.adjusted!.width > 2000 || testImage.adjusted!.height > 2000) {
      print('Large image detected. Optimizing memory for segmentation...');
      double scale = 2000 / (testImage.adjusted!.width > testImage.adjusted!.height 
                            ? testImage.adjusted!.width 
                            : testImage.adjusted!.height);
      fullImage = copyResize(
        testImage.adjusted!,
        width: (testImage.adjusted!.width * scale).floor(),
        height: (testImage.adjusted!.height * scale).floor(),
        interpolation: Interpolation.average
      );
    } else {
      fullImage = testImage.adjusted!.clone();
    }
  } catch (e) {
    print('Error preparing image for segmentation: $e');
    // Fallback to the original image but at lower resolution
    double scale = 1000 / (testImage.adjusted!.width > testImage.adjusted!.height 
                          ? testImage.adjusted!.width 
                          : testImage.adjusted!.height);
    fullImage = copyResize(
      testImage.adjusted!,
      width: (testImage.adjusted!.width * scale).floor(),
      height: (testImage.adjusted!.height * scale).floor(),
      interpolation: Interpolation.average
    );
    print('Using fallback lower resolution for segmentation.');
  }
  
  double imageArea = fullImage.width * fullImage.height.toDouble();
  double maxSegmentArea = 0.01; // Initial value for largest card area
  
  // Get contours using the specified mode - limit number of contours to avoid memory issues
  List<List<List<int>>> contours = contourImage(fullImage, mode: contouringMode);
  
  // Limit number of contours to process to avoid memory issues
  int maxContours = 50; // Reasonable limit
  if (contours.length > maxContours) {
    print('Limiting contour processing to $maxContours contours to conserve memory.');
    contours = contours.sublist(0, maxContours);
  }
  
  // Process each contour to find card candidates
  int processedContours = 0;
  for (List<List<int>> cardContour in contours) {
    try {
      // Periodically trigger garbage collection for large contour sets
      processedContours++;
      if (processedContours % 10 == 0) {
        // Force a pause to allow garbage collection
        print('Processed $processedContours contours...');
      }
      
      CardContourResult result = characterizeCardContour(
        cardContour,
        maxSegmentArea * imageArea,
        imageArea
      );
      
      if (!result.continueSegmentation) {
        break;
      }
      
      if (result.isCardCandidate && result.boundingPoly != null) {
        if (maxSegmentArea < 0.1) {
          maxSegmentArea = result.boundingPoly!.area() / imageArea;
        }
        
        // Apply perspective transform
        Polygon scaledPoly = scalePolygon(
          result.boundingPoly!, 
          result.cropFactor, 
          result.cropFactor
        );
        
        // Try to transform with memory optimization
        Image warped;
        try {
          warped = fourPointTransform(fullImage, scaledPoly);
        } catch (e) {
          print('Error in perspective transform: $e');
          // Try with a smaller region to avoid memory issues
          double scale = 0.9; // Slight reduction
          Polygon smallerPoly = scalePolygon(scaledPoly, scale, scale);
          warped = fourPointTransform(fullImage, smallerPoly);
        }
        
        // Add to candidate list
        testImage.candidateList.add(
          CardCandidate(
            warped,
            result.boundingPoly!,
            result.boundingPoly!.area() / imageArea
          )
        );
        
        // Limit to a reasonable number of candidates to avoid memory issues
        if (testImage.candidateList.length >= 15) {
          print('Reached maximum number of candidates (15). Stopping segmentation.');
          break;
        }
      }
    } catch (e) {
      print('Error processing contour: $e');
      continue;
    }
  }
}

// Helper functions

double calculateContourArea(List<List<int>> contour) {
  // Calculate the area of a contour using the Shoelace formula
  double area = 0.0;
  int n = contour.length;
  
  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    area += contour[i][0] * contour[j][1];
    area -= contour[j][0] * contour[i][1];
  }
  
  return (area.abs() / 2.0);
}

List<List<List<int>>> findContours(Image binaryImage) {
  // A simplified contour detection algorithm
  // For real applications, a more sophisticated algorithm would be needed
  
  // Create a copy for flood-fill operations
  Image labelImage = Image(width: binaryImage.width, height: binaryImage.height);
  
  int currentLabel = 1;
  List<List<List<int>>> contours = [];
  
  // Find connected components
  for (int y = 1; y < binaryImage.height - 1; y++) {
    for (int x = 1; x < binaryImage.width - 1; x++) {
      if (getBrightness(binaryImage.getPixel(x, y)) > 127 &&
          getBrightness(labelImage.getPixel(x, y)) == 0) {
        // New component found, assign a label
        List<List<int>> contour = [];
        floodFill(binaryImage, labelImage, x, y, currentLabel, contour);
        
        // Only add contours with enough points
        if (contour.length >= 5) {
          contours.add(contour);
          currentLabel++;
        }
      }
    }
  }
  
  // Approximate contours (reduce number of points)
  List<List<List<int>>> approximatedContours = [];
  for (List<List<int>> contour in contours) {
    approximatedContours.add(approximateContour(contour));
  }
  
  return approximatedContours;
}

void floodFill(Image source, Image labelImage, int x, int y, int label, List<List<int>> contour) {
  // Simple 4-connected flood fill
  List<List<int>> stack = [[x, y]];
  bool isContourPoint = false;
  
  while (stack.isNotEmpty) {
    List<int> point = stack.removeLast();
    int px = point[0];
    int py = point[1];
    
    // Check if already labeled or not a foreground pixel
    if (px < 0 || py < 0 || px >= source.width || py >= source.height ||
        getBrightness(labelImage.getPixel(px, py)) != 0 ||
        getBrightness(source.getPixel(px, py)) <= 127) {
      continue;
    }
    
    // Label this pixel
    labelImage.setPixel(px, py, getColor(label, label, label, 255));
    
    // Check if this is a boundary pixel
    isContourPoint = false;
    if (px == 0 || py == 0 || px == source.width - 1 || py == source.height - 1) {
      isContourPoint = true;
    } else {
      // Check 4-connected neighbors
      if (getBrightness(source.getPixel(px - 1, py)) <= 127 ||
          getBrightness(source.getPixel(px + 1, py)) <= 127 ||
          getBrightness(source.getPixel(px, py - 1)) <= 127 ||
          getBrightness(source.getPixel(px, py + 1)) <= 127) {
        isContourPoint = true;
      }
    }
    
    if (isContourPoint) {
      contour.add([px, py]);
    }
    
    // Add 4-connected neighbors to stack
    stack.add([px + 1, py]);
    stack.add([px - 1, py]);
    stack.add([px, py + 1]);
    stack.add([px, py - 1]);
  }
}


List<List<int>> approximateContour(List<List<int>> contour) {
  // Simple Douglas-Peucker-like algorithm to reduce contour points
  if (contour.length <= 5) return contour;
  
  double epsilon = 2.0; // Approximation precision
  List<List<int>> result = [];
  
  // Find the point with the maximum distance
  int start = 0;
  int end = contour.length - 1;
  
  result.add(contour[start]);
  
  douglasPeucker(contour, start, end, epsilon, result);
  
  result.add(contour[end]);
  
  return result;
}

void douglasPeucker(
  List<List<int>> contour, 
  int start, 
  int end, 
  double epsilon, 
  List<List<int>> result
) {
  // Base case
  if (end <= start + 1) {
    return;
  }
  
  double dmax = 0;
  int index = 0;
  
  // Line from start to end
  List<int> startPoint = contour[start];
  List<int> endPoint = contour[end];
  
  // Find the point with max distance from line
  for (int i = start + 1; i < end; i++) {
    double d = perpendicularDistance(contour[i], startPoint, endPoint);
    if (d > dmax) {
      index = i;
      dmax = d;
    }
  }
  
  // If max distance is greater than epsilon, recursively simplify
  if (dmax > epsilon) {
    douglasPeucker(contour, start, index, epsilon, result);
    result.add(contour[index]);
    douglasPeucker(contour, index, end, epsilon, result);
  }
}

double perpendicularDistance(List<int> point, List<int> lineStart, List<int> lineEnd) {
  // Calculate perpendicular distance from point to line
  double dx = lineEnd[0].toDouble() - lineStart[0].toDouble();
  double dy = lineEnd[1].toDouble() - lineStart[1].toDouble();
  
  // Normalize
  double mag = math.sqrt(dx * dx + dy * dy);
  if (mag < 1e-10) {
    return math.sqrt(math.pow(point[0].toDouble() - lineStart[0].toDouble(), 2) + 
                    math.pow(point[1].toDouble() - lineStart[1].toDouble(), 2));
  }
  
  dx /= mag;
  dy /= mag;
  
  // Perpendicular distance
  double pvx = point[0].toDouble() - lineStart[0].toDouble();
  double pvy = point[1].toDouble() - lineStart[1].toDouble();
  
  // Dot product
  double pvdot = dx * pvx + dy * pvy;
  
  // Scale line direction
  double dsx = pvdot * dx;
  double dsy = pvdot * dy;
  
  // Perpendicular vector
  double ax = pvx - dsx;
  double ay = pvy - dsy;
  
  return math.sqrt(ax * ax + ay * ay);
}

Image adaptiveThreshold(Image image, int blockSize, int c) {
  // Approximate adaptive thresholding
  Image result = Image(width: image.width, height: image.height);
  
  // Create an integral image
  List<List<int>> integral = List.generate(
    image.height + 1,
    (int i) => List.filled(image.width + 1, 0),
  );
  
  // Fill integral image
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int pixel = getBrightness(image.getPixel(x, y));
      integral[y + 1][x + 1] = pixel + 
                             integral[y][x + 1] + 
                             integral[y + 1][x] - 
                             integral[y][x];
    }
  }
  
  // Apply thresholding
  int radius = blockSize ~/ 2;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Define block bounds
      int x1 = math.max(0, x - radius);
      int y1 = math.max(0, y - radius);
      int x2 = math.min(image.width - 1, x + radius);
      int y2 = math.min(image.height - 1, y + radius);
      
      // Count pixels in block
      int count = (x2 - x1 + 1) * (y2 - y1 + 1);
      
      // Sum using integral image
      int sum = integral[y2 + 1][x2 + 1] - 
               integral[y2 + 1][x1] - 
               integral[y1][x2 + 1] + 
               integral[y1][x1];
      
      // Calculate local threshold
      int threshold = (sum ~/ count) - c;
      
      // Apply threshold
      int pixel = getBrightness(image.getPixel(x, y));
      if (pixel > threshold) {
        result.setPixel(x, y, getColor(255, 255, 255, 255));
      } else {
        result.setPixel(x, y, getColor(0, 0, 0, 255));
      }
    }
  }
  
  return result;
}

List<Image> extractChannels(Image image) {
  // Extract RGB channels
  int width = image.width;
  int height = image.height;
  
  Image red = Image(width: width, height: height);
  Image green = Image(width: width, height: height);
  Image blue = Image(width: width, height: height);
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      Pixel pixel = image.getPixel(x, y);
      red.setPixel(x, y, getColor(getRed(pixel), 0, 0, 255));
      green.setPixel(x, y, getColor(0, getGreen(pixel), 0, 255));
      blue.setPixel(x, y, getColor(0, 0, getBlue(pixel), 255));
    }
  }
  
  return [red, green, blue];
}

Image threshold(Image image, int thresholdValue) {
  // Create output image
  Image result = Image(width: image.width, height: image.height);
  
  // Apply threshold to each pixel
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int brightness = getBrightness(image.getPixel(x, y));
      if (brightness > thresholdValue) {
        result.setPixel(x, y, getColor(255, 255, 255, 255));
      } else {
        result.setPixel(x, y, getColor(0, 0, 0, 255));
      }
    }
  }
  
  return result;
}

Image adjustContrast(Image image) {
  // Apply contrast enhancement (simplified CLAHE)
  Image result = image.clone();
  
  // For now, just return the original image until we implement contrast adjustment
  return result;
}

Polygon scalePolygon(Polygon polygon, double xfact, double yfact) {
  // Scale polygon about its centroid
  Point2D centroid = polygon.centroid();
  List<Point2D> newVertices = [];
  
  for (Point2D point in polygon.vertices) {
    double newX = centroid.x + xfact * (point.x - centroid.x);
    double newY = centroid.y + yfact * (point.y - centroid.y);
    newVertices.add(Point2D(newX, newY));
  }
  
  return Polygon(newVertices);
}