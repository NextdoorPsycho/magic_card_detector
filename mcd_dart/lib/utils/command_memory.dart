import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Handles saving and loading of previous command settings
class CommandMemory {
  static const String _memoryFileName = '.mcd_memory.json';
  static const int _maxCommandHistory = 2; // Number of commands to store

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

  /// Loads all stored commands from memory
  static Future<List<Map<String, dynamic>>> loadCommands() async {
    try {
      final File memoryFile = File(_getMemoryFilePath());
      if (!memoryFile.existsSync()) {
        return [];
      }

      final String fileContent = await memoryFile.readAsString();
      final List<dynamic> commands = jsonDecode(fileContent);
      return commands.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading commands: $e');
      return [];
    }
  }

  /// Loads a specific command by index (0 = most recent)
  static Future<Map<String, dynamic>?> loadCommandByIndex(int index) async {
    final commands = await loadCommands();
    if (commands.isEmpty || index >= commands.length) {
      return null;
    }
    return commands[index];
  }

  /// Loads the last (most recent) command
  static Future<Map<String, dynamic>?> loadLastCommand() async {
    return loadCommandByIndex(0);
  }

  /// Checks if previous commands exist
  static bool hasPreviousCommand() {
    final File memoryFile = File(_getMemoryFilePath());
    return memoryFile.existsSync();
  }

  /// Gets the number of stored commands
  static Future<int> getCommandCount() async {
    final commands = await loadCommands();
    return commands.length;
  }

  /// Gets a command description for display in the menu
  static Future<String> getCommandDescription(int index) async {
    final command = await loadCommandByIndex(index);
    if (command == null) {
      return 'Run Command #${index + 1}';
    }

    final String type = command['type'] as String;
    final Map<String, dynamic> params =
        command['parameters'] as Map<String, dynamic>;

    if (type == typeHashGeneration) {
      return 'Generate Hashes for ${params['setCode']} (${params['source']})';
    } else if (type == typeCardExtraction) {
      return 'Extract Cards from ${params['inputPath']} using ${params['selectedSet']}';
    } else {
      return 'Run Command #${index + 1}';
    }
  }

  /// Gets the last command description
  static Future<String> getLastCommandDescription() async {
    return getCommandDescription(0);
  }

  /// Gets the second-to-last command description
  static Future<String> getSecondLastCommandDescription() async {
    return getCommandDescription(1);
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
      final List<Map<String, dynamic>> commands = await loadCommands();
      
      // Add new command to the beginning of the list
      commands.insert(0, data);
      
      // Limit the number of stored commands
      while (commands.length > _maxCommandHistory) {
        commands.removeLast();
      }
      
      // Save the updated list
      final File memoryFile = File(_getMemoryFilePath());
      final String jsonData = jsonEncode(commands);
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
