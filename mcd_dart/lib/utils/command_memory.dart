import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Handles saving and loading of previous command settings
class CommandMemory {
  static const String _memoryFileName = '.mcd_memory.json';

  /// Command types for different operations
  static const String typeHashGeneration = 'hash_generation';
  static const String typeCardExtraction = 'card_extraction';

  /// Saves the hash generation command parameters to memory
  static Future<bool> saveHashGenerationCommand({
    required String setCode,
    required String source,
    required int parallelism,
    required bool cleanup,
  }) async {
    final Map<String, dynamic> commandData = {
      'type': typeHashGeneration,
      'timestamp': DateTime.now().toIso8601String(),
      'parameters': {
        'setCode': setCode,
        'source': source,
        'parallelism': parallelism,
        'cleanup': cleanup,
      },
    };

    return _saveCommandData(commandData);
  }

  /// Saves the card extraction command parameters to memory
  static Future<bool> saveCardExtractionCommand({
    required String selectedSet,
    required String outputPath,
    required String inputPath,
    required int confidenceThreshold,
    required bool saveDebugImages,
  }) async {
    final Map<String, dynamic> commandData = {
      'type': typeCardExtraction,
      'timestamp': DateTime.now().toIso8601String(),
      'parameters': {
        'selectedSet': selectedSet,
        'outputPath': outputPath,
        'inputPath': inputPath,
        'confidenceThreshold': confidenceThreshold,
        'saveDebugImages': saveDebugImages,
      },
    };

    return _saveCommandData(commandData);
  }

  /// Loads the last command from memory
  static Future<Map<String, dynamic>?> loadLastCommand() async {
    try {
      final File memoryFile = File(_getMemoryFilePath());
      if (!memoryFile.existsSync()) {
        return null;
      }

      final String fileContent = await memoryFile.readAsString();
      return jsonDecode(fileContent) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading last command: $e');
      return null;
    }
  }

  /// Checks if a previous command exists
  static bool hasPreviousCommand() {
    final File memoryFile = File(_getMemoryFilePath());
    return memoryFile.existsSync();
  }

  /// Gets the command description for display in the menu
  static Future<String> getLastCommandDescription() async {
    final lastCommand = await loadLastCommand();
    if (lastCommand == null) {
      return 'Run Previous Command';
    }

    final String type = lastCommand['type'] as String;
    final Map<String, dynamic> params =
        lastCommand['parameters'] as Map<String, dynamic>;

    if (type == typeHashGeneration) {
      return 'Generate Hashes for ${params['setCode']} (${params['source']})';
    } else if (type == typeCardExtraction) {
      return 'Extract Cards from ${params['inputPath']} using ${params['selectedSet']}';
    } else {
      return 'Run Previous Command';
    }
  }

  /// Deletes the memory file
  static Future<void> clearMemory() async {
    final File memoryFile = File(_getMemoryFilePath());
    if (memoryFile.existsSync()) {
      await memoryFile.delete();
    }
  }

  /// Internal helper to save command data to file
  static Future<bool> _saveCommandData(Map<String, dynamic> data) async {
    try {
      final File memoryFile = File(_getMemoryFilePath());
      final String jsonData = jsonEncode(data);
      await memoryFile.writeAsString(jsonData);
      return true;
    } catch (e) {
      print('Error saving command: $e');
      return false;
    }
  }

  /// Gets the path to the memory file
  static String _getMemoryFilePath() {
    return path.join(Directory.current.path, _memoryFileName);
  }
}
