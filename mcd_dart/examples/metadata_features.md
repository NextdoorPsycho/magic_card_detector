# Card Metadata Features

The enhanced version of the Magic Card Detector now includes powerful metadata features that help identify the exact cards detected, including their set, collector number, and Scryfall ID.

## How It Works

When generating hashes for a set, the enhanced hash generator:

1. Processes each card image
2. Generates a perceptual hash for the image
3. Fetches additional metadata from Scryfall for the set (if a set code is provided)
4. Matches each image to its corresponding Scryfall data based on the filename
5. Saves both the hash and metadata to a combined reference file
6. Also creates a human-readable JSON metadata file for inspection

When detecting cards, the enhanced detector:

1. Loads the hash file with metadata
2. Detects cards in the image using the same perceptual hash comparison
3. Includes the complete metadata for each detected card in the results
4. Displays rich information including card name, set, collector number, and Scryfall ID

## Generate Hashes with Metadata

To generate hashes that include metadata:

```bash
./run_cli.sh
```

Then select "Generate Set Hashes" and provide a set code (e.g., "LEA" for Limited Edition Alpha). The tool will automatically:

1. Download card data from Scryfall if using the "Scryfall" source
2. Match local images to Scryfall data if using the "Local" source
3. Generate enhanced hash files with metadata

## Detection with Metadata

When extracting cards using the enhanced detector, you'll now see much richer output:

```
Image: geyser_twister_fireball.jpg
Cards found: 3
Recognized cards:
  - Fireball (LEA) #144
    Confidence: 92.8%
    Scryfall ID: 7220aaa1-9693-4844-b840-f4c82dc3741f
    Scryfall URL: https://scryfall.com/card/lea/144

  - Volcanic Eruption (LEA) #288
    Confidence: 95.1%
    Scryfall ID: a7f85e1f-5941-4e7b-aae5-1acbca2394f0
    Scryfall URL: https://scryfall.com/card/lea/288

  - Blaze of Glory (LEA) #4
    Confidence: 94.3%
    Scryfall ID: a87a94f3-5b5a-4c3e-b308-dc4048dbc191
    Scryfall URL: https://scryfall.com/card/lea/4
```

## Benefits

The metadata features provide several benefits:

1. **Precise Identification**: Cards are identified by their exact printing rather than just by name
2. **Scryfall Integration**: Direct links to Scryfall for each card
3. **Better Organization**: Cards can be organized by set and collector number
4. **Future Extensibility**: The metadata framework allows for adding more card properties in the future

## Technical Details

- Metadata is stored alongside perceptual hashes in the `.dat` file
- Card names are directly embedded in the hash data for more efficient lookups
- A parallel JSON file (`*_metadata.json`) is created for human readability
- Matching is performed using filename patterns and fuzzy matching when necessary
- The system is backwards compatible with existing hash files (without metadata)

### Name Storage Feature

The hash generator includes a `--store-names` option (enabled by default) that embeds card names directly in the reference data. This ensures that:

1. Even when file names don't match card names, the correct name is stored
2. The detector can quickly match detected cards to their proper names
3. Recognition works efficiently regardless of the original image filenames

## Requirements

To use the metadata features, you need:

1. Internet connection (for fetching Scryfall data during hash generation)
2. The requests Python package (`pip install requests`)
3. A valid set code for the set you're processing

## Tips for Best Results

- For filenames, try to use a consistent format like `CardName_SetCode_CollectorNumber.jpg`
- If you don't have well-structured filenames, the system will attempt to match based on card names
- Provide the correct set code when generating hashes for best metadata lookups