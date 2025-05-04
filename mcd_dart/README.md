# Magic Card Detector - Dart Implementation

A Dart implementation of the Magic Card Detector, which detects and recognizes Magic: The Gathering cards in images.

## Features

- Card detection using contour detection and polygon approximation
- Card recognition using perceptual hashing (pHash)
- Support for different lighting conditions and card orientations
- Command-line interface for batch processing
- Web server with UI for uploading and processing images
- Hash database generation for reference cards

## Prerequisites

- Dart SDK >= 3.7.2

## Installation

1. Clone the repository:

```bash
git clone https://github.com/your-repo/magic-card-detector.git
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
dart run bin/generate_hashes.dart -i /path/to/reference/cards -o reference_phash.dat
```

Options:
- `-i, --input`: Directory containing reference card images (required)
- `-o, --output`: Path to output hash file (default: reference_phash.dat)
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

### Command-line Interface

Process a single image or a directory of images:

```bash
# Process a single image
dart run bin/magic_card_detector.dart -i /path/to/image.jpg -o /path/to/output/dir -r reference_phash.dat

# Process a directory of images
dart run bin/magic_card_detector.dart -i /path/to/image/dir -o /path/to/output/dir -r reference_phash.dat
```

Options:
- `-i, --input`: Path to input image or directory (required)
- `-o, --output`: Path to output directory (default: results)
- `-r, --reference`: Path to reference hash file (default: alpha_reference_phash.dat)
- `-v, --verbose`: Enable verbose output
- `-d, --visual`: Enable visualization (requires GUI)
- `-h, --help`: Show help message



Options:
- `-p, --port`: Port to listen on (default: 5001)
- `-h, --host`: Host to bind to (default: 0.0.0.0)
- `-r, --reference`: Path to reference hash file (default: alpha_reference_phash.dat)
- `-v, --verbose`: Enable verbose output
- `--help`: Show help message

After starting the server, open a browser and navigate to `http://localhost:5001/` to upload and process images.

## Using the Library

You can also use the Magic Card Detector as a library in your own Dart projects:

```dart
import 'dart:io';
import 'package:mcd_dart/mcd_dart.dart';

Future<void> main() async {
  // Initialize detector
  final detector = MagicCardDetector(outputPath: 'results');
  
  // Load reference hash data
  await detector.readPrehashReferenceData('reference_phash.dat');
  
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
- `geometry/`: Polygon and geometric transformation utilities
- `image/`: Image processing functions
- `utils/`: Utility functions and configuration

## Dependencies

- `args`: Command-line argument parsing
- `image`: Image processing and manipulation
- `path`: File path handling
- `image_compare`: Perceptual hashing for image comparison
- `geometry_kit`: Geometric operations on polygons

## License

This project is licensed under the same license as the original Python implementation.

## Acknowledgments

This is a Dart port of the original Python implementation by Timo Ikonen.