import 'dart:math' as math;
// Import when needed
// import 'package:image/image.dart';

// Define our own Point2D class
class Point2D {
  final double x;
  final double y;
  
  const Point2D(this.x, this.y);
  
  // Helper methods for points
  double distanceTo(Point2D other) {
    double dx = x - other.x;
    double dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  @override
  String toString() => 'Point2D($x, $y)';
}

// Define Line class
class Line {
  final Point2D p1;
  final Point2D p2;
  
  const Line(this.p1, this.p2);
  
  // Create a line from two points
  factory Line.fromPoints(Point2D point1, Point2D point2) {
    return Line(point1, point2);
  }
  
  // Intersect this line with another line
  Point2D? intersect(Line other) {
    // Convert the lines to the format expected by lineIntersection
    List<double> x = [p1.x, p2.x, other.p1.x, other.p2.x];
    List<double> y = [p1.y, p2.y, other.p1.y, other.p2.y];
    
    Point2D intersection = lineIntersection(x, y);
    
    // Check if the lines are parallel (result will be NaN)
    if (intersection.x.isNaN || intersection.y.isNaN) {
      return null;
    }
    
    return intersection;
  }
}

// Define our own Polygon class
class Polygon {
  final List<Point2D> vertices;
  
  const Polygon(this.vertices);
  
  double area() {
    // Calculate area using Shoelace formula
    double area = 0.0;
    int n = vertices.length;
    
    for (int i = 0; i < n; i++) {
      Point2D current = vertices[i];
      Point2D next = vertices[(i + 1) % n];
      area += (current.x * next.y - next.x * current.y);
    }
    
    return area.abs() / 2.0;
  }
  
  double perimeter() {
    double perimeter = 0.0;
    int n = vertices.length;
    
    for (int i = 0; i < n; i++) {
      Point2D current = vertices[i];
      Point2D next = vertices[(i + 1) % n];
      perimeter += current.distanceTo(next);
    }
    
    return perimeter;
  }
  
  Point2D centroid() {
    // Calculate centroid
    double cx = 0.0;
    double cy = 0.0;
    
    for (var vertex in vertices) {
      cx += vertex.x;
      cy += vertex.y;
    }
    
    return Point2D(cx / vertices.length, cy / vertices.length);
  }
  
  bool contains(Polygon other) {
    // Check if all vertices of the other polygon are inside this one
    for (var vertex in other.vertices) {
      if (!_pointInPolygon(vertex)) {
        return false;
      }
    }
    return true;
  }
  
  bool _pointInPolygon(Point2D point) {
    // Ray casting algorithm to determine if a point is inside a polygon
    bool inside = false;
    int n = vertices.length;
    
    for (int i = 0, j = n - 1; i < n; j = i++) {
      if (((vertices[i].y > point.y) != (vertices[j].y > point.y)) &&
          (point.x < (vertices[j].x - vertices[i].x) * (point.y - vertices[i].y) / 
           (vertices[j].y - vertices[i].y) + vertices[i].x)) {
        inside = !inside;
      }
    }
    
    return inside;
  }
  
  Polygon? intersection(Polygon other) {
    // Simplified implementation: check if one contains the other
    if (contains(other)) {
      return other;
    } else if (other.contains(this)) {
      return this;
    }
    
    // For a more accurate intersection, we'd need a more complex algorithm
    // This is a simplification for the current use case
    return null;
  }
}

Point2D lineIntersection(List<double> x, List<double> y) {
  // Calculate the intersection point of two lines
  // Lines defined by points (x[0],y[0]), (x[1],y[1]) and (x[2],y[2]), (x[3],y[3])
  
  double slope0 = (x[0] - x[1]) * (y[2] - y[3]);
  double slope2 = (y[0] - y[1]) * (x[2] - x[3]);
  
  if (slope0 == slope2) {
    // Parallel lines
    return Point2D(double.nan, double.nan);
  }
  
  double xy01 = x[0] * y[1] - y[0] * x[1];
  double xy23 = x[2] * y[3] - y[2] * x[3];
  double denom = slope0 - slope2;
  
  double xis = (xy01 * (x[2] - x[3]) - (x[0] - x[1]) * xy23) / denom;
  double yis = (xy01 * (y[2] - y[3]) - (y[0] - y[1]) * xy23) / denom;
  
  return Point2D(xis, yis);
}

Polygon simplifyPolygon(Polygon inPoly, {double lengthCutoff = 0.15, int? maxIter, int? segmentToRemove}) {
  // Simplifies a polygon by removing short segments
  List<Point2D> points = List.from(inPoly.vertices);
  int lenPoly = points.length;
  int niter = 0;
  
  if (segmentToRemove != null) {
    maxIter = 1;
  }
  
  while (lenPoly > 4) {
    // Calculate distances between consecutive points
    List<double> distances = [];
    double dTotal = 0.0;
    
    for (int i = 0; i < lenPoly; i++) {
      int nextIdx = (i + 1) % lenPoly;
      double dx = points[i].x - points[nextIdx].x;
      double dy = points[i].y - points[nextIdx].y;
      double d = math.sqrt(dx * dx + dy * dy);
      distances.add(d);
      dTotal += d;
    }
    
    // Find shortest segment if not specified
    int k = segmentToRemove ?? distances.indexOf(distances.reduce(math.min));
    
    if (distances[k] < lengthCutoff * dTotal) {
      // Generate indices for the segments to extend
      List<int> ind = generatePointIndices(k - 1, k + 1, lenPoly);
      
      // Calculate new intersection point
      Point2D intersection = lineIntersection(
        [points[ind[0]].x, points[ind[1]].x, points[ind[2]].x, points[ind[3]].x],
        [points[ind[0]].y, points[ind[1]].y, points[ind[2]].y, points[ind[3]].y]
      );
      
      // Replace point K with intersection
      points[k] = intersection;
      
      // Remove the next point (shortens the polygon)
      points.removeAt((k + 1) % lenPoly);
      lenPoly = points.length;
      
      niter++;
      if (maxIter != null && niter >= maxIter) {
        break;
      }
    } else {
      break;
    }
  }
  
  return Polygon(points);
}

List<int> generatePointIndices(int index1, int index2, int maxLen) {
  // Returns the four indices for polygon segments
  return [
    index1 % maxLen,
    (index1 + 1) % maxLen,
    index2 % maxLen,
    (index2 + 1) % maxLen
  ];
}

List<Point2D> generateQuadCorners(List<int> indices, List<Point2D> points) {
  int i = indices[0], j = indices[1], k = indices[2], l = indices[3];
  List<double> x = points.map((p) => p.x).toList();
  List<double> y = points.map((p) => p.y).toList();
  
  List<Point2D> corners = List.filled(4, Point2D(double.nan, double.nan));
  
  if (j <= i || k <= j || l <= k) {
    return corners;
  }
  
  corners[0] = lineIntersection(
    [x[i], x[(i + 1) % points.length], x[j], x[(j + 1) % points.length]],
    [y[i], y[(i + 1) % points.length], y[j], y[(j + 1) % points.length]]
  );
  
  corners[1] = lineIntersection(
    [x[j], x[(j + 1) % points.length], x[k], x[(k + 1) % points.length]],
    [y[j], y[(j + 1) % points.length], y[k], y[(k + 1) % points.length]]
  );
  
  corners[2] = lineIntersection(
    [x[k], x[(k + 1) % points.length], x[l], x[(l + 1) % points.length]],
    [y[k], y[(k + 1) % points.length], y[l], y[(l + 1) % points.length]]
  );
  
  corners[3] = lineIntersection(
    [x[l], x[(l + 1) % points.length], x[i], x[(i + 1) % points.length]],
    [y[l], y[(l + 1) % points.length], y[i], y[(i + 1) % points.length]]
  );
  
  return corners;
}

List<Polygon> generateQuadCandidates(Polygon inPoly) {
  // Generate candidate quadrilaterals that bound the polygon
  
  // Sort the points in angular order
  List<Point2D> points = List.from(inPoly.vertices);
  
  // Calculate center
  double xAvg = 0, yAvg = 0;
  for (var p in points) {
    xAvg += p.x;
    yAvg += p.y;
  }
  xAvg /= points.length;
  yAvg /= points.length;
  
  // Create a slightly shrunken polygon to test containment
  List<Point2D> shrunkPoints = [];
  for (var p in points) {
    shrunkPoints.add(Point2D(
      xAvg + 0.9999 * (p.x - xAvg),
      yAvg + 0.9999 * (p.y - yAvg)
    ));
  }
  Polygon shrunkPoly = Polygon(shrunkPoints);
  
  List<Polygon> quads = [];
  
  // Generate all possible combinations of 4 line intersections
  // This is a simplification of the Python's itertools.product
  for (int i = 0; i < points.length; i++) {
    for (int j = i + 1; j < points.length; j++) {
      for (int k = j + 1; k < points.length; k++) {
        for (int l = k + 1; l < points.length; l++) {
          List<Point2D> corners = generateQuadCorners([i, j, k, l], points);
          
          // Check if any point is NaN (no intersection)
          bool hasNaN = corners.any((p) => p.x.isNaN || p.y.isNaN);
          if (hasNaN) continue;
          
          // Create a quad from the corners
          Polygon quad = Polygon(corners);
          
          // Test if the quad contains the original polygon
          if (quad.contains(shrunkPoly)) {
            quads.add(quad);
          }
        }
      }
    }
  }
  
  return quads;
}

Polygon getBoundingQuad(Polygon hullPoly) {
  // Get the minimum-area quadrilateral that bounds the given polygon
  
  Polygon simplePoly = simplifyPolygon(hullPoly);
  List<Polygon> boundingQuads = generateQuadCandidates(simplePoly);
  
  if (boundingQuads.isEmpty) {
    // If no quads were found, return the original polygon
    return hullPoly;
  }
  
  // Find the quad with minimum area
  Polygon minAreaQuad = boundingQuads[0];
  double minArea = minAreaQuad.area();
  
  for (int i = 1; i < boundingQuads.length; i++) {
    double area = boundingQuads[i].area();
    if (area < minArea) {
      minArea = area;
      minAreaQuad = boundingQuads[i];
    }
  }
  
  return minAreaQuad;
}

double quadCornerDiff(Polygon hullPoly, Polygon bquadPoly, [double regionSize = 0.9]) {
  // Calculate the difference between the quad corners and the hull
  List<Point2D> bquadCorners = bquadPoly.vertices;
  
  // Calculate quad center
  double xAvg = 0, yAvg = 0;
  for (var p in bquadCorners) {
    xAvg += p.x;
    yAvg += p.y;
  }
  xAvg /= bquadCorners.length;
  yAvg /= bquadCorners.length;
  
  // Calculate interior points (moved towards center by regionSize)
  List<Point2D> interiorPoints = [];
  for (var p in bquadCorners) {
    interiorPoints.add(Point2D(
      xAvg + regionSize * (p.x - xAvg),
      yAvg + regionSize * (p.y - yAvg)
    ));
  }
  
  // Calculate points for orthogonal line through interior point
  List<double> p0X = [], p1X = [], p0Y = [], p1Y = [];
  for (int i = 0; i < interiorPoints.length; i++) {
    p0X.add(interiorPoints[i].x + (bquadCorners[i].y - yAvg));
    p1X.add(interiorPoints[i].x - (bquadCorners[i].y - yAvg));
    p0Y.add(interiorPoints[i].y - (bquadCorners[i].x - xAvg));
    p1Y.add(interiorPoints[i].y + (bquadCorners[i].x - xAvg));
  }
  
  // Calculate corner area polygons
  double hullCornerArea = 0;
  double quadCornerArea = 0;
  
  for (int i = 0; i < bquadCorners.length; i++) {
    // Create a line from p0 to p1
    Line line = Line.fromPoints(
      Point2D(p0X[i], p0Y[i]),
      Point2D(p1X[i], p1Y[i])
    );
    
    // Find intersection of line with quad
    List<Point2D> intersections = [];
    for (int j = 0; j < bquadCorners.length; j++) {
      int next = (j + 1) % bquadCorners.length;
      Line edge = Line.fromPoints(bquadCorners[j], bquadCorners[next]);
      Point2D? intersection = line.intersect(edge);
      if (intersection != null) {
        intersections.add(intersection);
      }
    }
    
    if (intersections.length < 2) continue;
    
    // Create corner polygon from two intersection points and corner
    List<Point2D> cornerPoints = [
      intersections[0],
      intersections[1],
      bquadCorners[i]
    ];
    Polygon cornerPoly = Polygon(cornerPoints);
    
    // Add to areas
    quadCornerArea += cornerPoly.area();
    
    // Calculate intersection with hull
    Polygon? intersection = cornerPoly.intersection(hullPoly);
    if (intersection != null) {
      hullCornerArea += intersection.area();
    }
  }
  
  return quadCornerArea > 0 ? 1.0 - hullCornerArea / quadCornerArea : 0.0;
}

Polygon convexHullPolygon(List<List<int>> contour) {
  // OpenCV contour to convex hull polygon
  
  // Extract points from contour format
  List<Point2D> points = [];
  for (var point in contour) {
    points.add(Point2D(point[0].toDouble(), point[1].toDouble()));
  }
  
  // Calculate convex hull using Graham scan algorithm
  List<Point2D> hull = grahamScan(points);
  return Polygon(hull);
}

List<Point2D> grahamScan(List<Point2D> points) {
  if (points.length <= 3) return List.from(points);
  
  // Find the point with lowest y-coordinate (and leftmost if tied)
  Point2D pivot = points[0];
  for (int i = 1; i < points.length; i++) {
    if (points[i].y < pivot.y || 
        (points[i].y == pivot.y && points[i].x < pivot.x)) {
      pivot = points[i];
    }
  }
  
  // Sort points by polar angle with respect to pivot
  List<Point2D> sortedPoints = List.from(points);
  sortedPoints.remove(pivot);
  
  sortedPoints.sort((a, b) {
    double angleA = math.atan2(a.y - pivot.y, a.x - pivot.x);
    double angleB = math.atan2(b.y - pivot.y, b.x - pivot.x);
    
    if (angleA < angleB) return -1;
    if (angleA > angleB) return 1;
    
    // If angles are equal, take the point farther from pivot
    double distA = (a.x - pivot.x) * (a.x - pivot.x) + 
                   (a.y - pivot.y) * (a.y - pivot.y);
    double distB = (b.x - pivot.x) * (b.x - pivot.x) + 
                   (b.y - pivot.y) * (b.y - pivot.y);
    
    return distA > distB ? -1 : 1;
  });
  
  // Build hull
  List<Point2D> hull = [pivot, sortedPoints[0]];
  
  for (int i = 1; i < sortedPoints.length; i++) {
    while (hull.length > 1 && 
           !isLeftTurn(hull[hull.length - 2], hull[hull.length - 1], sortedPoints[i])) {
      hull.removeLast();
    }
    hull.add(sortedPoints[i]);
  }
  
  return hull;
}

bool isLeftTurn(Point2D a, Point2D b, Point2D c) {
  return ((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) > 0;
}

double polygonFormFactor(Polygon poly) {
  // Calculate the form factor (ratio of area to perimeter scaled by min edge)
  List<Point2D> points = poly.vertices;
  
  // Find minimum side length
  double minLength = double.infinity;
  for (int i = 0; i < points.length; i++) {
    int next = (i + 1) % points.length;
    double dx = points[i].x - points[next].x;
    double dy = points[i].y - points[next].y;
    double dist = math.sqrt(dx * dx + dy * dy);
    if (dist < minLength) {
      minLength = dist;
    }
  }
  
  // Calculate perimeter
  double perimeter = poly.perimeter();
  
  return poly.area() / (perimeter * minLength);
}

class CardContourResult {
  final bool continueSegmentation;
  final bool isCardCandidate;
  final Polygon? boundingPoly;
  final double cropFactor;
  
  CardContourResult(
    this.continueSegmentation,
    this.isCardCandidate,
    this.boundingPoly,
    this.cropFactor
  );
}

CardContourResult characterizeCardContour(
    List<List<int>> cardContour,
    double maxSegmentArea,
    double imageArea) {
  
  try {
    Polygon phull = convexHullPolygon(cardContour);
    
    if (phull.area() < 0.1 * maxSegmentArea || phull.area() < imageArea / 1000.0) {
      // Too small to be a card, or we've explored enough of the image
      return CardContourResult(false, false, null, 1.0);
    }
    
    Polygon boundingPoly = getBoundingQuad(phull);
    double qcDiff = quadCornerDiff(phull, boundingPoly);
    double cropFactor = math.min(1.0, (1.0 - qcDiff * 22.0 / 100.0));
    
    bool isCardCandidate = 
      0.1 * maxSegmentArea < boundingPoly.area() &&
      boundingPoly.area() < imageArea * 0.99 &&
      qcDiff < 0.35 &&
      0.25 < polygonFormFactor(boundingPoly) && 
      polygonFormFactor(boundingPoly) < 0.33;
    
    return CardContourResult(true, isCardCandidate, boundingPoly, cropFactor);
  } catch (e) {
    // Handle exceptions (e.g., degenerate geometries)
    print('Error in characterizeCardContour: $e');
    return CardContourResult(true, false, null, 1.0);
  }
}