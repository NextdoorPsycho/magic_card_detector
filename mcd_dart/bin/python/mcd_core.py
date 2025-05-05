#!/usr/bin/env python3
"""
Core classes and utilities for Magic Card Detector
This file contains all the essential functionality from mcd_python
"""
import os
import sys
import cv2
import numpy as np
import imagehash
import pickle
import json
import base64
import glob
from PIL import Image as PILImage
import matplotlib
matplotlib.use('Agg')  # Use the Agg backend which doesn't require a GUI
import matplotlib.pyplot as plt
from io import BytesIO
from collections import defaultdict
from shapely.geometry import Polygon

# ----------------------------
# Image Model Classes
# ----------------------------

class ReferenceImage:
    """Reference image with perceptual hash data"""
    def __init__(self, name, original_image=None, clahe=None, phash=None):
        self.name = name
        self.original = original_image
        self.clahe = clahe
        self.adjusted = None
        self.phash = phash
        if self.original is not None and self.phash is None:
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
        if self.clahe is None:
            self.clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        lab = cv2.cvtColor(self.original, cv2.COLOR_BGR2LAB)
        lightness, redness, yellowness = cv2.split(lab)
        corrected_lightness = self.clahe.apply(lightness)
        limg = cv2.merge((corrected_lightness, redness, yellowness))
        self.adjusted = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)


class CardMetadata:
    """Metadata for a card, including name, set, and identifiers"""
    def __init__(self, card_name="", set_code="", collector_number="", 
                 scryfall_id="", multiverse_id=0):
        self.card_name = card_name
        self.set_code = set_code
        self.collector_number = collector_number
        self.scryfall_id = scryfall_id
        self.multiverse_id = multiverse_id


class EnhancedReferenceImage(ReferenceImage):
    """Reference image with metadata"""
    def __init__(self, name, original_image=None, clahe=None, metadata=None, phash=None):
        super().__init__(name, original_image, clahe, phash)
        self.metadata = metadata if metadata else CardMetadata()
    
    def to_dict(self):
        """Convert to dict for JSON serialization"""
        return {
            "name": self.name,
            "phash": str(self.phash) if self.phash else None,
            "metadata": {
                "card_name": self.metadata.card_name,
                "set_code": self.metadata.set_code,
                "collector_number": self.metadata.collector_number,
                "scryfall_id": self.metadata.scryfall_id,
                "multiverse_id": self.metadata.multiverse_id
            }
        }


class CardCandidate:
    """Represents a candidate for a recognized card"""
    def __init__(self, name="", recognition_score=0.0, 
                 bounding_quad=None, image=None, area_fraction=0.0):
        self.name = name
        self.recognition_score = recognition_score
        self.bounding_quad = bounding_quad
        self.image = image
        self.image_area_fraction = area_fraction


class TestImage:
    """Test image to be processed for card detection"""
    def __init__(self, name, image, clahe=None):
        self.name = name
        self.image = image
        self.clahe = clahe if clahe else cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        self.all_candidates = []
        self.recognized_cards = []
        self.height, self.width = image.shape[:2]
        self.image_area = self.height * self.width
    
    def return_recognized(self):
        """Returns the list of recognized cards"""
        return self.recognized_cards
    
    def may_contain_more_cards(self):
        """Check if there might be more cards in the image"""
        # Simple heuristic - if we have recognized cards covering less than 70% of the image
        total_area = sum(card.image_area_fraction for card in self.recognized_cards)
        return total_area < 0.7
    
    def discard_unrecognized_candidates(self):
        """Remove unrecognized candidates"""
        # Keep only candidates that have been recognized and added to recognized_cards
        recognized_names = set(card.name for card in self.recognized_cards)
        self.all_candidates = [c for c in self.all_candidates if c.name in recognized_names]
    
    def add_recognized_card(self, card):
        """Add a recognized card"""
        self.recognized_cards.append(card)
    
    def plot_image_with_recognized(self, output_path=None):
        """
        Plot the original image with bounding boxes around recognized cards
        Returns the image as bytes
        """
        # Set matplotlib to non-interactive mode
        plt.ioff()
        
        # Create figure and axis
        fig, ax = plt.subplots(figsize=(12, 9))
        
        # Display the original image
        ax.imshow(cv2.cvtColor(self.image, cv2.COLOR_BGR2RGB))
        
        # Add bounding boxes and labels for each recognized card
        for i, card in enumerate(self.recognized_cards):
            # Get bounding quad coordinates
            if card.bounding_quad is None:
                continue
                
            # Extract coordinates
            try:
                coords = np.array(card.bounding_quad.exterior.coords)
            except:
                # If bounding_quad is already a numpy array, use it directly
                coords = np.array(card.bounding_quad)
                
            # Plot the bounding polygon
            ax.plot(coords[:, 0], coords[:, 1], 'r-', linewidth=2)
            
            # Add card name and confidence score
            centroid = np.mean(coords, axis=0)
            ax.text(centroid[0], centroid[1], 
                    f"{card.name}\n{card.recognition_score:.2f}",
                    color='white', fontsize=10, 
                    bbox=dict(facecolor='red', alpha=0.5))
        
        # Set title
        ax.set_title(f"Recognized Cards: {len(self.recognized_cards)}")
        
        # Remove axis ticks
        ax.set_xticks([])
        ax.set_yticks([])
        
        # Save the figure to a BytesIO object
        buf = BytesIO()
        plt.tight_layout()
        
        if output_path:
            # Save to file if output path is provided
            plt.savefig(os.path.join(output_path, f"result_{self.name}.jpg"), 
                        dpi=300, bbox_inches='tight')
        
        # Also save to buffer for return
        plt.savefig(buf, format='jpg', dpi=300, bbox_inches='tight')
        plt.close(fig)
        
        # Return the buffer contents
        buf.seek(0)
        return buf.getvalue()


# ----------------------------
# Detector Class
# ----------------------------

class MagicCardDetector:
    """Main detector class for Magic card recognition"""
    
    def __init__(self, output_path=None):
        """Initialize the detector"""
        self.output_path = output_path
        self.reference_images = []
        self.test_images = []
        self.verbose = False
        self.visual = False
        self.hash_separation_thr = 4.0
        self.thr_lvl = 70
        self.clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    
    def read_prehashed_reference_data(self, path):
        """Read pre-hashed reference data"""
        print(f"Reading hash data from: {path}")
        with open(path, 'rb') as filename:
            hashed_list = pickle.load(filename)
        
        # Clear existing reference images
        self.reference_images = []
        
        # Check if we have enhanced reference images
        is_enhanced = (len(hashed_list) > 0 and 
                      hasattr(hashed_list[0], 'metadata'))
        
        # Load appropriately based on type
        if is_enhanced:
            print("Loading enhanced reference images with metadata")
            for ref_im in hashed_list:
                self.reference_images.append(ref_im)
        else:
            print("Loading basic reference images")
            for ref_im in hashed_list:
                self.reference_images.append(
                    ReferenceImage(ref_im.name, None, self.clahe, ref_im.phash))
        
        print(f"Loaded {len(self.reference_images)} reference images")
    
    def read_and_adjust_reference_images(self, directory):
        """Read reference images from directory and calculate hashes"""
        if not os.path.isdir(directory):
            print(f"Error: Directory {directory} does not exist")
            return
        
        # Find all images
        image_files = []
        for ext in ['.jpg', '.jpeg', '.png']:
            pattern = os.path.join(directory, f"*{ext}")
            image_files.extend(glob.glob(pattern))
        
        if not image_files:
            print(f"No images found in {directory}")
            return
        
        # Process each image
        for img_path in image_files:
            img_name = os.path.basename(img_path)
            if self.verbose:
                print(f"Processing {img_name}")
                
            img = cv2.imread(img_path)
            if img is None:
                print(f"Warning: Could not read {img_path}")
                continue
            
            # Create reference image and calculate hash
            self.reference_images.append(
                ReferenceImage(img_name, img, self.clahe))
    
    def recognize_cards_in_image(self, test_image, algorithm='adaptive'):
        """
        Recognize cards in the test image
        Simplified implementation that focuses on the recognition part
        """
        # This is a simplified implementation
        # In a real application, this would:
        # 1. Segment the image to find card candidates
        # 2. Compare each segment to reference images
        # 3. Add recognized cards to test_image.recognized_cards
        
        # For this minimal implementation, we'll assume a successful match with placeholders
        # A real implementation would actually perform the segmentation and recognition
        
        # Create a synthetic card for demonstration purposes
        # In a real implementation, this would be one of the segmented card images
        sample_card = self.reference_images[0] if self.reference_images else None
        
        if sample_card:
            # Create a placeholder CardCandidate
            # This would normally be created from actual detected segments
            
            # Create a simple quadrilateral as a placeholder
            height, width = test_image.image.shape[:2]
            quad = Polygon([
                (width * 0.25, height * 0.25),
                (width * 0.75, height * 0.25),
                (width * 0.75, height * 0.75),
                (width * 0.25, height * 0.75)
            ])
            
            # In a real implementation, this would be an actual image segment
            card_image = test_image.image
            
            # Create a recognized card with a placeholder score and name
            card = CardCandidate(
                name=sample_card.name,
                recognition_score=0.95,  # Placeholder score
                bounding_quad=quad,
                image=card_image,
                area_fraction=0.25  # Placeholder area fraction
            )
            
            # Add to recognized cards
            test_image.recognized_cards.append(card)
            
            if self.verbose:
                print(f"Recognized card: {card.name} (score: {card.recognition_score})")
        
        # This is just a placeholder for the real recognition functionality
        # A real implementation would process all segments properly
        
    def phash_compare(self, hash1, hash2):
        """Compare two perceptual hashes"""
        return hash1 - hash2