import 'package:interact/interact.dart';

/// Handles advanced configuration options for the CLI
class AdvancedConfig {
  /// Configures and returns the confidence threshold for card detection
  ///
  /// Returns the confidence threshold (percentage between 50-100)
  static int configureConfidenceThreshold() {
    final String thresholdInput =
        Input(
          prompt: 'Enter confidence threshold (50-100%):',
          defaultValue: '85',
          validator: (value) {
            final int? threshold = int.tryParse(value);
            return threshold != null && threshold >= 50 && threshold <= 100;
          },
        ).interact();

    return int.parse(thresholdInput);
  }

  /// Configures and returns whether to save debug images
  ///
  /// Returns true if debug images should be saved, false otherwise
  static bool configureDebugImageSaving() {
    return Confirm(
      prompt: 'Save debug images with detection information?',
      defaultValue: false,
    ).interact();
  }
}
