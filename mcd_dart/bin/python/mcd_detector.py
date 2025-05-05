#!/usr/bin/env python3
"""
Magic Card Detector implementation
Standalone version that doesn't require mcd_python
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
from shapely.geometry import box as shapely_box

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
        # If we have less than 70% of the image covered by recognized cards
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
# Image Processing Functions
# ----------------------------

def phash_compare(hash1, hash2):
    """Compare two perceptual hashes and return distance"""
    if not hash1 or not hash2:
        return 100.0  # Large distance for missing hashes
    return hash1 - hash2


def segment_image(image, algorithm='adaptive', min_card_area_fraction=0.005, max_card_area_fraction=0.98):
    """
    Segment an image to find potential card candidates
    
    Args:
        image: OpenCV image
        algorithm: Algorithm to use ('adaptive' or 'rgb')
        min_card_area_fraction: Minimum relative area for a card
        max_card_area_fraction: Maximum relative area for a card
        
    Returns:
        list of contours that might be cards
    """
    height, width = image.shape[:2]
    min_card_area = min_card_area_fraction * height * width
    max_card_area = max_card_area_fraction * height * width
    
    if algorithm == 'adaptive':
        # Use adaptive thresholding
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        thresh = cv2.adaptiveThreshold(blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                       cv2.THRESH_BINARY, 11, 2)
        # Invert because we want to find white cards
        thresh = cv2.bitwise_not(thresh)
        
    elif algorithm == 'rgb':
        # Use RGB channel differencing
        blue, green, red = cv2.split(image)
        # Magic cards are often lighter in the red channel
        red_strong = (red > green + 20) & (red > blue + 20)
        # Create binary mask
        thresh = np.zeros_like(red)
        thresh[red_strong] = 255
        thresh = thresh.astype(np.uint8)
        # Clean up with morphological operations
        kernel = np.ones((5, 5), np.uint8)
        thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
    else:
        raise ValueError(f"Unknown algorithm: {algorithm}")
    
    # Find contours in the thresholded image
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Filter contours by area and shape
    card_contours = []
    for contour in contours:
        area = cv2.contourArea(contour)
        
        # Skip if too small or too large
        if area < min_card_area or area > max_card_area:
            continue
            
        # Approximate the contour to simplify
        epsilon = 0.02 * cv2.arcLength(contour, True)
        approx = cv2.approxPolyDP(contour, epsilon, True)
        
        # Skip if not quadrilateral-ish (4-8 vertices)
        if len(approx) < 4 or len(approx) > 8:
            continue
            
        # If we have more than 4 vertices, use minimum area rectangle
        if len(approx) > 4:
            rect = cv2.minAreaRect(contour)
            box = cv2.boxPoints(rect)
            approx = np.array(box, dtype=np.int32)
        
        # Make sure it's convex
        if not cv2.isContourConvex(approx):
            continue
        
        # Add to possible card contours
        card_contours.append(approx)
    
    return card_contours


def extract_card_image(image, contour):
    """
    Extract a card from an image given its contour
    
    Args:
        image: OpenCV image
        contour: Card contour points
        
    Returns:
        Warped image of the card
    """
    # Use a standard Magic card aspect ratio (63mm x 88mm)
    CARD_ASPECT_RATIO = 88.0 / 63.0
    
    # Sort contour points to get top-left, top-right, bottom-right, bottom-left
    rect = np.zeros((4, 2), dtype=np.float32)
    
    # Reshape contour to a simple list of points
    pts = contour.reshape(contour.shape[0], 2)
    
    # Get the sum of points to find top-left and bottom-right
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # top-left
    rect[2] = pts[np.argmax(s)]  # bottom-right
    
    # Get the difference to find top-right and bottom-left
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # top-right
    rect[3] = pts[np.argmax(diff)]  # bottom-left
    
    # Now that we have the corners, set the output size
    width = int(max(
        np.linalg.norm(rect[0] - rect[1]),
        np.linalg.norm(rect[2] - rect[3])
    ))
    height = int(width * CARD_ASPECT_RATIO)
    
    # Define the destination points
    dst = np.array([
        [0, 0],
        [width - 1, 0],
        [width - 1, height - 1],
        [0, height - 1]
    ], dtype=np.float32)
    
    # Get the perspective transform and apply it
    M = cv2.getPerspectiveTransform(rect, dst)
    warped = cv2.warpPerspective(image, M, (width, height))
    
    return warped


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
        
        Args:
            test_image: TestImage object
            algorithm: Algorithm to use ('adaptive' or 'rgb')
        """
        if self.verbose:
            print(f"Processing image {test_image.name} with algorithm {algorithm}")
            
        # No reference images, no recognition
        if not self.reference_images:
            print("No reference images loaded, cannot recognize cards")
            return
            
        # Extract card contours
        contours = segment_image(test_image.image, algorithm)
        
        if self.verbose:
            print(f"Found {len(contours)} potential card contours")
            
        # Process each contour
        for i, contour in enumerate(contours):
            # Extract card image
            try:
                card_image = extract_card_image(test_image.image, contour)
            except Exception as e:
                if self.verbose:
                    print(f"Error extracting card image: {e}")
                continue
                
            # Create a polygon from the contour
            contour_points = contour.reshape(contour.shape[0], 2)
            card_polygon = Polygon(contour_points)
            
            # Calculate area fraction
            area_fraction = card_polygon.area / (test_image.height * test_image.width)
            
            # Skip if too small
            if area_fraction < 0.01:
                if self.verbose:
                    print(f"Skipping card {i}, too small ({area_fraction:.3f})")
                continue
                
            # Calculate perceptual hash for this card
            try:
                # Convert to PIL image for hashing
                card_pil = PILImage.fromarray(cv2.cvtColor(card_image, cv2.COLOR_BGR2RGB))
                card_hash = imagehash.phash(card_pil, hash_size=32)
            except Exception as e:
                if self.verbose:
                    print(f"Error calculating hash for card {i}: {e}")
                continue
                
            # Compare with reference images
            best_match = None
            best_score = 100.0  # Start with a high value (worse)
            
            for ref_image in self.reference_images:
                score = phash_compare(card_hash, ref_image.phash)
                
                if score < best_score:
                    best_score = score
                    best_match = ref_image
            
            # If we found a good match
            if best_match and best_score < self.hash_separation_thr:
                # Convert score to a 0-1 range (where 1 is best)
                normalized_score = 1.0 - (best_score / self.hash_separation_thr)
                
                # Create a CardCandidate
                card = CardCandidate(
                    name=best_match.name,
                    recognition_score=normalized_score,
                    bounding_quad=card_polygon,
                    image=card_image,
                    area_fraction=area_fraction
                )
                
                # Add to recognized cards
                test_image.recognized_cards.append(card)
                
                if self.verbose:
                    print(f"Recognized card {i}: {best_match.name} with score {normalized_score:.3f}")
    
    def phash_compare(self, hash1, hash2):
        """Compare two perceptual hashes"""
        return phash_compare(hash1, hash2)