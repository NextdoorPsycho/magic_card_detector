import os
import numpy as np
import cv2

from magic_card_detector import MagicCardDetector

# --- Configuration ---
REFERENCE_HASH_FILE = '../../../../../../../Desktop/magic_card_detector-master/alpha_reference_phash.dat'

# --- Initialize MagicCardDetector ---
print("Initializing Magic Card Detector...")
detector = MagicCardDetector()
try:
    detector.read_prehashed_reference_data(REFERENCE_HASH_FILE)
    print(f"Successfully loaded reference data from {REFERENCE_HASH_FILE}")
except FileNotFoundError:
    print(f"ERROR: Reference hash file '{REFERENCE_HASH_FILE}' not found!")
    print("The detector will not be able to recognize cards.")
    detector = None
except Exception as e:
    print(f"ERROR loading reference data: {e}")
    detector = None

def process_image(image_path, output_path=None):
    """
    Process a single image file and analyze it for magic cards.
    """
    if detector is None:
        print("Card Detector could not be initialized (Reference data missing?). Cannot process image.")
        return None
    
    try:
        # Read image file
        img_cv = cv2.imread(image_path)
        
        if img_cv is None:
            print(f"Could not decode image file: {image_path}")
            return None
            
        print(f"Image '{image_path}' loaded successfully. Processing...")
        
        # Set output path if provided
        if output_path:
            detector.output_path = output_path
        
        # Process the image using the detector instance
        result = detector.process_image_data(img_cv, os.path.basename(image_path))
        
        print("Processing complete.")
        return result
        
    except Exception as e:
        print(f"An error occurred during processing: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    # Example usage
    # process_image("path/to/image.jpg")
    pass