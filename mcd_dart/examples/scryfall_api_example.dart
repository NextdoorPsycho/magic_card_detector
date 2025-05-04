import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:scryfall_api/scryfall_api.dart';

Future<void> main() async {
  // Create a Scryfall API client
  final scryfallClient = ScryfallApiClient();

  try {
    // Example 1: Search for all cards in a specific set (e.g., 'DSK' for Duskmorne)
    print('Searching for cards in set DSK...');
    final cards = await searchCardsBySet(scryfallClient, 'DSK');
    print('Found ${cards.totalCards} cards in set DSK');
    
    // Print the first few cards
    for (var i = 0; i < 5 && i < cards.data.length; i++) {
      final card = cards.data[i];
      print('- ${card.name} (${card.set}/${card.collectorNumber})');
      
      // Get and print image URLs for each card
      if (card.imageUris != null) {
        print('  Small image: ${card.imageUris!.small}');
        print('  Normal image: ${card.imageUris!.normal}');
        print('  Large image: ${card.imageUris!.large}');
        print('  PNG image: ${card.imageUris!.png}');
      } else if (card.cardFaces != null && card.cardFaces!.isNotEmpty) {
        // Handle double-faced cards
        print('  Front face image: ${card.cardFaces![0].imageUris?.normal}');
        if (card.cardFaces!.length > 1 && card.cardFaces![1].imageUris != null) {
          print('  Back face image: ${card.cardFaces![1].imageUris?.normal}');
        }
      }
    }
    
    // Example 2: Download an image for a specific card
    if (cards.data.isNotEmpty) {
      final firstCard = cards.data.first;
      await downloadCardImage(firstCard, 'dsk_card.jpg');
      print('\nDownloaded image for ${firstCard.name} to dsk_card.jpg');
    }
    
    // Example 3: Get a specific card by set code and collector number
    print('\nGetting a specific card by set code and collector number...');
    final specificCard = await scryfallClient.getCardBySetCodeAndCollectorNumber('DSK', '1');
    print('Retrieved card: ${specificCard.name}');
    
    // Example 4: Download a card image directly using Scryfall API
    print('\nDownloading card image directly using Scryfall API...');
    final imageBytes = await scryfallClient.getCardBySetCodeAndCollectorNumberAsImage(
      'DSK', 
      '1',
      imageVersion: ImageVersion.large
    );
    
    final directImageFile = File('dsk_direct_image.jpg');
    await directImageFile.writeAsBytes(imageBytes);
    print('Downloaded image directly to dsk_direct_image.jpg');

  } catch (e) {
    print('Error: $e');
  } finally {
    // Always close the client when done
    scryfallClient.close();
  }
}

// Function to search for cards in a specific set
Future<PaginableList<MtgCard>> searchCardsBySet(ScryfallApiClient client, String setCode) async {
  return await client.searchCards('set:$setCode');
}

// Function to get a card's image URL
Uri getCardImageUrl(MtgCard card, {bool highQuality = false}) {
  if (card.imageUris != null) {
    return highQuality ? card.imageUris!.png : card.imageUris!.large;
  } else if (card.cardFaces != null && 
             card.cardFaces!.isNotEmpty && 
             card.cardFaces![0].imageUris != null) {
    // For double-faced cards, return the front face
    return highQuality ? card.cardFaces![0].imageUris!.png : card.cardFaces![0].imageUris!.large;
  }
  
  throw Exception('No image found for card: ${card.name}');
}

// Function to download an image from URL
Future<void> downloadCardImage(MtgCard card, String outputPath) async {
  final imageUrl = getCardImageUrl(card);
  final response = await http.get(imageUrl);
  
  if (response.statusCode == 200) {
    final file = File(outputPath);
    await file.writeAsBytes(response.bodyBytes);
  } else {
    throw Exception('Failed to download image: ${response.statusCode}');
  }
}