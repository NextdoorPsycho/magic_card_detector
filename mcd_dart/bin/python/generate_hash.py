#!/usr/bin/env python3
"""
Hash generation tool for MTG card detector, for Dart integration.

This tool generates perceptual hashes for a set of MTG card images
and saves them to a reference file.
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
    Main function for the hash generation tool.
    """
    parser = argparse.ArgumentParser(
        description='Generate perceptual hashes for MTG card images.')

    parser.add_argument('--set-path', '-p', required=True,
                      help='Path to the folder containing card images.')
    parser.add_argument('--output', '-o', required=True,
                      help='Output file path for the hash data.')
    parser.add_argument('--verbose', '-v', action='store_true',
                      help='Enable verbose output.')

    args = parser.parse_args()

    # Validate the set path
    set_path = args.set_path
    if not os.path.isdir(set_path):
        print(f"Error: Set path '{set_path}' is not a valid directory.")
        return 1
    
    # Add trailing slash if needed
    if not set_path.endswith('/'):
        set_path += '/'

    # Create the output directory if it doesn't exist
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created output directory: {output_dir}")

    print(f"Generating hashes for card images in {set_path}")
    print(f"Output will be saved to {args.output}")

    # Create detector and generate hashes
    detector = MagicCardDetector()
    detector.verbose = args.verbose
    
    # Load reference images and generate hashes
    try:
        print("Reading and processing card images...")
        detector.read_and_adjust_reference_images(set_path)
        
        if not detector.reference_images:
            print(f"No .jpg images found in {set_path}")
            return 1
            
        print(f"Found and processed {len(detector.reference_images)} images")
        
        # Export the hash data
        print("Generating and saving perceptual hashes...")
        detector.export_reference_data(args.output)
        print(f"Hash data successfully saved to {args.output}")
        
        return 0
    except Exception as e:
        print(f"Error generating hashes: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())