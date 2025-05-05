# Magic Card Detector CLI Usage Examples

This document provides examples of how to use the Magic Card Detector CLI for common tasks.

## 1. Generate Hashes for a Card Set

To generate hash data for a card set, follow these steps:

1. Run the CLI:
   ```bash
   ./run_cli.sh
   ```

2. Select "Generate Set Hashes" from the main menu.

3. Enter the set code. For example, to generate hashes for the Dark Shadows expansion:
   ```
   Enter the set code (e.g., LEA, DSK): DSK
   ```

4. Select the source. Choose "Scryfall" to download images from the Scryfall API, or "Local" to use images from your local directory:
   ```
   Select the source:
   > Scryfall
     Local
   ```

5. Set the parallelism level. This controls how many images are processed concurrently:
   ```
   Enter parallelism level (default: 10): 10
   ```

6. Choose whether to clean up temporary files after completion:
   ```
   Cleanup/Delete temporary files after completion? [Y/n]: Y
   ```

7. The CLI will display your configuration and start the hash generation process:
   ```
   Generate Set Hashes Configuration:
   Set Code: DSK
   Source: Scryfall
   Parallelism: 10
   Cleanup: Yes

   Running hash generation...
   ```

8. Wait for the process to complete. The hash data will be saved to `assets/set_hashes/dsk_reference_phash.dat`.

## 2. Extract Cards from Images

To detect and extract Magic cards from images:

1. Run the CLI:
   ```bash
   ./run_cli.sh
   ```

2. Select "Extract Cards" from the main menu.

3. Choose the set to use for recognition:
   ```
   Select a set:
   > All
     LEA
     DSK
     Other
   ```

4. Specify the output directory:
   ```
   Enter output directory path [./Out]: ./output
   ```

5. Specify the input directory containing the images to process:
   ```
   Enter input directory path [./In]: ./input
   ```

6. Choose whether to configure advanced options:
   ```
   Would you like to see advanced options? [y/N]: y
   ```

7. If you selected "Yes" for advanced options, configure the confidence threshold:
   ```
   Enter confidence threshold (50-100%) [85]: 80
   ```

8. Configure whether to save debug images:
   ```
   Save debug images with detection information? [y/N]: y
   ```

9. The CLI will display your configuration and start the extraction process:
   ```
   Extract Cards Configuration:
   Selected Set: All
   Output Path: ./output
   Input Path: ./input
   Advanced Options: Enabled
   Confidence Threshold: 80%
   Save Debug Images: Yes

   Running card extraction...
   ```

10. The tool will output the detection results directly to your console:
    ```
    Image: dragon_whelp.jpg
    Cards found: 1
    Recognized cards:
      - dragon whelp (confidence: 95.2%)
    
    Image: counterspell_bgs.jpg
    Cards found: 1
    Recognized cards:
      - counterspell (confidence: 92.8%)
    
    Total recognized cards: 2
    
    Annotated images have been saved to: ./output
    ```

## Working with Custom Hash Files

When selecting "Other" for the set, you'll be prompted to enter a path to a custom hash file:

```
Enter the path to your custom hash file:
/path/to/your/custom_set_reference_phash.dat
```

This allows you to use hash files that may be located outside the default directory or have non-standard names.

## Tips for Best Results

- **Image Quality**: Use well-lit, high-resolution images for best recognition results.
- **Multiple Cards**: When photographing multiple cards, ensure they don't overlap significantly.
- **Set Selection**: When extracting cards, selecting a specific set (rather than "All") can improve recognition accuracy if you know which set the cards belong to.
- **Confidence Threshold**: Lower the confidence threshold (e.g., to 70%) if cards aren't being detected, or raise it (e.g., to 90%) if you're getting false positives.
- **Managing Hash Data**: Generate hash data for the specific sets you work with most often to improve performance.