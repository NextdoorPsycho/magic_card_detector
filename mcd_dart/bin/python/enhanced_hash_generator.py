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
        Fetches card metadata from Scryfall API for a given set including ALL printing variants
        
        Args:
            set_code: The three-letter set code (e.g., LEA, DSK)
            
        Returns:
            dict: Mapping of card names to their Scryfall metadata
        """
        if not set_code:
            return {}
            
        metadata_map = {}
        collected_printings = set()
        
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
            
            # Step 1: First get all base cards in the set to gather their oracle IDs
            print(f"Step 1: Fetching base cards from set {set_code}")
            oracle_ids = []
            url = f"https://api.scryfall.com/cards/search?q=set:{set_code.lower()}+lang:en&unique=cards"
            next_page = url
            
            while next_page:
                if self.verbose:
                    print(f"Fetching base cards from {next_page}")
                
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
                    
                    # Extract oracle IDs
                    for card in data.get('data', []):
                        oracle_id = card.get('oracle_id')
                        if oracle_id and oracle_id not in oracle_ids:
                            oracle_ids.append(oracle_id)
                    
                    # Check for next page
                    next_page = data.get('next_page') if data.get('has_more', False) else None
                
                except Exception as e:
                    print(f"Error getting base cards: {e}")
                    break
            
            print(f"Found {len(oracle_ids)} unique cards in set {set_code}")
            
            # Step 2: For each oracle ID, get ALL printings in the specified set
            print(f"Step 2: Fetching all printings for each card")
            for i, oracle_id in enumerate(oracle_ids):
                if self.verbose or i % 10 == 0:
                    print(f"Processing card {i+1}/{len(oracle_ids)}")
                
                # Build query to get all printings with this oracle ID in the set
                query = f"oracleid:{oracle_id}+set:{set_code.lower()}+lang:en+include:extras+include:variations+include:promos"
                printings_url = f"https://api.scryfall.com/cards/search?q={query}&unique=prints"
                
                printings_page = printings_url
                try:
                    while printings_page:
                        response = requests.get(printings_page)
                        
                        if response.status_code != 200:
                            if response.status_code != 404:  # 404 is expected if a card has no variants
                                print(f"Warning: Failed to load printings for oracle ID {oracle_id}: {response.status_code}")
                            break
                        
                        data = response.json()
                        
                        for card in data.get('data', []):
                            card_id = card.get('id')
                            
                            # Only add if we haven't seen this exact printing before
                            if card_id not in collected_printings:
                                collected_printings.add(card_id)
                                
                                card_name = card.get('name', '').lower()
                                collector_number = card.get('collector_number', '')
                                variant_type = self._determine_variant_type(card)
                                
                                # Create a unique key that includes variant information
                                key = f"{card_name}_{collector_number}_{variant_type}_{card_id[-8:]}"
                                # Clean the key for mapping
                                clean_key = re.sub(r'[^a-z0-9_]', '', key)
                                
                                # Extract frame effects as a list
                                frame_effects = []
                                if card.get('frame_effects'):
                                    frame_effects = card.get('frame_effects')
                                
                                # Store comprehensive metadata
                                metadata_map[clean_key] = {
                                    'name': card.get('name', ''),
                                    'scryfall_id': card_id,
                                    'collector_number': collector_number,
                                    'multiverse_id': card.get('multiverse_ids', [0])[0] if card.get('multiverse_ids') else 0,
                                    'set': card.get('set', '').upper(),
                                    'variant_type': variant_type,
                                    'is_alternate_art': card.get('variation', False),
                                    'artist': card.get('artist', ''),
                                    'rarity': card.get('rarity', ''),
                                    'oracle_id': card.get('oracle_id', ''),
                                    'frame_effects': frame_effects,
                                    'border_color': card.get('border_color', ''),
                                    'full_art': card.get('full_art', False),
                                    'textless': card.get('textless', False)
                                }
                                
                                if self.verbose:
                                    print(f"Added metadata for {card.get('name')} ({variant_type})")
                        
                        # Check for next page
                        printings_page = data.get('next_page') if data.get('has_more', False) else None
                
                except Exception as e:
                    print(f"Error getting printings for oracle ID {oracle_id}: {e}")
            
            # Step 3: Additional safety check for variants
            print("Step 3: Additional check for variants")
            try:
                extras_query = f"set:{set_code.lower()}+is:variant+lang:en"
                extras_url = f"https://api.scryfall.com/cards/search?q={extras_query}&unique=prints"
                
                extras_page = extras_url
                while extras_page:
                    response = requests.get(extras_page)
                    
                    if response.status_code != 200:
                        break  # This query may return no results, which is fine
                    
                    data = response.json()
                    
                    for card in data.get('data', []):
                        card_id = card.get('id')
                        
                        # Only add if we haven't seen this exact printing before
                        if card_id not in collected_printings:
                            collected_printings.add(card_id)
                            
                            card_name = card.get('name', '').lower()
                            collector_number = card.get('collector_number', '')
                            variant_type = self._determine_variant_type(card)
                            
                            # Create a unique key that includes variant information
                            key = f"{card_name}_{collector_number}_{variant_type}_{card_id[-8:]}"
                            # Clean the key for mapping
                            clean_key = re.sub(r'[^a-z0-9_]', '', key)
                            
                            # Extract frame effects as a list
                            frame_effects = []
                            if card.get('frame_effects'):
                                frame_effects = card.get('frame_effects')
                            
                            # Store comprehensive metadata
                            metadata_map[clean_key] = {
                                'name': card.get('name', ''),
                                'scryfall_id': card_id,
                                'collector_number': collector_number,
                                'multiverse_id': card.get('multiverse_ids', [0])[0] if card.get('multiverse_ids') else 0,
                                'set': card.get('set', '').upper(),
                                'variant_type': variant_type,
                                'is_alternate_art': card.get('variation', False),
                                'artist': card.get('artist', ''),
                                'rarity': card.get('rarity', ''),
                                'oracle_id': card.get('oracle_id', ''),
                                'frame_effects': frame_effects,
                                'border_color': card.get('border_color', ''),
                                'full_art': card.get('full_art', False),
                                'textless': card.get('textless', False)
                            }
                            
                            if self.verbose:
                                print(f"Added additional variant for {card.get('name')} ({variant_type})")
                    
                    # Check for next page
                    extras_page = data.get('next_page') if data.get('has_more', False) else None
            
            except Exception as e:
                print(f"Note: Additional variant search completed or not available.")
                
            print(f"Fetched metadata for {len(metadata_map)} cards (including ALL variants) from Scryfall")
                
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
    
    def _determine_variant_type(self, card):
        """
        Determines the variant type from a Scryfall card object
        
        Args:
            card: The Scryfall card data
            
        Returns:
            str: The variant type identifier
        """
        # Default variant type
        variant_type = 'normal'
        
        # Check for specific variant indicators
        if card.get('frame_effects'):
            frame_effects = card.get('frame_effects', [])
            if 'extendedart' in frame_effects:
                variant_type = 'extended'
            elif 'showcase' in frame_effects:
                variant_type = 'showcase'
            elif 'borderless' in frame_effects:
                variant_type = 'borderless'
        
        # Check for full art
        if card.get('full_art', False):
            variant_type = 'fullart'
        
        # Check promo status
        if card.get('promo', False):
            variant_type = 'promo'
        
        # Check textless status
        if card.get('textless', False):
            variant_type = 'textless'
        
        # For digital only cards
        if card.get('digital', False):
            variant_type = 'digital'
        
        # Borderless and alternate art detection
        if card.get('border_color') == 'borderless':
            variant_type = 'borderless'
        
        # Fetch specific frame types from Scryfall data
        if card.get('frame') == 'showcase':
            variant_type = 'showcase'
        
        # If we have variation or finishes, append to variant type
        if card.get('variation', False):
            if variant_type == 'normal':
                variant_type = 'alternate'
            else:
                variant_type = f'alternate_{variant_type}'
        
        return variant_type
    
    def match_image_to_metadata(self, image_name, metadata_map):
        """
        Matches an image filename to Scryfall metadata with variant support
        
        Args:
            image_name: The image filename
            metadata_map: Mapping of card keys to Scryfall metadata
            
        Returns:
            dict: The matching metadata or None if no match found
        """
        base_name = os.path.basename(image_name)
        # Remove extension
        if '.' in base_name:
            base_name = base_name.split('.')[0]
        
        # Handle our specific naming format for variants
        # The expected format is: CardName__SET_CollectorNumber_VariantType_Index
        # or front/back variants: CardName__SET_CollectorNumber_VariantType_Index_front
        if '__' in base_name:
            # This is likely our generated format with variant info
            parts = base_name.split('__')
            if len(parts) == 2:
                card_name = parts[0].lower()
                info_part = parts[1]
                
                # Parse the info part (expected: SET_CollectorNumber_VariantType_Index)
                info_parts = info_part.split('_')
                if len(info_parts) >= 3:
                    set_code = info_parts[0].lower()
                    collector_number = info_parts[1]
                    variant_type = info_parts[2]
                    
                    # Remove any front/back suffix if present
                    if variant_type.endswith('front') or variant_type.endswith('back'):
                        variant_type = variant_type.rsplit('_', 1)[0]
                    
                    # Try to find an exact match with all information
                    key = f"{card_name}_{collector_number}_{variant_type}"
                    clean_key = re.sub(r'[^a-z0-9_]', '', key)
                    
                    if clean_key in metadata_map:
                        return metadata_map[clean_key]
                    
                    # Try finding by card name and collector number only
                    for k, metadata in metadata_map.items():
                        meta_card_name = metadata['name'].lower()
                        meta_collector_number = metadata['collector_number']
                        
                        # Clean the card name for comparison
                        clean_meta_name = re.sub(r'[^a-z0-9]', '', meta_card_name)
                        clean_card_name = re.sub(r'[^a-z0-9]', '', card_name)
                        
                        if (clean_meta_name == clean_card_name and 
                            meta_collector_number == collector_number):
                            return metadata
        
        # Try matching by parts in the filename
        parts = base_name.split('_')
        if len(parts) >= 1:
            card_name = parts[0].lower()
            clean_name = re.sub(r'[^a-z0-9]', '', card_name)
            
            # Try to find collector number if present
            collector_number = None
            variant_type = None
            
            for part in parts[1:]:
                # Try to identify if this part is a collector number (usually numeric)
                if re.match(r'^[0-9]+[a-z]?$', part):
                    collector_number = part
                # Try to identify if this part is a variant type
                elif part.lower() in ['normal', 'extended', 'showcase', 'borderless', 
                                     'fullart', 'promo', 'textless', 'alternate']:
                    variant_type = part.lower()
            
            # Try to match with specific collector number and variant
            if collector_number and variant_type:
                key = f"{clean_name}_{collector_number}_{variant_type}"
                if key in metadata_map:
                    return metadata_map[key]
            
            # Try with collector number only
            if collector_number:
                for k, metadata in metadata_map.items():
                    if (k.startswith(f"{clean_name}_{collector_number}_") or 
                        metadata['collector_number'] == collector_number):
                        return metadata
            
            # Try with card name only - find the default/normal version
            for k, metadata in metadata_map.items():
                meta_name = re.sub(r'[^a-z0-9]', '', metadata['name'].lower())
                if meta_name == clean_name and metadata['variant_type'] == 'normal':
                    return metadata
        
        # Try fuzzy matching if we haven't found a match yet
        clean_filename = re.sub(r'[^a-z0-9]', '', base_name.lower())
        
        # Find the best match (most matching characters at start)
        best_match = None
        best_match_len = 0
        best_match_score = 0
        
        for key, metadata in metadata_map.items():
            meta_name = re.sub(r'[^a-z0-9]', '', metadata['name'].lower())
            
            # Find common prefix length
            common_len = 0
            for i in range(min(len(clean_filename), len(meta_name))):
                if clean_filename[i] == meta_name[i]:
                    common_len += 1
                else:
                    break
            
            # Calculate match score
            match_score = common_len
            
            # Bonus for normal variants (prefer them over special variants)
            if metadata['variant_type'] == 'normal':
                match_score += 5
                
            if match_score > best_match_score and common_len > len(meta_name) // 3:
                best_match = metadata
                best_match_len = common_len
                best_match_score = match_score
                
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
                    # Create metadata with all variant information
                    frame_effects = scryfall_meta.get('frame_effects', [])
                    meta = CardMetadata(
                        card_name=scryfall_meta['name'],
                        set_code=scryfall_meta['set'],
                        collector_number=scryfall_meta['collector_number'],
                        scryfall_id=scryfall_meta['scryfall_id'],
                        multiverse_id=scryfall_meta['multiverse_id'],
                        variant_type=scryfall_meta.get('variant_type', 'normal'),
                        is_alternate_art=scryfall_meta.get('is_alternate_art', False),
                        artist=scryfall_meta.get('artist', ''),
                        rarity=scryfall_meta.get('rarity', ''),
                        oracle_id=scryfall_meta.get('oracle_id', ''),
                        frame_effects=frame_effects,
                        border_color=scryfall_meta.get('border_color', ''),
                        full_art=scryfall_meta.get('full_art', False),
                        textless=scryfall_meta.get('textless', False)
                    )
                    if self.verbose:
                        print(f"Matched {ref_img.name} to {meta.card_name}")
            
            # If store_names is True and we're not using the card name already,
            # modify the name to include the card name and variant info for direct lookup
            display_name = ref_img.name
            if store_names:
                # Create a filename that includes the card name and variant for easier lookup later
                if meta.card_name:
                    # Format the name as CardName__SET_CollectorNumber_VariantType
                    variant_info = f"{meta.set_code}_{meta.collector_number}_{meta.variant_type}"
                    display_name = f"{meta.card_name}__{variant_info}"
                    
                    # If this is a double-faced card, may need to append front/back
                    if "_front" in ref_img.name or "_back" in ref_img.name:
                        if "_front" in ref_img.name:
                            display_name += "_front"
                        elif "_back" in ref_img.name:
                            display_name += "_back"
                    
                    if self.verbose:
                        print(f"Storing name with variant info: {display_name}")
            
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