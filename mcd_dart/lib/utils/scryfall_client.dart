import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Client for interacting with the Scryfall API to download card images
class ScryfallClient {
  static const String _baseUrl = 'https://api.scryfall.com';

  /// Get all cards from a specific set including ALL printing variants
  ///
  /// [setCode] - The three-letter code for the set (e.g., 'LEA', 'DSK')
  /// [includeLanguage] - Restrict to specific language (default: 'en' for English)
  static Future<List<Map<String, dynamic>>> getCardsFromSet(
    String setCode, {
    String includeLanguage = 'en',
  }) async {
    final List<Map<String, dynamic>> allCards = [];
    final Set<String> collectedPrintings = <String>{};

    // First get all base cards in the set to gather their oracle IDs
    String query = 'set:${setCode.toLowerCase()}';
    
    // Add language filter if specified
    if (includeLanguage.isNotEmpty) {
      query += '+lang:$includeLanguage';
    }
    
    String url = '$_baseUrl/cards/search?q=$query&unique=cards';
    print('Fetching basic cards from set $setCode...');
    
    final List<String> oracleIds = [];
    
    // Step 1: Get all oracle IDs for cards in this set
    String? nextPage = url;
    while (nextPage != null) {
      final http.Response response = await http.get(Uri.parse(nextPage));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load cards from Scryfall: ${response.statusCode} - ${response.body}',
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> cards = data['data'] as List<dynamic>;
      
      // Extract oracle IDs
      for (final card in cards) {
        final cardData = card as Map<String, dynamic>;
        final String oracleId = cardData['oracle_id'] as String;
        if (!oracleIds.contains(oracleId)) {
          oracleIds.add(oracleId);
        }
      }

      nextPage = data['has_more'] == true ? data['next_page'] as String : null;
    }
    
    print('Found ${oracleIds.length} unique cards in set $setCode');
    
    // Step 2: For each oracle ID, get ALL printings in the specified set
    for (final oracleId in oracleIds) {
      // Build query to get all printings with this oracle ID in the set
      String printingsQuery = 'oracleid:$oracleId+set:${setCode.toLowerCase()}';
      
      // Add language filter
      if (includeLanguage.isNotEmpty) {
        printingsQuery += '+lang:$includeLanguage';
      }
      
      // Include all extras, promos, etc.
      printingsQuery += '+include:extras+include:variations+include:promos';
      
      String printingsUrl = '$_baseUrl/cards/search?q=$printingsQuery&unique=prints';
      
      String? printingsPage = printingsUrl;
      while (printingsPage != null) {
        final http.Response response = await http.get(Uri.parse(printingsPage));

        if (response.statusCode != 200) {
          print('Warning: Failed to load printings for oracle ID $oracleId: ${response.statusCode}');
          break;
        }

        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> printings = data['data'] as List<dynamic>;
        
        for (final printing in printings) {
          final printingData = printing as Map<String, dynamic>;
          final String id = printingData['id'] as String;
          
          // Only add if we haven't seen this exact printing before
          if (!collectedPrintings.contains(id)) {
            collectedPrintings.add(id);
            allCards.add(printingData);
          }
        }

        printingsPage = data['has_more'] == true ? data['next_page'] as String : null;
      }
    }
    
    // Step 3: Add any remaining cards that may not have been captured
    // This is a safety measure to ensure we get everything
    String extrasQuery = 'set:${setCode.toLowerCase()}+is:variant';
    if (includeLanguage.isNotEmpty) {
      extrasQuery += '+lang:$includeLanguage';
    }
    
    String extrasUrl = '$_baseUrl/cards/search?q=$extrasQuery&unique=prints';
    
    try {
      String? extrasPage = extrasUrl;
      while (extrasPage != null) {
        final http.Response response = await http.get(Uri.parse(extrasPage));

        if (response.statusCode != 200) {
          break; // This query may return no results, which is fine
        }

        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> extras = data['data'] as List<dynamic>;
        
        for (final extra in extras) {
          final extraData = extra as Map<String, dynamic>;
          final String id = extraData['id'] as String;
          
          // Only add if we haven't seen this exact printing before
          if (!collectedPrintings.contains(id)) {
            collectedPrintings.add(id);
            allCards.add(extraData);
          }
        }

        extrasPage = data['has_more'] == true ? data['next_page'] as String : null;
      }
    } catch (e) {
      // This additional query may fail, but it's just a safety net
      print('Note: Additional variant search completed or not available.');
    }

    print('Downloaded ${allCards.length} cards (including ALL variants) from set $setCode');
    return allCards;
  }

  /// Download an image from a URL to a local file
  ///
  /// [imageUrl] - The URL of the image to download
  /// [outputPath] - The path where the image should be saved
  static Future<File> downloadImage(String imageUrl, String outputPath) async {
    final http.Response response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download image from $imageUrl: ${response.statusCode}',
      );
    }

    final File file = File(outputPath);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// Download all cards from a set including all variants
  ///
  /// [setCode] - The three-letter code for the set (e.g., 'LEA', 'DSK')
  /// [outputDir] - The directory where images should be saved
  /// [parallelism] - Number of concurrent downloads
  /// [progressCallback] - Callback function to report progress (index, total, cardName)
  /// [includeLanguage] - Restrict to specific language (default: 'en' for English)
  static Future<List<String>> downloadSetImages(
    String setCode,
    String outputDir,
    int parallelism,
    void Function(int, int, String)? progressCallback, {
    String includeLanguage = 'en',
  }) async {
    // Create the output directory if it doesn't exist
    final Directory dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Get all cards from the set including variants
    final List<Map<String, dynamic>> cards = await getCardsFromSet(
      setCode, 
      includeLanguage: includeLanguage,
    );
    final List<String> downloadedFiles = [];

    // Process cards in batches based on parallelism
    for (int i = 0; i < cards.length; i += parallelism) {
      final int endIndex =
          (i + parallelism) < cards.length ? i + parallelism : cards.length;
      final List<Map<String, dynamic>> batch = cards.sublist(i, endIndex);

      final List<Future<void>> downloads = [];

      for (int j = 0; j < batch.length; j++) {
        final int currentIndex = i + j;
        final Map<String, dynamic> card = batch[j];
        
        // Extract variant information
        final String cardName = card['name'] as String;
        final String collectorNumber = card['collector_number'] as String;
        final String variantType = _determineVariantType(card);
        
        // Create a descriptive filename that includes variant information
        final String safeCardName = cardName.replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        );
        
        final String fileName = _buildVariantFileName(
          safeCardName, 
          setCode, 
          collectorNumber, 
          variantType,
          currentIndex,
        );

        if (card.containsKey('image_uris') &&
            (card['image_uris'] as Map<String, dynamic>).containsKey('large')) {
          final String imageUrl = card['image_uris']['large'] as String;
          final String imagePath = path.join(outputDir, fileName);

          downloads.add(
            downloadImage(imageUrl, imagePath)
                .then((file) {
                  downloadedFiles.add(file.path);
                  if (progressCallback != null) {
                    final String displayName = '$cardName ($variantType)';
                    progressCallback(currentIndex + 1, cards.length, displayName);
                  }
                })
                .catchError((e) {
                  print('Error downloading $cardName ($variantType): $e');
                }),
          );
        } else if (card.containsKey('card_faces') &&
            (card['card_faces'] as List<dynamic>).isNotEmpty &&
            ((card['card_faces'] as List<dynamic>)[0] as Map<String, dynamic>)
                .containsKey('image_uris')) {
          // Handle double-faced cards - front face
          final String imageUrl =
              (card['card_faces'][0]
                      as Map<String, dynamic>)['image_uris']['large']
                  as String;
          
          final String imagePath = path.join(
            outputDir,
            fileName.replaceFirst('.jpg', '_front.jpg'),
          );

          downloads.add(
            downloadImage(imageUrl, imagePath)
                .then((file) {
                  downloadedFiles.add(file.path);
                  if (progressCallback != null) {
                    final String displayName = '$cardName ($variantType) - Front';
                    progressCallback(currentIndex + 1, cards.length, displayName);
                  }
                })
                .catchError((e) {
                  print('Error downloading $cardName ($variantType) - Front: $e');
                }),
          );
          
          // Also download back face if available
          if ((card['card_faces'] as List<dynamic>).length > 1 &&
              ((card['card_faces'] as List<dynamic>)[1] as Map<String, dynamic>)
                  .containsKey('image_uris')) {
            final String backImageUrl =
                (card['card_faces'][1]
                        as Map<String, dynamic>)['image_uris']['large']
                    as String;
            
            final String backImagePath = path.join(
              outputDir,
              fileName.replaceFirst('.jpg', '_back.jpg'),
            );
            
            downloads.add(
              downloadImage(backImageUrl, backImagePath)
                  .then((file) {
                    downloadedFiles.add(file.path);
                    if (progressCallback != null) {
                      final String displayName = '$cardName ($variantType) - Back';
                      progressCallback(currentIndex + 1, cards.length, displayName);
                    }
                  })
                  .catchError((e) {
                    print('Error downloading $cardName ($variantType) - Back: $e');
                  }),
            );
          }
        } else {
          if (progressCallback != null) {
            progressCallback(
              currentIndex + 1,
              cards.length,
              '$cardName ($variantType)',
            );
          }
          print(
            'Warning: No suitable image found for $cardName ($variantType)',
          );
        }
      }

      // Wait for all downloads in this batch to complete
      await Future.wait(downloads);
    }

    return downloadedFiles;
  }
  
  /// Determines the variant type from a Scryfall card object
  static String _determineVariantType(Map<String, dynamic> card) {
    // Default variant type
    String variantType = 'normal';
    
    // Check for specific variant indicators
    if (card.containsKey('frame_effects')) {
      final List<dynamic> frameEffects = card['frame_effects'] as List<dynamic>;
      if (frameEffects.contains('extendedart')) {
        variantType = 'extended';
      } else if (frameEffects.contains('showcase')) {
        variantType = 'showcase';
      } else if (frameEffects.contains('borderless')) {
        variantType = 'borderless';
      }
    }
    
    // Check for full art
    if (card.containsKey('full_art') && card['full_art'] == true) {
      variantType = 'fullart';
    }
    
    // Check promo status
    if (card.containsKey('promo') && card['promo'] == true) {
      variantType = 'promo';
    }
    
    // Check textless status
    if (card.containsKey('textless') && card['textless'] == true) {
      variantType = 'textless';
    }
    
    // For digital only cards
    if (card.containsKey('digital') && card['digital'] == true) {
      variantType = 'digital';
    }
    
    // Borderless and alternate art detection
    if (card.containsKey('border_color')) {
      final String borderColor = card['border_color'] as String;
      if (borderColor == 'borderless') {
        variantType = 'borderless';
      }
    }
    
    // Fetch specific frame types from Scryfall data
    if (card.containsKey('frame')) {
      final String frame = card['frame'] as String;
      if (frame == 'showcase') {
        variantType = 'showcase';
      }
    }
    
    // If we have variation or finishes, append to variant type
    if (card.containsKey('variation') && card['variation'] == true) {
      if (variantType == 'normal') {
        variantType = 'alternate';
      } else {
        variantType = 'alternate_$variantType';
      }
    }
    
    return variantType;
  }
  
  /// Builds a filename for the variant that includes all necessary information
  static String _buildVariantFileName(
    String cardName,
    String setCode,
    String collectorNumber,
    String variantType,
    int index,
  ) {
    return '${cardName}__${setCode.toUpperCase()}_${collectorNumber}_${variantType}_$index.jpg';
  }
}
