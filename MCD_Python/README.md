# MTG Card Detector

A Python tool for detecting and recognizing Magic: the Gathering cards in images.

## Description

This project provides a solution for automatically detecting and recognizing Magic: the Gathering cards from images. It leverages computer vision techniques for card segmentation and recognition. This is a refactored version of the original project with a more maintainable structure.

More details about the algorithms and examples can be found in the blog post: [https://tmikonen.github.io/quantitatively/2020-01-01-magic-card-detector/](https://tmikonen.github.io/quantitatively/2020-01-01-magic-card-detector/)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/mtg_card_detector.git
   cd mtg_card_detector
   ```

2. Install the package:
   ```bash
   pip install -e .
   ```

### Dependencies

MTG Card Detector requires Python 3.8 or newer. All dependencies are listed in `requirements.txt` and will be installed automatically when installing the package.

## Usage

### Command Line Interface

The refactored version provides a more flexible command-line interface.

#### Detecting Cards in Images

```bash
detect_cards.py <image_path> <output_path> [options]
```

**Examples:**

```bash
# Basic usage
detect_cards.py example results

# Process specific images with visualization
detect_cards.py example results --images dragon_whelp.jpg ruby.jpg --visual

# Adjust detection threshold
detect_cards.py example results --threshold 3.5

# Run with verbose output
detect_cards.py example results --verbose
```

#### Generating Hashes for Card Sets

To recognize cards, you need a reference hash file. The refactored version includes a separate tool for generating these hash files for different sets.

```bash
generate_hashes.py --set-path <path_to_set_images> --output <output_hash_file>
```

**Examples:**

```bash
# Generate hashes for a new set
generate_hashes.py --set-path images/modern_horizons/ --output modern_horizons_phash.dat

# Enable verbose output
generate_hashes.py --set-path images/modern_horizons/ --output modern_horizons_phash.dat --verbose
```

### Using as a Library

You can also use MTG Card Detector as a library in your own Python code:

```python
from lib import MagicCardDetector

# Initialize the detector
detector = MagicCardDetector(output_path='out')

# Load reference hashes
detector.read_prehashed_reference_data('alpha_reference_phash.dat')

# Load test images
detector.read_and_adjust_test_images('example')

# Run recognition
detector.run_recognition()
```

## Project Structure

The refactored project is organized into several modules:

```
mtg_card_detector/
├── core/            # Core detection and recognition functionality
├── geometry/        # Geometric operations for card detection
├── image/           # Image processing functions
├── models/          # Data classes for cards and images
└── utils/           # Utility functions and configuration

bin/
├── detect_cards.py  # CLI for card detection
└── generate_hashes.py  # CLI for hash generation
```

## License

This project is licensed under the [MIT License](LICENSE).