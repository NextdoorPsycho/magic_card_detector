# Magic Card Detector - Dart Implementation

A Dart implementation of the Magic Card Detector, which detects and recognizes Magic: The Gathering cards in images.

## Features

- Card detection using contour detection and polygon approximation
- Card recognition using perceptual hashing (pHash)
- Support for different lighting conditions and card orientations
- Multiplatform support (thanks to Dart)
- Custom matrix operations and image transformations

## Prerequisites

- Dart SDK >= 3.7.2

## Installation

1. Clone the repository:

```bash
git clone https://github.com/NextdoorPsycho/magic_card_detector.git
cd magic-card-detector/mcd_dart
```

2. Install dependencies:

```bash
dart pub get
```

## Usage

### Generating Hash Database

Before using the detector, you need to generate a hash database from reference card images:

```bash
dart run lib/generate_hashes.dart -i /path/to/reference/cards -o assets/set_hashes/reference_phash.dat
```

Options:
- `-i, --input`: Directory containing reference card images (required)
- `-o, --output`: Path to output hash file (default: assets/set_hashes/alpha_reference_phash.dat)
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

### Command-line Interface

Process a single image or a directory of images:

```bash
# Process a single image
dart run lib/magic_card_detector.dart -i /path/to/image.jpg -o /path/to/output/dir -r assets/set_hashes/alpha_reference_phash.dat

# Process a directory of images
dart run lib/magic_card_detector.dart -i /path/to/image/dir -o /path/to/output/dir -r assets/set_hashes/alpha_reference_phash.dat
```

Options:
- `-i, --input`: Path to input image or directory (required)
- `-o, --output`: Path to output directory (default: assets/out)
- `-r, --reference`: Path to reference hash file (default: assets/set_hashes/alpha_reference_phash.dat)
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

## Using the Library

You can also use the Magic Card Detector as a library in your own Dart projects:

```dart
import 'dart:io';
import 'package:mcd_dart/mcd_dart.dart';

Future<void> main() async {
  // Initialize detector
  final detector = MagicCardDetector(outputPath: 'assets/out');
  
  // Load reference hash data
  await detector.readPrehashReferenceData('assets/set_hashes/alpha_reference_phash.dat');
  
  // Process an image
  final imageFile = File('path/to/image.jpg');
  final imageBytes = await imageFile.readAsBytes();
  final results = await detector.processImage(imageBytes, 'my_image.jpg');
  
  // Save results
  await File('original.jpg').writeAsBytes(results[0]);
  await File('annotated.jpg').writeAsBytes(results[1]);
}
```

## Library Structure

- `core/`: Core detector and recognition functionality
- `models/`: Data models for cards and images
- `geometry/`: Polygon and matrix transformation utilities
- `image/`: Image processing functions
- `utils/`: Utility functions and configuration

## Dependencies

- `args`: Command-line argument parsing
- `image`: Image processing and manipulation
- `path`: File path handling
- `collection`: Utility collections
- `fast_log`: Logging utilities
- `scryfall_api`: Used for looking up additional card data

## Custom Implementations

This Dart port includes several custom implementations of functionality that would normally be handled by libraries in Python:

- **Matrix Operations**: Custom Matrix4 and Vector4 classes for perspective transformations
- **Geometry**: Custom Point2D, Line, and Polygon classes
- **Image Processing**: Custom implementations of contour detection, thresholding, and image adjustments
- **Perceptual Hashing**: Custom implementation of perceptual image hashing

## License

This project is licensed under the MIT License.

## Acknowledgments

This is a Dart port of the original Magic Card Detector Python implementation.