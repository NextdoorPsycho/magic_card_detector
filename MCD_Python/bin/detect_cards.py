#!/usr/bin/env python
"""
MTG Card Detector CLI tool.

This tool detects and recognizes Magic: the Gathering cards in images.
"""

import os
import argparse
import io
import cProfile
import pstats
from lib import MagicCardDetector


def main():
    """
    Main function for the MTG card detector CLI tool.
    """
    global profiler
    parser = argparse.ArgumentParser(
        description='Recognize Magic: the Gathering cards from images. ' +
                    'Author: Timo Ikonen, timo.ikonen(at)iki.fi')

    parser.add_argument('input_path',
                       help='Path containing the images to be analyzed')
    parser.add_argument('output_path',
                       help='Output path for the results')
    parser.add_argument('--phash', '-p', default='alpha_reference_phash.dat',
                       help='Pre-calculated phash reference file')
    parser.add_argument('--visual', '-v', action='store_true',
                       help='Run with visualization (shows images)')
    parser.add_argument('--verbose', '-d', action='store_true',
                       help='Run in verbose mode (detailed output)')
    parser.add_argument('--profile', action='store_true',
                       help='Run with profiling and print stats')
    parser.add_argument('--images', '-i', nargs='+',
                       help='Specific image filenames to process')
    parser.add_argument('--threshold', '-t', type=float, default=4.0,
                       help='Hash separation threshold (default: 4.0)')

    args = parser.parse_args()

    # Create the output path
    output_path = args.output_path.rstrip('/')
    if not os.path.exists(output_path):
        os.makedirs(output_path)

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
    card_detector.visual = args.visual
    card_detector.verbose = args.verbose
    card_detector.hash_separation_thr = args.threshold

    # Read the reference data
    try:
        card_detector.read_prehashed_reference_data(args.phash)
    except Exception as e:
        print(f"Error loading hash data: {e}")
        return 1

    # Read test images
    try:
        card_detector.read_and_adjust_test_images(args.input_path)
        if not card_detector.test_images:
            print(f"No images found in {args.input_path}")
            return 1
    except Exception as e:
        print(f"Error loading test images: {e}")
        return 1

    # If specific images are requested, find their indices
    image_indices = None
    if args.images:
        image_indices = []
        for image_name in args.images:
            found = False
            for i, test_image in enumerate(card_detector.test_images):
                if test_image.name == image_name or image_name in test_image.name:
                    image_indices.append(i)
                    found = True
            if not found:
                print(f"Warning: Image '{image_name}' not found.")

    # Start profiling if requested
    if args.profile:
        profiler = cProfile.Profile()
        profiler.enable()

    # Run the card detection and recognition
    try:
        card_detector.run_recognition(image_indices)
    except Exception as e:
        print(f"Error during card recognition: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1

    # Stop profiling and print results if requested
    if args.profile:
        profiler.disable()
        profiler.dump_stats('magic_card_detector.prof')
        profiler_stream = io.StringIO()
        sortby = pstats.SortKey.CUMULATIVE
        profiler_stats = pstats.Stats(
            profiler, stream=profiler_stream).sort_stats(sortby)
        profiler_stats.print_stats(20)
        print(profiler_stream.getvalue())

    return 0


if __name__ == "__main__":
    exit(main())