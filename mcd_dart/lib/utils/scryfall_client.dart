import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as path;
import 'package:scryfall_api/scryfall_api.dart';
import 'package:http/http.dart' as http;

/// A client for fetching Magic card data and images from Scryfall API
class ScryfallClient {
  final ScryfallApiClient _client;
  final bool verbose;

  /// Directory where temporary downloaded images are stored
  final String? cacheDir;

  ScryfallClient({
    this.verbose = false,
    this.cacheDir,
  }) : _client = ScryfallApiClient();

  /// Close the client and cleanup resources
  void close() {
    _client.close();
  }

  /// Get all cards from a specific set by set code
  Future<List<MtgCard>> getCardsBySetCode(String setCode) async {
    if (verbose) {
      info('Fetching cards for set: $setCode');
    }

    final cards = <MtgCard>[];
    
    try {
      // Get the first page of results
      final searchResult = await _client.searchCards('set:$setCode');
      cards.addAll(searchResult.data);
      
      // Get all subsequent pages if any
      PaginableList<MtgCard>? currentPage = searchResult;
      while (currentPage?.hasMore == true) {
        // Handle pagination manually since getNextPage isn't available
        final nextPageUri = currentPage!.nextPage;
        if (nextPageUri == null) break;
        
        final response = await http.get(nextPageUri);
        if (response.statusCode != 200) {
          throw Exception('Failed to fetch next page: ${response.statusCode}');
        }
        
        // Parse the response body as JSON map
        final jsonMap = json.decode(response.body) as Map<String, dynamic>;
        final nextPage = PaginableList<MtgCard>.fromJson(
          jsonMap, 
          (json) => MtgCard.fromJson(json as Map<String, dynamic>)
        );
        
        cards.addAll(nextPage.data);
        currentPage = nextPage;
      }
      
      if (verbose) {
        success('Found ${cards.length} cards in set $setCode');
      }
      
      return cards;
    } catch (e) {
      error('Error fetching cards for set $setCode: $e');
      rethrow;
    }
  }

  /// Get image URL for a card, handling double-faced cards
  String? getCardImageUrl(MtgCard card, {ImageSize size = ImageSize.large}) {
    // For normal cards
    if (card.imageUris != null) {
      return _getImageUrlBySize(card.imageUris!, size);
    }
    // For double-faced cards, return front face
    else if (card.cardFaces != null && card.cardFaces!.isNotEmpty) {
      return _getImageUrlBySize(card.cardFaces!.first.imageUris!, size);
    }
    return null;
  }

  /// Helper to get image URL based on requested size
  String? _getImageUrlBySize(ImageUris uris, ImageSize size) {
    switch (size) {
      case ImageSize.small:
        return uris.small.toString();
      case ImageSize.normal:
        return uris.normal.toString();
      case ImageSize.large:
        return uris.large.toString();
      case ImageSize.png:
        return uris.png.toString();
      case ImageSize.artCrop:
        return uris.artCrop.toString();
      case ImageSize.borderCrop:
        return uris.borderCrop.toString();
    }
  }

  /// Download a card image by set code and collector number
  Future<Uint8List> downloadCardImage(String setCode, String collectorNumber,
      {ImageSize size = ImageSize.large}) async {
    try {
      if (verbose) {
        info('Downloading image for card: $setCode #$collectorNumber');
      }

      final imageBytes = await _client.getCardBySetCodeAndCollectorNumberAsImage(
        setCode,
        collectorNumber,
        imageVersion: _getApiImageVersion(size),
      );

      if (verbose) {
        success('Downloaded image: $setCode #$collectorNumber (${imageBytes.length} bytes)');
      }

      return imageBytes;
    } catch (e) {
      error('Error downloading image for card $setCode #$collectorNumber: $e');
      rethrow;
    }
  }

  /// Download a card image from a URL
  Future<Uint8List> downloadImageFromUrl(String url) async {
    try {
      if (verbose) {
        info('Downloading image from URL: $url');
      }

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
      
      if (verbose) {
        success('Downloaded image: ${response.bodyBytes.length} bytes');
      }

      return response.bodyBytes;
    } catch (e) {
      error('Error downloading image from URL: $e');
      rethrow;
    }
  }

  /// Download all card images for a set and save to a directory
  Future<List<String>> downloadSetImages(String setCode, String outputDir,
      {ImageSize size = ImageSize.large}) async {
    final cards = await getCardsBySetCode(setCode);
    final downloadedFiles = <String>[];
    
    // Create output directory if it doesn't exist
    final directory = Directory(outputDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    for (final card in cards) {
      try {
        // Skip cards without images (like tokens or special card entries)
        String? imageUrl = getCardImageUrl(card, size: size);
        if (imageUrl == null) {
          warn('No image available for card: ${card.name}');
          continue;
        }
        
        // Generate a safe filename
        final filename = '${card.name.replaceAll(RegExp(r'[^\w\s]'), '_')}_${card.collectorNumber}.jpg';
        final filePath = path.join(outputDir, filename);
        
        // Download the image
        final imageBytes = await downloadImageFromUrl(imageUrl);
        
        // Save to file
        await File(filePath).writeAsBytes(imageBytes);
        downloadedFiles.add(filePath);
        
        if (verbose) {
          info('Saved: $filename');
        }
        
        // Be nice to the Scryfall API - add a small delay between requests
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        warn('Error downloading card ${card.name}: $e');
      }
    }
    
    return downloadedFiles;
  }

  /// Convert our ImageSize enum to Scryfall API's ImageVersion
  ImageVersion _getApiImageVersion(ImageSize size) {
    switch (size) {
      case ImageSize.small:
        return ImageVersion.small;
      case ImageSize.normal:
        return ImageVersion.normal;
      case ImageSize.large:
        return ImageVersion.large;
      case ImageSize.png:
        return ImageVersion.png;
      case ImageSize.artCrop:
        return ImageVersion.artCrop;
      case ImageSize.borderCrop:
        return ImageVersion.borderCrop;
    }
  }
}

/// Image size options for card downloads
enum ImageSize {
  small,
  normal,
  large,
  png, // High quality
  artCrop,
  borderCrop,
}