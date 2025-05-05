# Command Memory Feature

This feature allows the CLI to remember the last command that was run, so users can quickly re-run it without having to enter all the parameters again.

## Testing the Command Memory Feature

You can test the command memory feature with the provided test script:

```bash
dart run test_command_memory.dart
```

This will:
1. Save a test hash generation command to the memory file
2. Load the command and display its contents
3. Get a formatted description of the command
4. Check if a previous command exists
5. Clear the memory
6. Verify that the memory was cleared

## Implementation Details

The command memory feature is implemented in the `CommandMemory` class in `lib/utils/command_memory.dart`.

Key aspects:
- Commands are stored in a JSON file named `.mcd_memory.json` in the current working directory
- Each saved command includes the command type, timestamp, and all parameters
- When the CLI starts, it checks if a previous command exists and adds it to the menu if one is found
- The menu option for the previous command includes a description of what it will do

## Adding More Command Types

To add additional command types:

1. Define a new constant in the `CommandMemory` class
2. Create a new save method (similar to `saveHashGenerationCommand` and `saveCardExtractionCommand`)
3. Update `getLastCommandDescription` to handle the new command type
4. Update `_runPreviousCommand` in `mcd_cli.dart` to handle the new command type