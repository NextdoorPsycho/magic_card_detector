import 'package:image/image.dart';
// Import when needed
// import 'package:image_compare/image_compare.dart' as image_compare;

/// Custom wrapper for image perceptual hashing
class ImageHash {
  /// The internal hash value
  final int hashValue;

  /// Creates a hash with the given value
  const ImageHash(this.hashValue);

  /// Creates a perceptual hash from an image
  factory ImageHash.createPerceptualHash(Image image) {
    // Resize image to 32x32 as required by the algorithm
    final resizedImage = copyResize(image, width: 32, height: 32);
    
    // Convert to grayscale
    final grayImage = grayscale(resizedImage);
    
    // Calculate pHash using the image_compare package's PerceptualHash algorithm
    // We need to generate a hash from the image
    // Note: Since image_compare package expects File objects normally,
    // we'll implement a simple perceptual hash calculation
    int hash = _calculatePerceptualHash(grayImage);
    
    return ImageHash(hash);
  }

  /// Computes the Hamming distance between this hash and another hash
  double distanceTo(ImageHash other) {
    return _hammingDistance(hashValue, other.hashValue);
  }

  /// Hamming distance between two integers counts the number of bit positions that differ
  double _hammingDistance(int a, int b) {
    int xor = a ^ b;
    int distance = 0;
    
    // Count the number of set bits (1s) in xor
    while (xor != 0) {
      if (xor & 1 == 1) {
        distance++;
      }
      xor >>= 1;
    }
    
    return distance.toDouble();
  }

  @override
  String toString() => 'ImageHash($hashValue)';
}

/// Calculates a perceptual hash value for an image
/// This is a simplified implementation of the pHash algorithm
int _calculatePerceptualHash(Image image) {
  const size = 8; // Final hash size (8x8)
  
  // Ensure image is grayscale and properly sized
  Image img = image;
  if (img.width != size || img.height != size) {
    img = copyResize(img, width: size, height: size);
  }
  
  // Calculate the average pixel value
  int sum = 0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      sum += getBrightness(img.getPixel(x, y));
    }
  }
  int average = sum ~/ (size * size);
  
  // Generate the hash bits based on whether pixels are above or below average
  int hash = 0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (getBrightness(img.getPixel(x, y)) > average) {
        // Set the corresponding bit to 1
        hash |= 1 << (y * size + x);
      }
    }
  }
  
  return hash;
}

/// Helper function to get brightness from a pixel
int getBrightness(Pixel pixel) {
  int r = pixel.r.toInt();
  int g = pixel.g.toInt();
  int b = pixel.b.toInt();
  return ((r + g + b) / 3).round();
}