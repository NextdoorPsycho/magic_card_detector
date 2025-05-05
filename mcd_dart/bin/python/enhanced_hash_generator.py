#!/usr/bin/env python3
"""
Enhanced hash generation tool for MTG card detector, for Dart integration.

This tool generates perceptual hashes for a set of MTG card images
and saves them to a reference file, including card metadata.
"""

import os
import sys
import json
import argparse
import pickle
import re

# Set matplotlib to use a non-interactive backend before any other matplotlib imports
import matplotlib
matplotlib.use('Agg')  # Use the Agg backend which doesn't require a GUI

# Try to import requests, provide helpful error if missing
try:
    import requests
except ImportError:
    print("ERROR: Python 'requests' library is not installed.")
    print("Please install it using:")
    print("    pip install requests")
    print("or")
    print("    pip3 install requests")
    sys.exit(1)

# Import from our local module
from mtg_detector import MagicCardDetector, EnhancedReferenceImage, CardMetadata
import cv2

class EnhancedHashGenerator:
    """
    Generates perceptual hashes with enhanced metadata for Magic cards
    """
    
    def __init__(self, verbose=False):
        """Initialize the generator with detector"""
        self.detector = MagicCardDetector()
        self.detector.verbose = verbose
        self.verbose = verbose
        self.enhanced_reference_images = []
        
    def fetch_scryfall_metadata(self, set_code):
        """
        Fetches card metadata from Scryfall API for a given set
        
        Args:
            set_code: The three-letter set code (e.g., LEA, DSK)
            
        Returns:
            dict: Mapping of card names to their Scryfall metadata
        """
        if not set_code:
            return {}
            
        metadata_map = {}
        
        try:
            # Try to load from local metadata.json file first if it exists
            metadata_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'metadata.json')
            if os.path.exists(metadata_file):
                try:
                    with open(metadata_file, 'r', encoding='utf-8') as f:
                        print(f"Loading metadata from local file: {metadata_file}")
                        existing_data = json.load(f)
                        if set_code.lower() in existing_data:
                            return existing_data[set_code.lower()]
                except Exception as e:
                    print(f"Error reading local metadata: {e}")
        
            # Fetch cards from the Scryfall API
            url = f"https://api.scryfall.com/cards/search?q=set:{set_code.lower()}&unique=prints"
            next_page = url
            
            while next_page:
                if self.verbose:
                    print(f"Fetching Scryfall data from {next_page}")
                    
                try:
                    response = requests.get(next_page)
                    if response.status_code != 200:
                        print(f"Error fetching data from Scryfall: {response.status_code}")
                        if response.status_code == 404:
                            print(f"Set '{set_code}' not found on Scryfall.")
                        elif response.status_code == 429:
                            print("Rate limit exceeded. Please try again later.")
                        break
                        
                    data = response.json()
                    
                    for card in data.get('data', []):
                        card_name = card.get('name', '').lower()
                        # Clean the name for matching
                        clean_name = re.sub(r'[^a-z0-9]', '', card_name)
                        
                        # Store metadata
                        metadata_map[clean_name] = {
                            'name': card.get('name', ''),
                            'scryfall_id': card.get('id', ''),
                            'collector_number': card.get('collector_number', ''),
                            'multiverse_id': card.get('multiverse_ids', [0])[0] if card.get('multiverse_ids') else 0,
                            'set': card.get('set', '').upper()
                        }
                        
                    # Check for next page
                    next_page = data.get('next_page') if data.get('has_more', False) else None
                except Exception as e:
                    print(f"Error communicating with Scryfall API: {e}")
                    break
                
            if self.verbose:
                print(f"Fetched metadata for {len(metadata_map)} cards from Scryfall")
                
            # Save the metadata for future use if we got any results
            if metadata_map:
                try:
                    all_metadata = {}
                    if os.path.exists(metadata_file):
                        with open(metadata_file, 'r', encoding='utf-8') as f:
                            all_metadata = json.load(f)
                    
                    all_metadata[set_code.lower()] = metadata_map
                    
                    with open(metadata_file, 'w', encoding='utf-8') as f:
                        json.dump(all_metadata, f, indent=2)
                        if self.verbose:
                            print(f"Saved metadata to {metadata_file}")
                except Exception as e:
                    print(f"Warning: Could not save metadata for future use: {e}")
        except Exception as e:
            print(f"Error fetching metadata from Scryfall: {e}")
            print("Processing will continue without metadata.")
            
        return metadata_map
    
    def match_image_to_metadata(self, image_name, metadata_map):
        """
        Matches an image filename to Scryfall metadata
        
        Args:
            image_name: The image filename
            metadata_map: Mapping of card names to Scryfall metadata
            
        Returns:
            dict: The matching metadata or None if no match found
        """
        base_name = os.path.basename(image_name)
        # Remove extension
        if '.' in base_name:
            base_name = base_name.split('.')[0]
            
        # Try various patterns to match the name
        # First try exact match if filename is formatted
        parts = base_name.split('_')
        if len(parts) >= 1:
            card_name = parts[0].lower()
            clean_name = re.sub(r'[^a-z0-9]', '', card_name)
            
            # Direct lookup
            if clean_name in metadata_map:
                return metadata_map[clean_name]
        
        # Try fuzzy matching by removing special characters and comparing
        clean_filename = re.sub(r'[^a-z0-9]', '', base_name.lower())
        
        # Find the best match (most matching characters at start)
        best_match = None
        best_match_len = 0
        
        for clean_name, metadata in metadata_map.items():
            # Find common prefix length
            common_len = 0
            for i in range(min(len(clean_filename), len(clean_name))):
                if clean_filename[i] == clean_name[i]:
                    common_len += 1
                else:
                    break
                    
            if common_len > best_match_len and common_len > len(clean_name) // 2:
                best_match = metadata
                best_match_len = common_len
                
        return best_match
    
    def process_images(self, image_dir, set_code=None, store_names=False):
        """
        Processes images in the directory, enriching them with metadata
        
        Args:
            image_dir: Directory containing card images
            set_code: Optional three-letter set code for fetching Scryfall data
            store_names: Store card names directly in the hash for efficient lookup
            
        Returns:
            list: List of EnhancedReferenceImage objects
        """
        # Initialize the detector
        self.detector = MagicCardDetector()
        self.detector.verbose = self.verbose
        
        # Load images and generate hashes
        print(f"Reading images from {image_dir}")
        self.detector.read_and_adjust_reference_images(image_dir)
        
        if not self.detector.reference_images:
            print(f"No images found in {image_dir}")
            return []
            
        print(f"Found {len(self.detector.reference_images)} images")
        
        # Fetch metadata if set code is provided
        metadata_map = {}
        if set_code:
            print(f"Fetching Scryfall metadata for set {set_code}")
            metadata_map = self.fetch_scryfall_metadata(set_code)
        
        # Create enhanced images with metadata
        self.enhanced_reference_images = []
        for ref_img in self.detector.reference_images:
            # Get the base name (without extension)
            base_name = ref_img.name.split('.')[0] if '.' in ref_img.name else ref_img.name
            
            # Create basic metadata from filename
            meta = CardMetadata(card_name=base_name)
            
            # Try to match with Scryfall data
            if metadata_map:
                scryfall_meta = self.match_image_to_metadata(ref_img.name, metadata_map)
                if scryfall_meta:
                    meta = CardMetadata(
                        card_name=scryfall_meta['name'],
                        set_code=scryfall_meta['set'],
                        collector_number=scryfall_meta['collector_number'],
                        scryfall_id=scryfall_meta['scryfall_id'],
                        multiverse_id=scryfall_meta['multiverse_id']
                    )
                    if self.verbose:
                        print(f"Matched {ref_img.name} to {meta.card_name}")
            
            # If store_names is True and we're not using the card name already,
            # modify the name to include the card name for direct lookup
            display_name = ref_img.name
            if store_names:
                # Create a filename that includes the card name for easier lookup later
                if meta.card_name and meta.card_name != base_name:
                    # Only modify if the metadata name is different from the base filename
                    # Format the name as CardName__OriginalName to allow for consistent lookup
                    display_name = f"{meta.card_name}__{ref_img.name}"
                    if self.verbose:
                        print(f"Storing name directly: {display_name}")
            
            # Create enhanced reference image
            enhanced_img = EnhancedReferenceImage(
                name=display_name,  # Use the potentially modified name
                original_image=None,  # We don't need to store the image
                clahe=None,
                metadata=meta,
                phash=ref_img.phash
            )
            
            self.enhanced_reference_images.append(enhanced_img)
            
        return self.enhanced_reference_images
    
    def export_reference_data(self, output_path, include_json=True):
        """
        Exports reference data to binary and optional JSON format
        
        Args:
            output_path: Path to save the reference data
            include_json: Whether to also save a JSON version of the metadata
            
        Returns:
            bool: True if successful, False otherwise
        """
        if not self.enhanced_reference_images:
            print("No reference images to export")
            return False
            
        try:
            # Create the output directory if it doesn't exist
            output_dir = os.path.dirname(output_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir)
                
            # Save the binary pickle file with hashes
            with open(output_path, 'wb') as f:
                pickle.dump(self.enhanced_reference_images, f)
                
            # Optionally save a JSON metadata file
            if include_json:
                json_path = os.path.splitext(output_path)[0] + '_metadata.json'
                metadata_list = []
                
                for img in self.enhanced_reference_images:
                    metadata_list.append(img.to_dict())
                    
                with open(json_path, 'w', encoding='utf-8') as f:
                    json.dump(metadata_list, f, indent=2)
                    
                print(f"Saved metadata to {json_path}")
                
            print(f"Saved hash data to {output_path}")
            return True
            
        except Exception as e:
            print(f"Error saving reference data: {e}")
            return False
            

def main():
    """
    Main function for the enhanced hash generation tool.
    """
    parser = argparse.ArgumentParser(
        description='Generate perceptual hashes with metadata for MTG card images.')

    parser.add_argument('--set-path', '-p', required=True,
                      help='Path to the folder containing card images.')
    parser.add_argument('--output', '-o', required=True,
                      help='Output file path for the hash data.')
    parser.add_argument('--set-code', '-s',
                      help='Three-letter set code for fetching Scryfall metadata (e.g., LEA, DSK).')
    parser.add_argument('--verbose', '-v', action='store_true',
                      help='Enable verbose output.')
    parser.add_argument('--json', '-j', action='store_true',
                      help='Also output metadata in JSON format.')
    parser.add_argument('--store-names', '-n', action='store_true',
                      help='Store card names directly in the hash (more efficient lookup).')

    args = parser.parse_args()

    # Validate the set path
    set_path = args.set_path
    if not os.path.isdir(set_path):
        print(f"Error: Set path '{set_path}' is not a valid directory.")
        return 1
    
    # Add trailing slash if needed
    if not set_path.endswith('/'):
        set_path += '/'

    print(f"Generating enhanced hashes for card images in {set_path}")
    print(f"Output will be saved to {args.output}")
    
    if args.set_code:
        print(f"Will fetch metadata for set {args.set_code}")

    # Create enhanced hash generator
    generator = EnhancedHashGenerator(verbose=args.verbose)
    
    # Process images and generate hashes with metadata
    if args.set_code and not os.path.exists(os.path.join(set_path, 'metadata.json')):
        try:
            # Use Scryfall API for metadata if set code is provided
            generator.process_images(set_path, args.set_code, store_names=args.store_names)
        except Exception as e:
            print(f"Warning: Failed to fetch metadata from Scryfall: {e}")
            print("Continuing without Scryfall metadata...")
            # Fall back to local processing without Scryfall integration
            generator.process_images(set_path, None, store_names=args.store_names)
    else:
        # No set code provided or local metadata exists, just process locally
        generator.process_images(set_path, None, store_names=args.store_names)
    
    # Export reference data
    success = generator.export_reference_data(args.output, include_json=args.json)
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())