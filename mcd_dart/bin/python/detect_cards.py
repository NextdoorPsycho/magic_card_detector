#!/usr/bin/env python3
"""
MTG Card Detector CLI for integration with Dart CLI.
Detects and recognizes Magic: the Gathering cards in images.
"""

import os
import sys
import json
import argparse

# Add the lib/python directory to the Python path so we can import our modules
script_dir = os.path.dirname(os.path.abspath(__file__))
lib_path = os.path.abspath(os.path.join(script_dir, '..', '..', 'lib', 'python'))
sys.path.append(lib_path)

# Import our modules
from app import process_image

def main():
    """Command line interface for the card detector."""
    parser = argparse.ArgumentParser(
        description='Detect and recognize Magic: The Gathering cards in images.')
    
    parser.add_argument('--input-path', required=True,
                      help='Path to the input image or directory of images')
    parser.add_argument('--output-path', default='out',
                      help='Directory to save output images (default: "out")')
    parser.add_argument('--phash', 
                      help='Path to the reference hash file')
    parser.add_argument('--threshold', type=float, default=4.0,
                      help='Confidence threshold for matching (default: 4.0)')
    parser.add_argument('--debug-images', action='store_true',
                      help='Save debug images with detections')
    parser.add_argument('--verbose', action='store_true',
                      help='Enable verbose output')
    parser.add_argument('--json', action='store_true',
                      help='Output results as JSON')
    
    args = parser.parse_args()
    
    # Ensure output directory exists
    os.makedirs(args.output_path, exist_ok=True)
    
    # Process single image or directory
    results = []
    
    if os.path.isdir(args.input_path):
        # Process directory
        for filename in os.listdir(args.input_path):
            if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                image_path = os.path.join(args.input_path, filename)
                result = process_image(
                    image_path, 
                    args.output_path if args.debug_images else None,
                    args.phash,
                    args.threshold,
                    False,  # No visual display in CLI mode
                    args.verbose
                )
                if result:
                    results.append(result)
    else:
        # Process single image
        result = process_image(
            args.input_path, 
            args.output_path if args.debug_images else None,
            args.phash,
            args.threshold,
            False,  # No visual display in CLI mode
            args.verbose
        )
        if result:
            results.append(result)
    
    # Output results
    if args.json:
        # Output as JSON for easy parsing by Dart
        print(json.dumps(results))
    else:
        # Human-readable output
        print(f"\nProcessed {len(results)} images")
        for result in results:
            print(f"Image: {result['image_name']}")
            print(f"Cards found: {result['card_count']}")
            
            if result['card_count'] > 0:
                print("Recognized cards:")
                for card in result['cards']:
                    print(f"  - {card['name']} (confidence: {card['score']*100:.1f}%)")
            
            if 'result_image_path' in result and result['result_image_path']:
                print(f"Result image saved to: {result['result_image_path']}")
            print()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())