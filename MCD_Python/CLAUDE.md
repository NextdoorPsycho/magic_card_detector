# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Run Commands
- Run CLI version: `python magic_card_detector.py example results`
- Run web app: `python app.py`
- Run with visualization: `python magic_card_detector.py example results --visual`
- Run with verbose output: `python magic_card_detector.py example results --verbose`
- Run hash generation: `python save_hash.py`

## Code Style Guidelines
- Imports: Standard library first, then third-party, then local modules
- Formatting: 4-space indentation, 79-char line length
- Functions: Use docstrings for all functions and classes
- Variables: Use snake_case for variables and functions
- Classes: Use CamelCase for class names
- Error Handling: Use try/except blocks with specific exceptions
- Documentation: Maintain complete docstrings for all public functions and classes
- Typing: No strict typing enforcement but maintain consistent parameter passing