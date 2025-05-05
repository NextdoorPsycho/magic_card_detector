#!/usr/bin/env python3
"""
MTG Card Detector CLI tool for Dart integration.

This tool detects and recognizes Magic: the Gathering cards in images.
It's a wrapper around the mcd_python library functionality.
"""

import os
import sys
import argparse

# Set matplotlib to use a non-interactive backend before any other matplotlib imports
import matplotlib
matplotlib.use('Agg')  # Use the Agg backend which doesn't require a GUI

# Import from our local module
from mtg_detector import MagicCardDetector


def main():
    """
    Main function for the MTG card detector CLI tool.
    """
    parser = argparse.ArgumentParser(
        description='Recognize Magic: the Gathering cards from images.')

    parser.add_argument('--input-path', '-i', required=True,
                      help='Path containing the images to be analyzed')
    parser.add_argument('--output-path', '-o', required=True,
                      help='Output path for the results')
    parser.add_argument('--phash', '-p', required=True,
                      help='Pre-calculated phash reference file')
    parser.add_argument('--threshold', '-t', type=float, default=4.0,
                      help='Hash separation threshold (default: 4.0)')
    parser.add_argument('--debug-images', '-d', action='store_true',
                      help='Save debug images with detection information')
    parser.add_argument('--verbose', '-v', action='store_true',
                      help='Run in verbose mode (detailed output)')

    args = parser.parse_args()

    # Create the output path
    output_path = args.output_path.rstrip('/')
    if not os.path.exists(output_path):
        os.makedirs(output_path)
        print(f"Created output directory: {output_path}")
    else:
        print(f"Using existing output directory: {output_path}")

    # Check if input path exists
    if not os.path.isdir(args.input_path):
        print(f"Error: Input path '{args.input_path}' does not exist or is not a directory.")
        return 1

    # Check if hash file exists
    if not os.path.isfile(args.phash):
        print(f"Error: Hash file '{args.phash}' does not exist.")
        return 1

    # Instantiate the detector
    card_detector = MagicCardDetector(output_path)
    card_detector.visual = args.debug_images
    card_detector.verbose = args.verbose
    card_detector.hash_separation_thr = args.threshold

    print(f"Running card detection with threshold: {args.threshold}")

    # Read the reference data
    try:
        print(f"Loading hash data from {args.phash}...")
        card_detector.read_prehashed_reference_data(args.phash)
        print(f"Loaded {len(card_detector.reference_images)} reference cards")
    except Exception as e:
        print(f"Error loading hash data: {e}")
        return 1

    # Read test images
    try:
        print(f"Reading images from {args.input_path}...")
        card_detector.read_and_adjust_test_images(args.input_path)
        if not card_detector.test_images:
            print(f"No images found in {args.input_path}")
            return 1
        print(f"Found {len(card_detector.test_images)} images to process")
    except Exception as e:
        print(f"Error loading test images: {e}")
        return 1

    # Run the card detection and recognition
    try:
        print("Running card detection and recognition...")
        card_detector.run_recognition()
        print("Card detection completed successfully")
        
        # Print a summary of recognized cards for all images
        total_recognized = 0
        for test_image in card_detector.test_images:
            recognized = test_image.return_recognized()
            total_recognized += len(recognized)
            print(f"\nImage: {test_image.name}")
            print(f"Recognized {len(recognized)} cards:")
            for card in recognized:
                print(f"  - {card.name} (score: {card.recognition_score:.2f})")
                
        print(f"\nTotal recognized cards across all images: {total_recognized}")
        
        # Mention where results are saved
        print(f"\nAnnotated images have been saved to: {output_path}")
        
    except Exception as e:
        print(f"Error during card recognition: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())