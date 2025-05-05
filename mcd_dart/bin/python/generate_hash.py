#!/usr/bin/env python3
"""
MTG Card Hash Generator CLI for integration with Dart CLI.
Generates perceptual hash data for Magic: the Gathering cards.
"""

import os
import sys
import argparse

# Add the lib/python directory to the Python path so we can import our modules
script_dir = os.path.dirname(os.path.abspath(__file__))
lib_path = os.path.abspath(os.path.join(script_dir, '..', '..', 'lib', 'python'))
sys.path.append(lib_path)

# Import our modules
from save_hash import generate_hash

def main():
    """Command line interface for the hash generator."""
    parser = argparse.ArgumentParser(
        description='Generate perceptual hash data for Magic: The Gathering cards.')
    
    parser.add_argument('--set-path', required=True,
                      help='Path to the directory containing card images')
    parser.add_argument('--output', required=True,
                      help='Path to save the generated hash file')
    parser.add_argument('--verbose', action='store_true',
                      help='Enable verbose output')
    parser.add_argument('--store-names', action='store_true',
                      help='Store card names in the hash file')
    
    args = parser.parse_args()
    
    # Validate inputs
    if not os.path.exists(args.set_path):
        print(f"Error: Directory not found: {args.set_path}")
        return 1
        
    # Make sure the output directory exists
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    
    # Generate hash data
    success = generate_hash(args.set_path, args.output, args.verbose)
    
    if success:
        print(f"Successfully generated hash data and saved to: {args.output}")
    else:
        print("Failed to generate hash data.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())