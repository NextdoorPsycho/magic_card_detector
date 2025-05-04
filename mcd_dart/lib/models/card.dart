// Import when needed
// import 'dart:typed_data';
import 'package:image/image.dart';
import '../geometry/polygons.dart';

class CardCandidate {
  final Image image;
  final Polygon boundingQuad;
  final double imageAreaFraction;
  bool isRecognized;
  double recognitionScore;
  bool isFragment;
  String name;

  CardCandidate(
    this.image,
    this.boundingQuad,
    this.imageAreaFraction, {
    this.isRecognized = false,
    this.recognitionScore = 0.0,
    this.isFragment = false,
    this.name = 'unknown',
  });

  bool contains(CardCandidate other) {
    return boundingQuad.contains(other.boundingQuad) && name == other.name;
  }
}