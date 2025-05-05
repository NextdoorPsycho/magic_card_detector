import os
import sys
import argparse
import pickle
import magic_card_detector as mcg

def generate_hash(set_path, output_path, verbose=False):
    """
    Generate perceptual hashes from a set of card images.
    
    Args:
        set_path: Path to the directory containing card images
        output_path: Path to save the generated hash file
        verbose: Whether to print verbose output
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Create output directory if it doesn't exist
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        if verbose:
            print(f"Reading images from: {set_path}")
            print(f"Output will be saved to: {output_path}")
        
        # Initialize the card detector
        card_detector = mcg.MagicCardDetector()
        card_detector.verbose = verbose
        
        # Read and process the image set
        card_detector.read_and_adjust_reference_images(set_path)
        
        if len(card_detector.reference_images) == 0:
            print("Error: No images found in the specified directory.")
            return False
            
        # Prepare hash data
        hash_list = []
        for image in card_detector.reference_images:
            # Create a lightweight copy with just the essential data
            image.original = None
            image.clahe = None
            image.adjusted = None
            hash_list.append(image)
        
        # Save hash data to file
        with open(output_path, 'wb') as f:
            pickle.dump(hash_list, f)
            
        if verbose:
            print(f"Successfully generated hash data for {len(hash_list)} cards.")
            print(f"Hash data saved to: {output_path}")
            
        return True
    except Exception as e:
        print(f"Error generating hash data: {e}")
        return False

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
    
    args = parser.parse_args()
    
    # Validate inputs
    if not os.path.exists(args.set_path):
        print(f"Error: Directory not found: {args.set_path}")
        return 1
        
    # Generate hash data
    success = generate_hash(args.set_path, args.output, args.verbose)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())