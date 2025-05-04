import 'dart:io';
import 'dart:convert';
import 'package:scryfall_api/scryfall_api.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// Note: This is a skeleton example and would need to be integrated with your actual
// hash generation logic from your project

Future<void> main() async {
  // Set code to fetch (e.g., 'DSK' for Duskmorne)
  String setCode = 'DSK';
  
  // Create output directory for downloaded images
  final tempImageDir = Directory(path.join(Directory.current.path, 'temp_images'));
  if (!await tempImageDir.exists()) {
    await tempImageDir.create(recursive: true);
  }
  
  // Create a Scryfall API client
  final scryfallClient = ScryfallApiClient();
  
  try {
    print('Fetching all cards from set $setCode...');
    
    // Search for all cards in the set
    final searchResult = await scryfallClient.searchCards('set:$setCode');
    print('Found ${searchResult.totalCards} cards in set $setCode');
    
    // Process all pages of results
    var allCards = searchResult.data;
    var nextPage = searchResult.hasMore ? searchResult.nextPage : null;
    
    while (nextPage != null) {
      // Need to fetch the next page manually since the page param should be int
      final response = await http.get(nextPage);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch next page: ${response.statusCode}');
      }
      
      // Parse the response body as JSON map
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      final nextPageResult = PaginableList<MtgCard>.fromJson(
        jsonMap, 
        (json) => MtgCard.fromJson(json as Map<String, dynamic>)
      );
      
      allCards.addAll(nextPageResult.data);
      nextPage = nextPageResult.hasMore ? nextPageResult.nextPage : null;
    }
    
    print('Processing ${allCards.length} cards...');
    
    // Download and process images for each card
    for (var i = 0; i < allCards.length; i++) {
      final card = allCards[i];
      print('Processing ${i+1}/${allCards.length}: ${card.name} (${card.set}/${card.collectorNumber})');
      
      try {
        // Get image URL
        final imageUrl = getCardImageUrl(card);
        final imagePath = path.join(tempImageDir.path, '${card.set}_${card.collectorNumber}.jpg');
        
        // Download image
        await downloadImage(imageUrl, imagePath);
        
        // Here you would add code to generate hash for the downloaded image
        // For example:
        // final hash = await generateImageHash(imagePath);
        // await saveHashToDatabase(card.id, card.set, card.collectorNumber, hash);
        
        print('  Processed image for ${card.name}');
      } catch (e) {
        print('  Error processing ${card.name}: $e');
      }
      
      // Add a small delay to avoid hitting rate limits
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    print('Completed processing all cards from set $setCode');
    
  } catch (e) {
    print('Error: $e');
  } finally {
    // Close the client when done
    scryfallClient.close();
  }
}

// Function to get the image URL from a card
Uri getCardImageUrl(MtgCard card) {
  // Check if card has normal image URIs
  if (card.imageUris != null) {
    return card.imageUris!.large;
  } 
  // Check if it's a double-faced card
  else if (card.cardFaces != null && 
           card.cardFaces!.isNotEmpty && 
           card.cardFaces![0].imageUris != null) {
    return card.cardFaces![0].imageUris!.large;
  }
  
  throw Exception('No image found for card: ${card.name}');
}

// Function to download an image from a URL
Future<void> downloadImage(Uri url, String savePath) async {
  final response = await http.get(url);
  
  if (response.statusCode == 200) {
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
  } else {
    throw Exception('Failed to download image: ${response.statusCode}');
  }
}

// Placeholder for your hash generation function
Future<String> generateImageHash(String imagePath) async {
  // Here you would implement your project's hash generation logic
  // For example:
  // final image = await decodeImageFromFile(imagePath);
  // return computePerceptualHash(image);
  return 'hash_placeholder';
}

// Placeholder for saving hash to your database or file
Future<void> saveHashToDatabase(String cardId, String setCode, String collectorNumber, String hash) async {
  // Here you would implement your project's hash storage logic
  // For example, save to a file:
  // final hashFile = File('${setCode}_hashes.dat');
  // await hashFile.writeAsString('$cardId,$setCode,$collectorNumber,$hash\n', mode: FileMode.append);
}