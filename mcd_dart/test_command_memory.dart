import 'package:mcd_dart/utils/command_memory.dart';

/// Simple test script to verify that the CommandMemory class works
Future<void> main() async {
  // Save a test command
  print('Saving test hash generation command...');
  await CommandMemory.saveHashGenerationCommand(
    setCode: 'TEST',
    source: 'Local',
    parallelism: 4,
    cleanup: true,
  );

  // Test that we can load and read the command
  print('Loading command...');
  final lastCommand = await CommandMemory.loadLastCommand();
  if (lastCommand != null) {
    print('Command loaded successfully!');
    print('Type: ${lastCommand['type']}');
    print('Parameters: ${lastCommand['parameters']}');

    // Get formatted description
    final description = await CommandMemory.getLastCommandDescription();
    print('Description: $description');

    // Test has previous command
    print('Has previous command: ${CommandMemory.hasPreviousCommand()}');

    // Clear memory
    print('Clearing memory...');
    await CommandMemory.clearMemory();

    // Verify cleared
    print(
      'Has previous command after clearing: ${CommandMemory.hasPreviousCommand()}',
    );
  } else {
    print('Failed to load command.');
  }

  print('Test complete.');
}
