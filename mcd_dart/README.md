# Magic Card Detector - Dart CLI

A command-line interface for the Magic Card Detector application, which can identify Magic: The Gathering cards from images. This CLI provides a bridge between the Dart application and Python image processing libraries.

## Features

- **Generate Set Hashes**: Generate perceptual hash data for card sets to use for matching
  - Support for Scryfall and local image sources
  - Configurable parallelism level
  - Option to clean up temporary files after completion

- **Extract Cards**: Detect and extract cards from input images
  - Set-specific recognition
  - Adjustable confidence threshold
  - Support for debug image output

## Prerequisites

- Dart SDK (version 3.7.2 or newer)
- Python 3.8 or newer
- Required Python libraries (install using `pip install -r requirements.txt`):
  - opencv-python
  - numpy
  - pillow
  - imagehash
  - scipy
  - shapely
  - matplotlib

## Installation

1. Clone the repository
2. Install Dart dependencies:
   ```
   dart pub get
   ```
3. Install Python dependencies:
   ```
   pip install -r requirements.txt
   ```

## Usage

Run the CLI using the provided shell script:

```
./run_cli.sh
```

### Generate Set Hashes

This workflow creates perceptual hash data for a card set:

1. Enter the set code (e.g., LEA, DSK)
2. Select the source (Scryfall or Local)
3. Set the parallelism level (default: 10)
4. Choose whether to clean up temporary files

The hash data will be stored in the `assets/set_hashes/` directory.

### Extract Cards

This workflow detects and extracts cards from images:

1. Select the set for recognition (or use "All")
2. Specify the output directory path
3. Specify the input directory path containing card images
4. Configure advanced options (optional):
   - Confidence threshold (50-100%)
   - Debug image saving

## Project Structure

- `bin/mcd_cli.dart`: Main CLI entry point
- `bin/generate_hash.py`: Python script for hash generation
- `bin/detect_cards.py`: Python script for card detection
- `lib/cli/`: Implementation of CLI functionality
- `assets/`: Input and output directories for images and hash data

## License

This project is licensed under the MIT License - see the LICENSE file for details.