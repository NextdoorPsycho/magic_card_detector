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

Before using the detector, you need to generate a hash database from reference card images. You can generate multiple hash files, one for each Magic: The Gathering set you want to recognize:

#### From Local Card Images

```bash
# Generate hash for the Alpha set
dart run lib/generate_hashes.dart -i /path/to/alpha/cards -s alpha

# Generate hash for the Beta set
dart run lib/generate_hashes.dart -i /path/to/beta/cards -s beta

# Generate a custom hash with a specific output path
dart run lib/generate_hashes.dart -i /path/to/reference/cards -o assets/set_hashes/custom_set.dat
```

Options:
- `-i, --input`: Directory containing reference card images (required)
- `-o, --output`: Path to output hash file (default: assets/set_hashes/custom_reference_phash.dat)
- `-s, --set`: Set name (e.g., "alpha", "beta", "unlimited") (default: "custom")
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

#### From Scryfall Card Images (New!)

You can now generate hash databases directly from Scryfall by specifying a set code:

```bash
# Generate hash for the Duskmorne set
dart run bin/generate_hashes_from_scryfall.dart --set=DSK

# Generate hash for Lord of the Rings set with verbose output
dart run bin/generate_hashes_from_scryfall.dart --set=LTR --verbose

# Keep downloaded images for inspection
dart run bin/generate_hashes_from_scryfall.dart --set=MOM --keep-images
```

Options:
- `-s, --set`: Set code (e.g., "DSK", "LTR", "MOM") (required)
- `-o, --output`: Path to output hash file (default: assets/set_hashes/{set}_reference_phash.dat)
- `-t, --tempdir`: Temporary directory to store downloaded images (default: "temp_images")
- `--keep-images`: Keep downloaded images after hash generation (default: false)
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

For a complete list of set codes, visit [Scryfall Sets](https://scryfall.com/sets).

The tool will automatically create the proper directory structure if it doesn't exist.

### Command-line Interface

Process a single image or a directory of images:

```bash
# Process a single image with a specific hash set
dart run lib/magic_card_detector.dart -i /path/to/image.jpg -o /path/to/output/dir -r assets/set_hashes/alpha_reference_phash.dat

# Process a directory of images using all available set hashes
dart run lib/magic_card_detector.dart -i /path/to/image/dir -o /path/to/output/dir -a
```

Options:
- `-i, --input`: Path to input image or directory (required)
- `-o, --output`: Path to output directory (default: assets/out)
- `-r, --reference`: Path to reference hash file (default: assets/set_hashes/alpha_reference_phash.dat)
- `-a, --all-sets`: Load all available set hashes from the assets/set_hashes directory
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

### Using Multiple Card Sets

The Dart implementation can recognize cards from multiple Magic: The Gathering sets simultaneously. To do this, simply:

1. Add your hash files to the `assets/set_hashes` directory
2. Run the detector with the `-a` flag to load all available sets

Each hash file should be generated using the `generate_hashes.dart` tool and have a `.dat` extension.

## Using the Library

You can also use the Magic Card Detector as a library in your own Dart projects:

```dart
import 'dart:io';
import 'package:mcd_dart/mcd_dart.dart';

Future<void> main() async {
  // Initialize detector
  final detector = MagicCardDetector(outputPath: 'assets/out');
  
  // Option 1: Load a specific reference hash file
  await detector.readPrehashReferenceData('assets/set_hashes/alpha_reference_phash.dat');
  
  // Option 2: Load all available set hashes
  // await detector.loadAllSetHashes();
  
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
- `scryfall_api`: Used for looking up additional card data and downloading card images
- `http`: HTTP client for downloading images

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