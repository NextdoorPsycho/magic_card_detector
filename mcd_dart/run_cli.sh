#!/bin/bash
# Run the Magic Card Detector CLI

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "Dart SDK not found. Please install Dart."
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 not found. Please install Python 3."
    exit 1
fi

# Check for required Python libraries
echo "Checking for required Python libraries..."
python3 -c "
import sys
try:
    import cv2
    import numpy
    import imagehash
    from PIL import Image
    import pickle
    import scipy
    import matplotlib
    import shapely
    print('All required Python libraries are installed.')
except ImportError as e:
    print(f'Missing Python library: {e}')
    print('Please install the required libraries using:')
    print('pip install -r requirements.txt')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    exit 1
fi

# Run the CLI
echo "Starting Magic Card Detector CLI..."
dart run bin/mcd_cli.dart