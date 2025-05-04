import 'dart:math' as math;
import 'package:image/image.dart';
import 'polygons.dart'; // Import our custom Point2D and Polygon classes
import 'matrix.dart'; // Import our Matrix4 and Vector4 classes

// Color utility functions since the image package doesn't expose them directly
int getRed(Pixel pixel) => pixel.r.toInt();
int getGreen(Pixel pixel) => pixel.g.toInt();
int getBlue(Pixel pixel) => pixel.b.toInt();
int getAlpha(Pixel pixel) => pixel.a.toInt();
Color getColor(int r, int g, int b, int a) => ColorRgba8(r, g, b, a);

List<Point2D> orderPolygonPoints(List<Point2D> points) {
  // First calculate center
  double centerX = 0.0;
  double centerY = 0.0;
  for (var point in points) {
    centerX += point.x;
    centerY += point.y;
  }
  centerX /= points.length;
  centerY /= points.length;
  
  // Calculate angles of points relative to center
  List<Map<String, dynamic>> pointsWithAngles = [];
  for (var point in points) {
    double angle = math.atan2(point.y - centerY, point.x - centerX);
    pointsWithAngles.add({
      'point': point,
      'angle': angle
    });
  }
  
  // Sort by angle
  pointsWithAngles.sort((a, b) => a['angle'].compareTo(b['angle']));
  
  // Return sorted points
  return pointsWithAngles.map((p) => p['point'] as Point2D).toList();
}

Image fourPointTransform(Image image, Polygon quad) {
  // Get vertices from polygon
  List<Point2D> points = quad.vertices;
  
  // Order the points consistently
  points = orderPolygonPoints(points);
  
  // Compute width of new image (max distance between points horizontally)
  double widthA = points[1].distanceTo(points[0]);
  double widthB = points[2].distanceTo(points[3]);
  int maxWidth = math.max(widthA.toInt(), widthB.toInt());
  
  // Compute height of new image (max distance between points vertically)
  double heightA = points[3].distanceTo(points[0]);
  double heightB = points[2].distanceTo(points[1]);
  int maxHeight = math.max(heightA.toInt(), heightB.toInt());
  
  // Create perspective transform matrix
  List<double> sourcePoints = [];
  for (var point in points) {
    sourcePoints.add(point.x);
    sourcePoints.add(point.y);
  }
  
  List<double> destPoints = [
    0, 0,
    maxWidth - 1, 0,
    maxWidth - 1, maxHeight - 1,
    0, maxHeight - 1
  ];
  
  // Calculate the perspective transform matrix
  Matrix4 transform = getPerspectiveTransform(sourcePoints, destPoints);
  
  // Apply the perspective transformation
  return perspectiveTransform(image, transform, maxWidth, maxHeight);
}

// Calculates a perspective transform matrix
Matrix4 getPerspectiveTransform(List<double> src, List<double> dst) {
  // Source points
  final double x0 = src[0], y0 = src[1];
  final double x1 = src[2], y1 = src[3];
  final double x2 = src[4], y2 = src[5];
  final double x3 = src[6], y3 = src[7];
  
  // Destination points - change to lowerCamelCase to follow Dart conventions
  final double x0Dst = dst[0], y0Dst = dst[1];
  final double x1Dst = dst[2], y1Dst = dst[3];
  final double x2Dst = dst[4], y2Dst = dst[5];
  final double x3Dst = dst[6], y3Dst = dst[7];
  
  // Calculate coefficients for the system of equations
  final double a = (x1 - x2) * (y0 - y2) - (x0 - x2) * (y1 - y2);
  final double b = (x3 - x2) * (y0 - y2) - (x0 - x2) * (y3 - y2);
  final double c = x0Dst - x2Dst;
  final double d = x1Dst - x2Dst;
  final double e = x3Dst - x2Dst;
  final double f = y0Dst - y2Dst;
  final double g = y1Dst - y2Dst;
  final double h = y3Dst - y2Dst;
  
  // Solve for the transformation matrix parameters
  final double A = (a * e - b * d) / (a * h - b * g);
  final double B = (a * h - b * g != 0) ? (c * h - e * f) / (a * h - b * g) : 0;
  final double C = x2Dst;
  
  final double D = (a * h - b * g != 0) ? (d * h - e * g) / (a * h - b * g) : 0;
  final double E = (a * h - b * g != 0) ? (f * d - c * g) / (a * h - b * g) : 0;
  final double F = y2Dst;
  
  final double G = (a != 0) ? ((x0 - x2) * A + (y0 - y2) * D) / (x0 - x2) : 
                   (b != 0) ? ((x3 - x2) * A + (y3 - y2) * D) / (x3 - x2) : 0;
  final double H = (a != 0) ? ((x0 - x2) * B + (y0 - y2) * E) / (x0 - x2) : 
                   (b != 0) ? ((x3 - x2) * B + (y3 - y2) * E) / (x3 - x2) : 0;
  
  // Create homography matrix
  return Matrix4(
    A, D, 0, G,
    B, E, 0, H,
    0, 0, 1, 0,
    C, F, 0, 1
  );
}

// Apply perspective transform to an image
Image perspectiveTransform(Image src, Matrix4 transform, int width, int height) {
  // Create a new destination image with the specified dimensions
  Image dst = Image(width: width, height: height);
  
  try {
    // Compute inverse transform
    Matrix4 inverseTransform = Matrix4.clone(transform);
    inverseTransform.invert();
    
    // For each pixel in the destination image
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Apply inverse transform to get source coordinates
        Vector4 srcVec = inverseTransform.transform(Vector4(x.toDouble(), y.toDouble(), 0, 1));
        
        // Normalize homogeneous coordinates
        if (srcVec.w.abs() < 1e-10) {
          continue; // Skip if w is close to zero (avoid division by zero)
        }
        
        double srcX = srcVec.x / srcVec.w;
        double srcY = srcVec.y / srcVec.w;
        
        // Skip if out of bounds
        if (srcX < 0 || srcX >= src.width || srcY < 0 || srcY >= src.height) {
          continue;
        }
        
        // Bilinear interpolation to get the color at the source coordinates
        Color color = interpolateColor(src, srcX, srcY);
        
        // Set the pixel in the destination image
        dst.setPixel(x, y, color);
      }
    }
  } catch (e) {
    print('Error during perspective transform: $e');
    // Return a simple copy of the source image if transformation fails
    return src.clone();
  }
  
  return dst;
}

// Bilinear interpolation for color
Color interpolateColor(Image src, double x, double y) {
  // Get four surrounding pixel coordinates
  int x0 = x.floor();
  int y0 = y.floor();
  int x1 = math.min(x0 + 1, src.width - 1);
  int y1 = math.min(y0 + 1, src.height - 1);
  
  // Calculate interpolation weights
  double wx = x - x0;
  double wy = y - y0;
  
  // First try using the built-in image package interpolation
  try {
    return src.getPixelInterpolate(x, y);
  } catch (_) {
    try {
      // Try the older getPixelLinear method
      return src.getPixelLinear(x, y);
    } catch (_) {
      // Continue with manual interpolation
    }
  }
  
  // Fallback to manual interpolation if needed
  // Get colors of four surrounding pixels
  Pixel c00 = src.getPixel(x0, y0);
  Pixel c10 = src.getPixel(x1, y0);
  Pixel c01 = src.getPixel(x0, y1);
  Pixel c11 = src.getPixel(x1, y1);
  
  // Extract RGB components
  int r00 = getRed(c00), g00 = getGreen(c00), b00 = getBlue(c00), a00 = getAlpha(c00);
  int r10 = getRed(c10), g10 = getGreen(c10), b10 = getBlue(c10), a10 = getAlpha(c10);
  int r01 = getRed(c01), g01 = getGreen(c01), b01 = getBlue(c01), a01 = getAlpha(c01);
  int r11 = getRed(c11), g11 = getGreen(c11), b11 = getBlue(c11), a11 = getAlpha(c11);
  
  // Interpolate color components
  int r = (r00 * (1 - wx) * (1 - wy) + r10 * wx * (1 - wy) + r01 * (1 - wx) * wy + r11 * wx * wy).round();
  int g = (g00 * (1 - wx) * (1 - wy) + g10 * wx * (1 - wy) + g01 * (1 - wx) * wy + g11 * wx * wy).round();
  int b = (b00 * (1 - wx) * (1 - wy) + b10 * wx * (1 - wy) + b01 * (1 - wx) * wy + b11 * wx * wy).round();
  int a = (a00 * (1 - wx) * (1 - wy) + a10 * wx * (1 - wy) + a01 * (1 - wx) * wy + a11 * wx * wy).round();
  
  // Ensure values are within valid range
  r = math.min(255, math.max(0, r));
  g = math.min(255, math.max(0, g));
  b = math.min(255, math.max(0, b));
  a = math.min(255, math.max(0, a));
  
  // Combine components back to a color
  return getColor(r, g, b, a);
}