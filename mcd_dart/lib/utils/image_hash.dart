import 'package:image/image.dart';
// Import when needed
// import 'package:image_compare/image_compare.dart' as image_compare;

/// Custom wrapper for image perceptual hashing
class ImageHash {
  /// The internal hash value
  final BigInt hashValue;

  /// Creates a hash with the given value
  const ImageHash(this.hashValue);

  /// Creates a perceptual hash from an image
  factory ImageHash.createPerceptualHash(Image image) {
    // Use a more memory-efficient approach for processing, especially for large images
    // First, resize to a reasonable size to avoid memory issues during processing
    final int maxDimension = 1000;
    Image processImage = image;
    if (image.width > maxDimension || image.height > maxDimension) {
      double scale = maxDimension / (image.width > image.height ? image.width : image.height);
      processImage = copyResize(
        image, 
        width: (image.width * scale).floor(),
        height: (image.height * scale).floor(),
        interpolation: Interpolation.average
      );
    }
    
    // Now resize to the target size for the hash algorithm (match Python's 32x32)
    final resizedImage = copyResize(processImage, width: 32, height: 32, interpolation: Interpolation.average);
    
    // Convert to grayscale
    final grayImage = grayscale(resizedImage);
    
    // Calculate perceptual hash
    BigInt hash = _calculatePerceptualHash(grayImage);
    
    return ImageHash(hash);
  }

  /// Computes the Hamming distance between this hash and another hash
  double distanceTo(ImageHash other) {
    return _hammingDistance(hashValue, other.hashValue);
  }

  /// Hamming distance between two BigInts counts the number of bit positions that differ
  double _hammingDistance(BigInt a, BigInt b) {
    BigInt xor = a ^ b;
    int distance = 0;
    
    // Count the number of set bits (1s) in xor
    while (xor != BigInt.zero) {
      if (xor & BigInt.one == BigInt.one) {
        distance++;
      }
      xor = xor >> 1;
    }
    
    return distance.toDouble();
  }

  @override
  String toString() => 'ImageHash($hashValue)';
}

/// Calculates a perceptual hash value for an image
/// This implementation matches the Python version's 32x32 approach
BigInt _calculatePerceptualHash(Image image) {
  const int hashSize = 32; // Match Python's hash_size=32
  
  // Ensure image is grayscale and properly sized
  Image img = image;
  if (img.width != hashSize || img.height != hashSize) {
    img = copyResize(img, width: hashSize, height: hashSize, interpolation: Interpolation.average);
  }
  
  // Step 1: Compute the DCT (Discrete Cosine Transform) approximation with mean values
  // For simplicity and memory efficiency, we'll use a mean-based approach
  int sum = 0;
  for (int y = 0; y < hashSize; y++) {
    for (int x = 0; x < hashSize; x++) {
      sum += getBrightness(img.getPixel(x, y));
    }
  }
  int average = sum ~/ (hashSize * hashSize);
  
  // Step 2: Generate the hash bits based on whether pixels are above or below average
  // Use BigInt to handle the larger size (1024 bits for 32x32)
  BigInt hash = BigInt.zero;
  for (int y = 0; y < hashSize; y++) {
    for (int x = 0; x < hashSize; x++) {
      if (getBrightness(img.getPixel(x, y)) > average) {
        // Set the corresponding bit to 1
        hash = hash | (BigInt.one << (y * hashSize + x));
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