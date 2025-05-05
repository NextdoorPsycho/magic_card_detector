#!/usr/bin/env python3
"""
Enhanced card detector for MTG cards, for Dart integration.

This tool detects and recognizes Magic: the Gathering cards in images
and includes additional metadata about the recognized cards.
"""

import os
import sys
import json
import argparse
import base64
import cv2
import numpy as np
import io
import pickle

# Set matplotlib to use a non-interactive backend before any other matplotlib imports
import matplotlib
matplotlib.use('Agg')  # Use the Agg backend which doesn't require a GUI

from PIL import Image

# Import from our local module
from mcd_detector import MagicCardDetector, TestImage, EnhancedReferenceImage

class EnhancedCardDetector:
    """
    Enhanced card detector class with rich metadata output
    """
    
    def __init__(self, hash_file_path, verbose=False, visual=False):
        """
        Initialize the detector with the given hash file.
        
        Args:
            hash_file_path: Path to the perceptual hash reference file
            verbose: Whether to print verbose output
            visual: Whether to display visualizations (for debugging)
        """
        self.detector = MagicCardDetector()
        self.detector.verbose = verbose
        self.detector.visual = visual
        
        # Set detection threshold
        self.detector.hash_separation_thr = 4.0  # Default
        
        # Read hash data
        try:
            self._load_enhanced_hashes(hash_file_path)
            print(f"Loaded {len(self.detector.reference_images)} reference images")
        except Exception as e:
            print(f"Error loading hash data: {e}")
            raise
            
    def _load_enhanced_hashes(self, hash_file_path):
        """
        Loads the enhanced hash data with metadata
        """
        print(f"Reading prehashed data from {hash_file_path}")
        with open(hash_file_path, 'rb') as f:
            hashed_list = pickle.load(f)
            
        # Check if we have enhanced reference images or regular ones
        if hashed_list and hasattr(hashed_list[0], 'metadata'):
            print("Detected enhanced hash file with metadata")
            self.is_enhanced = True
        else:
            print("Detected standard hash file (without metadata)")
            self.is_enhanced = False
            
        # Load reference images
        self.detector.reference_images = []
        for ref_im in hashed_list:
            self.detector.reference_images.append(ref_im)
            
    def detect_from_file(self, image_path, output_path=None, confidence_threshold=None):
        """
        Detect cards in the given image file.
        
        Args:
            image_path: Path to the image file
            output_path: Path to save result images
            confidence_threshold: Custom confidence threshold
            
        Returns:
            dict: Detection results in JSON-compatible format
        """
        if confidence_threshold is not None:
            self.detector.hash_separation_thr = confidence_threshold
            
        # Read the image
        image = cv2.imread(image_path)
        if image is None:
            return {"error": f"Could not read image: {image_path}"}
            
        # Process the image
        return self._process_image(image, os.path.basename(image_path), output_path)
        
    def detect_from_directory(self, directory_path, output_path=None, confidence_threshold=None):
        """
        Detect cards in all images in the given directory.
        
        Args:
            directory_path: Path to directory containing images
            output_path: Path to save result images
            confidence_threshold: Custom confidence threshold
            
        Returns:
            list: List of detection results for each image
        """
        if confidence_threshold is not None:
            self.detector.hash_separation_thr = confidence_threshold
            
        # Find all image files
        image_files = []
        for ext in ['.jpg', '.jpeg', '.png']:
            image_files.extend([
                os.path.join(directory_path, f) 
                for f in os.listdir(directory_path) 
                if f.lower().endswith(ext)
            ])
            
        if not image_files:
            return {"error": f"No image files found in: {directory_path}"}
            
        # Process each image
        results = []
        for image_path in image_files:
            image = cv2.imread(image_path)
            if image is not None:
                result = self._process_image(image, os.path.basename(image_path), output_path)
                results.append(result)
                
        return results
        
    def _process_image(self, cv_image, image_name, output_path=None):
        """
        Process a single OpenCV image and return results.
        
        Args:
            cv_image: OpenCV image
            image_name: Name of the image file
            output_path: Path to save result images
            
        Returns:
            dict: Detection results
        """
        # Create TestImage
        test_image = TestImage(image_name, cv_image, self.detector.clahe)
        
        # Try different algorithms
        for alg in ['adaptive', 'rgb']:
            self.detector.recognize_cards_in_image(test_image, alg)
            test_image.discard_unrecognized_candidates()
            if (not test_image.may_contain_more_cards() or 
                    len(test_image.return_recognized()) > 5):
                break
                
        # Generate result image if output path is specified
        result_image_path = None
        result_image_bytes = None
        if output_path:
            os.makedirs(output_path, exist_ok=True)
            result_image_path = os.path.join(
                output_path, 
                f"MTG_card_recognition_results_{image_name}"
            )
            
        # Generate annotated image
        result_image_bytes = test_image.plot_image_with_recognized(output_path)
        
        # Convert recognized cards to JSON-compatible format with metadata
        recognized_cards = []
        for card in test_image.return_recognized():
            # Convert bounding quad to flat list for JSON
            bquad_corners = np.asarray(card.bounding_quad.exterior.coords)[:-1]
            bquad_flat = bquad_corners.flatten().tolist()
            
            # Convert card image to base64 for transport
            _, buffer = cv2.imencode('.jpg', card.image)
            image_b64 = base64.b64encode(buffer).decode('utf-8')
            
            # Get raw card name without file extension
            raw_card_name = card.name.split('.jpg')[0]
            
            # Find corresponding reference image with metadata if available
            card_metadata = {}
            if self.is_enhanced:
                # First try exact match by name
                found_match = False
                
                for ref_img in self.detector.reference_images:
                    if hasattr(ref_img, 'metadata'):
                        # Check for direct name match
                        if raw_card_name == ref_img.metadata.card_name:
                            card_metadata = {
                                "card_name": ref_img.metadata.card_name,
                                "set_code": ref_img.metadata.set_code,
                                "collector_number": ref_img.metadata.collector_number,
                                "scryfall_id": ref_img.metadata.scryfall_id,
                                "multiverse_id": ref_img.metadata.multiverse_id
                            }
                            found_match = True
                            break
                
                # If no match, check for stored names with the double-underscore format
                if not found_match:
                    for ref_img in self.detector.reference_images:
                        ref_name = ref_img.name
                        # Check if the name contains the double-underscore format
                        if '__' in ref_name:
                            card_name_part = ref_name.split('__')[0]
                            if card_name_part and hasattr(ref_img, 'metadata'):
                                card_metadata = {
                                    "card_name": ref_img.metadata.card_name,
                                    "set_code": ref_img.metadata.set_code,
                                    "collector_number": ref_img.metadata.collector_number,
                                    "scryfall_id": ref_img.metadata.scryfall_id,
                                    "multiverse_id": ref_img.metadata.multiverse_id
                                }
                                # Use the part before __ as the display name
                                raw_card_name = card_name_part
                                break
            
            recognized_cards.append({
                "name": raw_card_name,
                "score": float(card.recognition_score),
                "area_fraction": float(card.image_area_fraction),
                "bounding_quad": bquad_flat,
                "image_b64": image_b64,
                "metadata": card_metadata
            })
            
        # Encode result image as base64
        result_b64 = base64.b64encode(result_image_bytes).decode('utf-8') if result_image_bytes else None
            
        # Return results as JSON-compatible dict
        return {
            "image_name": image_name,
            "card_count": len(recognized_cards),
            "cards": recognized_cards,
            "result_image_path": result_image_path,
            "result_image_b64": result_b64
        }


def main():
    """
    Command-line interface for the enhanced card detector.
    """
    parser = argparse.ArgumentParser(description='Enhanced MTG Card Detector with metadata')
    parser.add_argument('--input', required=True, help='Input image file or directory')
    parser.add_argument('--output', help='Output directory for results')
    parser.add_argument('--hash-file', required=True, help='Perceptual hash reference file')
    parser.add_argument('--threshold', type=float, default=4.0, help='Recognition confidence threshold')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    parser.add_argument('--visual', action='store_true', help='Show visualizations')
    
    args = parser.parse_args()
    
    try:
        # Initialize detector
        detector = EnhancedCardDetector(args.hash_file, args.verbose, args.visual)
        
        # Process input
        if os.path.isdir(args.input):
            results = detector.detect_from_directory(args.input, args.output, args.threshold)
        else:
            results = detector.detect_from_file(args.input, args.output, args.threshold)
            
        # Output JSON results
        print(json.dumps(results, indent=2))
        return 0
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        return 1
        
if __name__ == "__main__":
    sys.exit(main())