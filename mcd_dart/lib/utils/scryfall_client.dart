import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Client for interacting with the Scryfall API to download card images
class ScryfallClient {
  static const String _baseUrl = 'https://api.scryfall.com';
  
  /// Get all cards from a specific set
  /// 
  /// [setCode] - The three-letter code for the set (e.g., 'LEA', 'DSK')
  static Future<List<Map<String, dynamic>>> getCardsFromSet(String setCode) async {
    final String url = '$_baseUrl/cards/search?q=set:${setCode.toLowerCase()}&unique=prints';
    final List<Map<String, dynamic>> allCards = [];
    
    String? nextPage = url;
    
    while (nextPage != null) {
      final http.Response response = await http.get(Uri.parse(nextPage));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load cards from Scryfall: ${response.statusCode} - ${response.body}');
      }
      
      final Map<String, dynamic> data = json.decode(response.body);
      
      // Add all cards from this page to our collection
      final List<dynamic> cards = data['data'] as List<dynamic>;
      for (final card in cards) {
        allCards.add(card as Map<String, dynamic>);
      }
      
      // Check if there's another page of results
      nextPage = data['has_more'] == true ? data['next_page'] as String : null;
    }
    
    return allCards;
  }
  
  /// Download an image from a URL to a local file
  ///
  /// [imageUrl] - The URL of the image to download
  /// [outputPath] - The path where the image should be saved
  static Future<File> downloadImage(String imageUrl, String outputPath) async {
    final http.Response response = await http.get(Uri.parse(imageUrl));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download image from $imageUrl: ${response.statusCode}');
    }
    
    final File file = File(outputPath);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
  
  /// Download all cards from a set
  ///
  /// [setCode] - The three-letter code for the set (e.g., 'LEA', 'DSK')
  /// [outputDir] - The directory where images should be saved
  /// [parallelism] - Number of concurrent downloads
  /// [progressCallback] - Callback function to report progress (index, total, cardName)
  static Future<List<String>> downloadSetImages(
    String setCode,
    String outputDir,
    int parallelism,
    void Function(int, int, String)? progressCallback,
  ) async {
    // Create the output directory if it doesn't exist
    final Directory dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    
    // Get all cards from the set
    final List<Map<String, dynamic>> cards = await getCardsFromSet(setCode);
    final List<String> downloadedFiles = [];
    
    // Process cards in batches based on parallelism
    for (int i = 0; i < cards.length; i += parallelism) {
      final int endIndex = (i + parallelism) < cards.length ? i + parallelism : cards.length;
      final List<Map<String, dynamic>> batch = cards.sublist(i, endIndex);
      
      final List<Future<void>> downloads = [];
      
      for (int j = 0; j < batch.length; j++) {
        final int currentIndex = i + j;
        final Map<String, dynamic> card = batch[j];
        
        if (card.containsKey('image_uris') && (card['image_uris'] as Map<String, dynamic>).containsKey('large')) {
          final String imageUrl = card['image_uris']['large'] as String;
          final String cardName = card['name'] as String;
          final String safeCardName = cardName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          final String imagePath = path.join(outputDir, '${safeCardName}_$currentIndex.jpg');
          
          downloads.add(
            downloadImage(imageUrl, imagePath).then((file) {
              downloadedFiles.add(file.path);
              if (progressCallback != null) {
                progressCallback(currentIndex + 1, cards.length, cardName);
              }
            }).catchError((e) {
              print('Error downloading $cardName: $e');
            }),
          );
        } else if (card.containsKey('card_faces') && 
                  (card['card_faces'] as List<dynamic>).isNotEmpty &&
                  ((card['card_faces'] as List<dynamic>)[0] as Map<String, dynamic>).containsKey('image_uris')) {
          // Handle double-faced cards
          final String imageUrl = (card['card_faces'][0] as Map<String, dynamic>)['image_uris']['large'] as String;
          final String cardName = card['name'] as String;
          final String safeCardName = cardName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          final String imagePath = path.join(outputDir, '${safeCardName}_$currentIndex.jpg');
          
          downloads.add(
            downloadImage(imageUrl, imagePath).then((file) {
              downloadedFiles.add(file.path);
              if (progressCallback != null) {
                progressCallback(currentIndex + 1, cards.length, cardName);
              }
            }).catchError((e) {
              print('Error downloading $cardName: $e');
            }),
          );
        } else {
          if (progressCallback != null) {
            progressCallback(currentIndex + 1, cards.length, card['name'] as String);
          }
          print('Warning: No suitable image found for ${card['name'] as String}');
        }
      }
      
      // Wait for all downloads in this batch to complete
      await Future.wait(downloads);
    }
    
    return downloadedFiles;
  }
}