#!/usr/bin/env python3
"""
Magic Card Detector implementation
Direct port of the original algorithms from mcd_python
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
import math

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
            PILImage.fromarray(np.uint8(cv2.cvtColor(
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
        self.fragment = False  # Flag to mark fragments/duplicates


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
        
        # Preprocess image for better detection
        self.gray = cv2.cvtColor(self.image, cv2.COLOR_BGR2GRAY)
        self.blurred = cv2.GaussianBlur(self.gray, (5, 5), 0)
    
    def return_recognized(self):
        """Returns the list of recognized cards"""
        return [c for c in self.recognized_cards if not c.fragment]
    
    def may_contain_more_cards(self):
        """Check if there might be more cards in the image"""
        # Count non-fragment cards
        non_fragment_cards = len(self.return_recognized())
        
        # If we have less than 2 cards and have explored less than 70% of the image
        total_area = sum(c.image_area_fraction for c in self.recognized_cards if not c.fragment)
        return (non_fragment_cards < 2 or total_area < 0.7)
    
    def discard_unrecognized_candidates(self):
        """Remove unrecognized candidates and mark fragments"""
        # First mark fragments/duplicates
        self.mark_fragments()
        
        # Keep only candidates that have been recognized
        recognized_names = set(card.name for card in self.recognized_cards)
        self.all_candidates = [c for c in self.all_candidates if c.name in recognized_names]
    
    def mark_fragments(self):
        """Mark duplicate/fragment card detections"""
        if len(self.recognized_cards) <= 1:
            return
            
        # Sort by recognition score (highest first)
        sorted_cards = sorted(
            self.recognized_cards, 
            key=lambda c: c.recognition_score, 
            reverse=True
        )
        
        # Check for intersecting card detections
        for i, card1 in enumerate(sorted_cards):
            if card1.fragment:
                continue
                
            for card2 in sorted_cards[i+1:]:
                if card2.fragment:
                    continue
                    
                # Check if the two cards have significant overlap
                try:
                    intersection = card1.bounding_quad.intersection(card2.bounding_quad)
                    union = card1.bounding_quad.union(card2.bounding_quad)
                    overlap = intersection.area / union.area
                    
                    # If significant overlap, mark the lower-scored card as a fragment
                    if overlap > 0.5:
                        card2.fragment = True
                except Exception as e:
                    print(f"Error calculating overlap: {e}")
    
    def add_card_candidate(self, card):
        """Add a card candidate"""
        self.all_candidates.append(card)
    
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
        for i, card in enumerate(self.return_recognized()):
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
        ax.set_title(f"Recognized Cards: {len(self.return_recognized())}")
        
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
# Geometry Functions
# ----------------------------

def order_points(pts):
    """
    Order a list of 4 points in top-left, top-right, bottom-right, bottom-left order
    """
    # Initialize ordered coordinates
    rect = np.zeros((4, 2), dtype=np.float32)
    
    # Sort based on sum (smallest = top-left, largest = bottom-right)
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # top-left
    rect[2] = pts[np.argmax(s)]  # bottom-right
    
    # Sort based on difference (smallest = top-right, largest = bottom-left)
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # top-right
    rect[3] = pts[np.argmax(diff)]  # bottom-left
    
    return rect


def four_point_transform(image, pts):
    """
    Apply a perspective transform to an image based on four points
    """
    # Order points in top-left, top-right, bottom-right, bottom-left order
    rect = order_points(np.array(pts, dtype=np.float32))
    
    # Get width of output image
    # (maximum of bottom-right - bottom-left or top-right - top-left)
    widthA = np.sqrt(((rect[2][0] - rect[3][0]) ** 2) + ((rect[2][1] - rect[3][1]) ** 2))
    widthB = np.sqrt(((rect[1][0] - rect[0][0]) ** 2) + ((rect[1][1] - rect[0][1]) ** 2))
    width = max(int(widthA), int(widthB))
    
    # Get height of output image
    # (maximum of bottom-right - top-right or bottom-left - top-left)
    heightA = np.sqrt(((rect[2][0] - rect[1][0]) ** 2) + ((rect[2][1] - rect[1][1]) ** 2))
    heightB = np.sqrt(((rect[3][0] - rect[0][0]) ** 2) + ((rect[3][1] - rect[0][1]) ** 2))
    height = max(int(heightA), int(heightB))
    
    # Adjust for Magic card aspect ratio (63mm x 88mm)
    CARD_ASPECT_RATIO = 88.0 / 63.0
    if width > 0 and height > 0:
        current_ratio = height / width
        if abs(current_ratio - CARD_ASPECT_RATIO) > 0.2:
            if current_ratio > CARD_ASPECT_RATIO:
                # Too tall, adjust width
                width = int(height / CARD_ASPECT_RATIO)
            else:
                # Too wide, adjust height
                height = int(width * CARD_ASPECT_RATIO)
    
    # Define destination points in top-left, top-right, bottom-right, bottom-left order
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


def get_bounding_quad(contour):
    """
    Get the minimal quadrilateral that bounds a contour
    """
    # Approximate polygon
    epsilon = 0.02 * cv2.arcLength(contour, True)
    approx = cv2.approxPolyDP(contour, epsilon, True)
    
    # If we have 4 points already, use them
    if len(approx) == 4:
        return order_points(approx.reshape(4, 2))
    
    # Otherwise, use minimum area rectangle
    rect = cv2.minAreaRect(contour)
    box = cv2.boxPoints(rect)
    box = np.array(box, dtype=np.float32)
    
    # Return ordered points
    return order_points(box)


# ----------------------------
# Image Processing Functions
# ----------------------------

def phash_compare(hash1, hash2):
    """
    Compare two perceptual hashes and return distance
    Matches original implementation
    """
    if not hash1 or not hash2:
        return 100.0  # Large distance for missing hashes
    return hash1 - hash2


def segment_image_adaptive(image, min_card_area_fraction=0.005, max_card_area_fraction=0.98):
    """
    Segment an image to find potential card candidates using adaptive thresholding
    Matches original implementation
    """
    height, width = image.shape[:2]
    image_area = height * width
    min_card_area = min_card_area_fraction * image_area
    max_card_area = max_card_area_fraction * image_area
    
    # Convert to grayscale and blur
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    
    # Apply adaptive thresholding
    thresh = cv2.adaptiveThreshold(
        blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
        cv2.THRESH_BINARY, 11, 2
    )
    
    # Invert because we want to find white cards (black on white background)
    thresh = cv2.bitwise_not(thresh)
    
    # Find contours
    contours, hierarchy = cv2.findContours(
        thresh, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE
    )
    
    # Process contours
    card_contours = []
    for contour in contours:
        area = cv2.contourArea(contour)
        if area < min_card_area or area > max_card_area:
            continue
        
        # Get convex hull
        hull = cv2.convexHull(contour)
        
        # Card-like shape check: should be quadrilateral-ish
        epsilon = 0.02 * cv2.arcLength(hull, True)
        approx = cv2.approxPolyDP(hull, epsilon, True)
        if len(approx) < 4 or len(approx) > 8:
            continue
        
        # Get bounding quad
        quad_points = get_bounding_quad(hull)
        
        # Adjust for Magic card aspect ratio (63mm x 88mm)
        CARD_ASPECT_RATIO = 88.0 / 63.0
        
        # Calculate width and height
        w = max(
            np.linalg.norm(quad_points[1] - quad_points[0]),
            np.linalg.norm(quad_points[2] - quad_points[3])
        )
        h = max(
            np.linalg.norm(quad_points[3] - quad_points[0]),
            np.linalg.norm(quad_points[2] - quad_points[1])
        )
        
        # Skip if too narrow
        if w < 10 or h < 10:
            continue
        
        # Form factor check (should be close to Magic card proportions)
        ratio = h / w if w > 0 else 0
        if abs(ratio - CARD_ASPECT_RATIO) > 0.5:
            continue
        
        # Store the contour and hull for processing
        card_contours.append((contour, hull, quad_points))
    
    return card_contours


def segment_image_rgb(image, min_card_area_fraction=0.005, max_card_area_fraction=0.98):
    """
    Segment an image to find potential card candidates using RGB channel analysis
    Matches original implementation
    """
    height, width = image.shape[:2]
    image_area = height * width
    min_card_area = min_card_area_fraction * image_area
    max_card_area = max_card_area_fraction * image_area
    
    # Split image into BGR channels
    blue, green, red = cv2.split(image)
    
    # Apply CLAHE to each channel
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    blue_eq = clahe.apply(blue)
    green_eq = clahe.apply(green)
    red_eq = clahe.apply(red)
    
    # Threshold each channel
    _, blue_thresh = cv2.threshold(blue_eq, 110, 255, cv2.THRESH_BINARY)
    _, green_thresh = cv2.threshold(green_eq, 110, 255, cv2.THRESH_BINARY)
    _, red_thresh = cv2.threshold(red_eq, 110, 255, cv2.THRESH_BINARY)
    
    # Combine all channels
    combined = cv2.bitwise_or(blue_thresh, green_thresh)
    combined = cv2.bitwise_or(combined, red_thresh)
    
    # Clean up with morphological operations
    kernel = np.ones((5, 5), np.uint8)
    combined = cv2.morphologyEx(combined, cv2.MORPH_CLOSE, kernel)
    
    # Find contours
    contours, hierarchy = cv2.findContours(
        combined, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE
    )
    
    # Process contours (similar to adaptive method)
    card_contours = []
    for contour in contours:
        area = cv2.contourArea(contour)
        if area < min_card_area or area > max_card_area:
            continue
        
        # Get convex hull
        hull = cv2.convexHull(contour)
        
        # Card-like shape check: should be quadrilateral-ish
        epsilon = 0.02 * cv2.arcLength(hull, True)
        approx = cv2.approxPolyDP(hull, epsilon, True)
        if len(approx) < 4 or len(approx) > 8:
            continue
        
        # Get bounding quad
        quad_points = get_bounding_quad(hull)
        
        # Adjust for Magic card aspect ratio (63mm x 88mm)
        CARD_ASPECT_RATIO = 88.0 / 63.0
        
        # Calculate width and height
        w = max(
            np.linalg.norm(quad_points[1] - quad_points[0]),
            np.linalg.norm(quad_points[2] - quad_points[3])
        )
        h = max(
            np.linalg.norm(quad_points[3] - quad_points[0]),
            np.linalg.norm(quad_points[2] - quad_points[1])
        )
        
        # Skip if too narrow
        if w < 10 or h < 10:
            continue
        
        # Form factor check (should be close to Magic card proportions)
        ratio = h / w if w > 0 else 0
        if abs(ratio - CARD_ASPECT_RATIO) > 0.5:
            continue
        
        # Store the contour and hull for processing
        card_contours.append((contour, hull, quad_points))
    
    return card_contours


def extract_card_image(image, quad_points):
    """
    Extract a card from an image given its bounding quad points
    Matches original implementation
    """
    # Apply perspective transform
    warped = four_point_transform(image, quad_points)
    return warped


# ----------------------------
# Recognition Functions
# ----------------------------

def phash_recognition(card_image, reference_images, hash_separation_thr=4.0, verbose=False):
    """
    Recognize a card using perceptual hashing
    Matches original implementation
    """
    # Convert to PIL image
    pil_image = PILImage.fromarray(cv2.cvtColor(card_image, cv2.COLOR_BGR2RGB))
    
    # Generate hashes at 4 rotations
    hashes = []
    hashes.append(imagehash.phash(pil_image, hash_size=32))  # 0 degrees
    hashes.append(imagehash.phash(pil_image.rotate(90), hash_size=32))  # 90 degrees
    hashes.append(imagehash.phash(pil_image.rotate(180), hash_size=32))  # 180 degrees
    hashes.append(imagehash.phash(pil_image.rotate(270), hash_size=32))  # 270 degrees
    
    # Find best match across all rotations
    best_score = 100.0
    best_match = None
    best_distances = []
    
    # Compare against reference images
    for ref_image in reference_images:
        if not ref_image.phash:
            continue
            
        # Compare all rotations
        min_distance = min(phash_compare(h, ref_image.phash) for h in hashes)
        best_distances.append((min_distance, ref_image))
    
    # Sort distances (best/lowest first)
    best_distances.sort(key=lambda x: x[0])
    
    # If we have matches
    if best_distances:
        # Get best match and distance
        best_distance, best_match = best_distances[0]
        
        # Statistical analysis - compare to other distances
        if len(best_distances) > 1:
            other_distances = [d for d, _ in best_distances[1:]]
            avg_others = sum(other_distances) / len(other_distances)
            std_others = np.std(other_distances) if len(other_distances) > 1 else 1.0
            
            # Calculate separation (how distinct is this match from others)
            separation = (avg_others - best_distance) / std_others
            
            # Adjust to a 0-1 scale where 1 is perfect match
            normalized_score = min(1.0, max(0.0, separation / hash_separation_thr))
            
            if verbose:
                print(f"Match {best_match.name}: distance={best_distance:.2f}, " +
                      f"separation={separation:.2f}, score={normalized_score:.2f}")
            
            # If good enough match
            if separation > hash_separation_thr:
                return best_match, normalized_score
    
    # No good match found
    return None, 0.0


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
            print("Detected enhanced hash file with metadata")
            for ref_im in hashed_list:
                self.reference_images.append(ref_im)
        else:
            print("Detected standard hash file (without metadata)")
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
        Matches original implementation
        """
        if self.verbose:
            print(f"Processing image {test_image.name} with algorithm {algorithm}")
        
        # Check if we have reference images
        if not self.reference_images:
            print("No reference images loaded")
            return
        
        # Segment the image
        card_contours = []
        if algorithm == 'adaptive':
            card_contours = segment_image_adaptive(test_image.image)
        elif algorithm == 'rgb':
            card_contours = segment_image_rgb(test_image.image)
        else:
            print(f"Unknown algorithm: {algorithm}")
            return
        
        if self.verbose:
            print(f"Found {len(card_contours)} potential card contours")
        
        # Process each card contour
        for i, (contour, hull, quad_points) in enumerate(card_contours):
            try:
                # Extract card image
                card_image = extract_card_image(test_image.image, quad_points)
                
                # Skip if extraction failed
                if card_image is None or card_image.size == 0:
                    continue
                
                # Calculate area fraction
                contour_area = cv2.contourArea(contour)
                area_fraction = contour_area / (test_image.height * test_image.width)
                
                # Skip if too small
                if area_fraction < 0.01:
                    continue
                
                # Create polygon for the card
                poly_points = [(p[0], p[1]) for p in quad_points]
                card_polygon = Polygon(poly_points)
                
                # Recognize the card
                best_match, score = phash_recognition(
                    card_image, 
                    self.reference_images,
                    self.hash_separation_thr,
                    self.verbose
                )
                
                # If recognized
                if best_match and score > 0:
                    # Create a CardCandidate
                    card = CardCandidate(
                        name=best_match.name,
                        recognition_score=score,
                        bounding_quad=card_polygon,
                        image=card_image,
                        area_fraction=area_fraction
                    )
                    
                    # Add to test image's list
                    test_image.recognized_cards.append(card)
                    
                    if self.verbose:
                        print(f"Recognized card {i}: {best_match.name} with score {score:.3f}")
            
            except Exception as e:
                if self.verbose:
                    print(f"Error processing card contour {i}: {e}")
    
    def phash_compare(self, hash1, hash2):
        """Compare two perceptual hashes"""
        return phash_compare(hash1, hash2)