#!/usr/bin/env python3
"""
Generate perceptual hashes for Magic card sets
This script is called from the Dart CLI to generate hash data
"""
import os
import sys
import argparse
import cv2
import numpy as np
import imagehash
from PIL import Image as PILImage
import pickle
from pathlib import Path

class ReferenceImage:
    """Reference image representation for perceptual hashing"""
    def __init__(self, name, original_image=None, clahe=None, phash=None):
        self.name = name
        self.original = original_image
        self.clahe = clahe
        self.adjusted = None
        self.phash = phash
        if self.original is not None:
            self.histogram_adjust()
            self.calculate_phash()

    def calculate_phash(self):
        """Calculate perceptual hash for the image"""
        self.phash = imagehash.phash(
            PILImage.fromarray(np.uint8(255 * cv2.cvtColor(
                self.adjusted, cv2.COLOR_BGR2RGB))),
            hash_size=32)

    def histogram_adjust(self):
        """Adjust image histogram for better recognition"""
        lab = cv2.cvtColor(self.original, cv2.COLOR_BGR2LAB)
        lightness, redness, yellowness = cv2.split(lab)
        corrected_lightness = self.clahe.apply(lightness)
        limg = cv2.merge((corrected_lightness, redness, yellowness))
        self.adjusted = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)


def generate_hashes(set_path, output_path, verbose=False):
    """
    Generate perceptual hashes for card images in the specified directory
    
    Args:
        set_path: Path to directory containing card images
        output_path: Path to save the hash data
        verbose: Whether to print verbose output
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Create CLAHE object for histogram adjustment
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        
        # Process image files
        print(f"Reading images from: {set_path}")
        reference_images = []
        
        # Get all jpg files
        image_files = list(Path(set_path).glob("*.jpg"))
        image_files.extend(list(Path(set_path).glob("*.png")))
        
        if not image_files:
            print(f"No jpg/png images found in {set_path}")
            return False
            
        print(f"Found {len(image_files)} images")
        
        # Process each image
        for file_path in image_files:
            if verbose:
                print(f"Processing {file_path}")
            
            # Read the image
            img = cv2.imread(str(file_path))
            if img is None:
                print(f"Warning: Could not read {file_path}")
                continue
                
            # Get image name
            img_name = file_path.name
            
            # Create reference image and calculate hash
            reference_images.append(
                ReferenceImage(img_name, img, clahe))
        
        # Create hash data
        hlist = []
        for image in reference_images:
            hlist.append(ReferenceImage(image.name, None, None, image.phash))
        
        # Create output directory if it doesn't exist
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Save hash data
        print(f"Saving hash data to {output_path}")
        with open(output_path, 'wb') as fhandle:
            pickle.dump(hlist, fhandle)
            
        print("Hash generation complete")
        return True
        
    except Exception as e:
        print(f"Error generating hashes: {e}")
        if verbose:
            import traceback
            traceback.print_exc()
        return False


def main():
    """Main function to parse arguments and run hash generation"""
    parser = argparse.ArgumentParser(
        description="Generate perceptual hashes for Magic card sets")
    parser.add_argument('--set-path', required=True,
                      help="Path to directory containing card images")
    parser.add_argument('--output', required=True,
                      help="Path to save the hash data")
    parser.add_argument('--verbose', action='store_true',
                      help="Enable verbose output")
    args = parser.parse_args()
    
    success = generate_hashes(args.set_path, args.output, args.verbose)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())