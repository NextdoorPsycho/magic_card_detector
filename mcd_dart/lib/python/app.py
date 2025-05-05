import os
import sys
import argparse
import numpy as np
import cv2

from magic_card_detector import MagicCardDetector

def initialize_detector(hash_file_path=None):
    """
    Initialize the Magic Card Detector with the given hash file.
    Uses a default path if none is provided.
    """
    print("Initializing Magic Card Detector...")
    detector = MagicCardDetector()
    
    # If no hash file is specified, look in default locations
    if hash_file_path is None:
        # Try common locations for the hash file
        possible_paths = [
            os.path.join('assets', 'set_hashes', 'alpha_reference_phash.dat'),
            os.path.join('assets', 'set_hashes', 'lea_reference_phash.dat'),
            os.path.join('assets', 'set_hashes', 'dsk_reference_phash.dat')
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                hash_file_path = path
                break
    
    if hash_file_path and os.path.exists(hash_file_path):
        try:
            detector.read_prehashed_reference_data(hash_file_path)
            print(f"Successfully loaded reference data from {hash_file_path}")
            return detector
        except Exception as e:
            print(f"ERROR loading reference data: {e}")
            return None
    else:
        print(f"ERROR: Reference hash file not found!")
        print("The detector will not be able to recognize cards.")
        return None

def process_image(image_path, output_path=None, hash_file=None, threshold=4.0, visual=False, verbose=False):
    """
    Process a single image file and analyze it for magic cards.
    
    Args:
        image_path: Path to the image to process
        output_path: Optional directory to save output images
        hash_file: Path to the hash file for card recognition
        threshold: Confidence threshold for matching (default: 4.0)
        visual: Whether to display visual results
        verbose: Whether to print verbose output
        
    Returns:
        A dictionary with the recognition results
    """
    detector = initialize_detector(hash_file)
    
    if detector is None:
        print("Card Detector could not be initialized. Cannot process image.")
        return None
    
    # Set detector parameters
    detector.hash_separation_thr = threshold
    detector.visual = visual
    detector.verbose = verbose
    
    if output_path:
        detector.output_path = output_path
        # Ensure the output directory exists
        os.makedirs(output_path, exist_ok=True)
    
    try:
        # Read image file
        img_cv = cv2.imread(image_path)
        
        if img_cv is None:
            print(f"Could not decode image file: {image_path}")
            return None
            
        print(f"Image '{image_path}' loaded successfully. Processing...")
        
        # Process the image using the detector instance
        result = detector.process_image_data(img_cv, os.path.basename(image_path))
        
        # Collect and return results
        recognized_cards = result.return_recognized()
        
        # Format the result as a dictionary for easy JSON conversion
        result_dict = {
            'image_name': os.path.basename(image_path),
            'card_count': len(recognized_cards),
            'cards': []
        }
        
        for card in recognized_cards:
            card_dict = {
                'name': card.name,
                'score': card.recognition_score / detector.hash_separation_thr  # Normalize to 0-1
            }
            result_dict['cards'].append(card_dict)
        
        if output_path:
            result_path = os.path.join(output_path, 
                                     f"MTG_card_recognition_results_{os.path.basename(image_path)}")
            result_dict['result_image_path'] = result_path
        
        print("Processing complete.")
        return result_dict
        
    except Exception as e:
        print(f"An error occurred during processing: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Command line interface for the card detector."""
    parser = argparse.ArgumentParser(
        description='Detect and recognize Magic: The Gathering cards in images.')
    
    parser.add_argument('--input-path', required=True,
                      help='Path to the input image or directory of images')
    parser.add_argument('--output-path', default='out',
                      help='Directory to save output images (default: "out")')
    parser.add_argument('--hash-file', 
                      help='Path to the reference hash file')
    parser.add_argument('--threshold', type=float, default=4.0,
                      help='Confidence threshold for matching (default: 4.0)')
    parser.add_argument('--visual', action='store_true',
                      help='Display visual results')
    parser.add_argument('--verbose', action='store_true',
                      help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Ensure output directory exists
    os.makedirs(args.output_path, exist_ok=True)
    
    # Process single image or directory
    if os.path.isdir(args.input_path):
        # Process directory
        results = []
        for filename in os.listdir(args.input_path):
            if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                image_path = os.path.join(args.input_path, filename)
                result = process_image(
                    image_path, 
                    args.output_path,
                    args.hash_file,
                    args.threshold,
                    args.visual,
                    args.verbose
                )
                if result:
                    results.append(result)
        
        # Print summary
        print(f"\nProcessed {len(results)} images")
        for result in results:
            print(f"Image: {result['image_name']} - Found {result['card_count']} cards")
    else:
        # Process single image
        result = process_image(
            args.input_path, 
            args.output_path,
            args.hash_file,
            args.threshold,
            args.visual,
            args.verbose
        )
        if result:
            print(f"\nImage: {result['image_name']}")
            print(f"Cards found: {result['card_count']}")
            
            if result['card_count'] > 0:
                print("Recognized cards:")
                for card in result['cards']:
                    print(f"  - {card['name']} (confidence: {card['score']*100:.1f}%)")

if __name__ == "__main__":
    main()