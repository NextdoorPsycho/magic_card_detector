"""
Enhanced image classes for representing reference and test images.
These classes include additional metadata for the cards.
"""

# Set matplotlib to use a non-interactive backend before any other matplotlib imports
import matplotlib
matplotlib.use('Agg')  # Use the Agg backend which doesn't require a GUI

import cv2
import imagehash
import numpy as np
from PIL import Image as PILImage
from dataclasses import dataclass, field

@dataclass
class CardMetadata:
    """
    Stores metadata about a Magic card
    """
    card_name: str
    set_code: str = ""
    scryfall_id: str = ""
    collector_number: str = ""
    multiverse_id: int = 0
    
    def format_filename(self):
        """
        Creates a formatted filename from the metadata
        """
        return f"{self.card_name}_{self.set_code}_{self.collector_number}"

class EnhancedReferenceImage:
    """
    Enhanced container for a card image with additional metadata
    """
    
    def __init__(self, name, original_image, clahe, metadata=None, phash=None):
        """
        Initialize an enhanced reference image
        
        Args:
            name: Original filename
            original_image: OpenCV image
            clahe: CLAHE object for histogram adjustment
            metadata: CardMetadata object
            phash: Pre-computed perceptual hash
        """
        self.name = name
        self.original = original_image
        self.clahe = clahe
        self.adjusted = None
        self.phash = phash
        
        # Parse metadata from filename if not provided
        if metadata is None:
            self.metadata = self._parse_metadata_from_filename(name)
        else:
            self.metadata = metadata
            
        if self.original is not None:
            self.histogram_adjust()
            self.calculate_phash()
    
    def _parse_metadata_from_filename(self, filename):
        """
        Tries to extract metadata from the filename
        Format expected: CardName_SetCode_CollectorNumber.jpg
        If underscore format is not detected, just use the filename as card_name
        """
        # Remove file extension
        base_name = filename.split('.')[0]
        
        # Check if filename follows the expected pattern
        parts = base_name.split('_')
        
        if len(parts) >= 3:
            # Assume format is CardName_SetCode_CollectorNumber
            # Note: Card name might contain underscores, so we use parts[:-2] for name
            card_name = '_'.join(parts[:-2])
            set_code = parts[-2]
            collector_number = parts[-1]
            return CardMetadata(
                card_name=card_name,
                set_code=set_code,
                collector_number=collector_number
            )
        elif len(parts) == 2 and parts[1].isdigit():
            # Format might be CardName_Index
            return CardMetadata(card_name=parts[0])
        else:
            # Just use the whole name
            return CardMetadata(card_name=base_name)
    
    def calculate_phash(self):
        """
        Calculates the perceptive hash for the image
        """
        self.phash = imagehash.phash(
            PILImage.fromarray(np.uint8(255 * cv2.cvtColor(
                self.adjusted, cv2.COLOR_BGR2RGB))),
            hash_size=32)
    
    def histogram_adjust(self):
        """
        Adjusts the image by contrast limited histogram adjustment (clahe)
        """
        lab = cv2.cvtColor(self.original, cv2.COLOR_BGR2LAB)
        lightness, redness, yellowness = cv2.split(lab)
        corrected_lightness = self.clahe.apply(lightness)
        limg = cv2.merge((corrected_lightness, redness, yellowness))
        self.adjusted = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)
    
    def add_scryfall_metadata(self, scryfall_id, multiverse_id=0):
        """
        Adds Scryfall-specific metadata to the image
        """
        self.metadata.scryfall_id = scryfall_id
        self.metadata.multiverse_id = multiverse_id
        
    def to_dict(self):
        """
        Converts the image metadata to a dictionary (JSON-friendly)
        """
        return {
            "name": self.name,
            "card_name": self.metadata.card_name,
            "set_code": self.metadata.set_code,
            "collector_number": self.metadata.collector_number,
            "scryfall_id": self.metadata.scryfall_id,
            "multiverse_id": self.metadata.multiverse_id
        }