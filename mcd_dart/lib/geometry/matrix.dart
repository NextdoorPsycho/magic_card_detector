// Simple vector and matrix classes for the perspective transform
class Vector4 {
  double x;
  double y;
  double z;
  double w;
  
  Vector4(this.x, this.y, this.z, this.w);
  
  @override
  String toString() => 'Vector4($x, $y, $z, $w)';
}

class Matrix4 {
  // Row-major order: data[row][column]
  List<List<double>> data;
  
  Matrix4(double a, double b, double c, double d,
          double e, double f, double g, double h,
          double i, double j, double k, double l,
          double m, double n, double o, double p)
      : data = [
          [a, b, c, d],
          [e, f, g, h],
          [i, j, k, l],
          [m, n, o, p]
        ];
  
  factory Matrix4.clone(Matrix4 other) {
    return Matrix4(
      other.data[0][0], other.data[0][1], other.data[0][2], other.data[0][3],
      other.data[1][0], other.data[1][1], other.data[1][2], other.data[1][3],
      other.data[2][0], other.data[2][1], other.data[2][2], other.data[2][3],
      other.data[3][0], other.data[3][1], other.data[3][2], other.data[3][3]
    );
  }
  
  // A simplified 3D transform method
  Vector4 transform(Vector4 v) {
    // Perform matrix multiplication
    final x = data[0][0] * v.x + data[0][1] * v.y + data[0][2] * v.z + data[0][3] * v.w;
    final y = data[1][0] * v.x + data[1][1] * v.y + data[1][2] * v.z + data[1][3] * v.w;
    final z = data[2][0] * v.x + data[2][1] * v.y + data[2][2] * v.z + data[2][3] * v.w;
    final w = data[3][0] * v.x + data[3][1] * v.y + data[3][2] * v.z + data[3][3] * v.w;
    
    return Vector4(x, y, z, w);
  }
  
  // Inverts the matrix for perspective transform
  void invert() {
    final det = determinant();
    if (det.abs() < 1e-10) {
      throw Exception('Matrix is singular and cannot be inverted');
    }
    
    // Create a temporary copy of the matrix
    final temp = Matrix4.clone(this);
    
    // Calculate the adjugate matrix
    data[0][0] = (temp.data[1][1] * (temp.data[2][2] * temp.data[3][3] - temp.data[2][3] * temp.data[3][2]) -
                  temp.data[1][2] * (temp.data[2][1] * temp.data[3][3] - temp.data[2][3] * temp.data[3][1]) +
                  temp.data[1][3] * (temp.data[2][1] * temp.data[3][2] - temp.data[2][2] * temp.data[3][1])) / det;
    
    data[0][1] = (temp.data[0][1] * (temp.data[2][3] * temp.data[3][2] - temp.data[2][2] * temp.data[3][3]) +
                  temp.data[0][2] * (temp.data[2][1] * temp.data[3][3] - temp.data[2][3] * temp.data[3][1]) +
                  temp.data[0][3] * (temp.data[2][2] * temp.data[3][1] - temp.data[2][1] * temp.data[3][2])) / det;
    
    data[0][2] = (temp.data[0][1] * (temp.data[1][2] * temp.data[3][3] - temp.data[1][3] * temp.data[3][2]) +
                  temp.data[0][2] * (temp.data[1][3] * temp.data[3][1] - temp.data[1][1] * temp.data[3][3]) +
                  temp.data[0][3] * (temp.data[1][1] * temp.data[3][2] - temp.data[1][2] * temp.data[3][1])) / det;
    
    data[0][3] = (temp.data[0][1] * (temp.data[1][3] * temp.data[2][2] - temp.data[1][2] * temp.data[2][3]) +
                  temp.data[0][2] * (temp.data[1][1] * temp.data[2][3] - temp.data[1][3] * temp.data[2][1]) +
                  temp.data[0][3] * (temp.data[1][2] * temp.data[2][1] - temp.data[1][1] * temp.data[2][2])) / det;
    
    data[1][0] = (temp.data[1][0] * (temp.data[2][3] * temp.data[3][2] - temp.data[2][2] * temp.data[3][3]) +
                  temp.data[1][2] * (temp.data[2][0] * temp.data[3][3] - temp.data[2][3] * temp.data[3][0]) +
                  temp.data[1][3] * (temp.data[2][2] * temp.data[3][0] - temp.data[2][0] * temp.data[3][2])) / det;
    
    data[1][1] = (temp.data[0][0] * (temp.data[2][2] * temp.data[3][3] - temp.data[2][3] * temp.data[3][2]) +
                  temp.data[0][2] * (temp.data[2][3] * temp.data[3][0] - temp.data[2][0] * temp.data[3][3]) +
                  temp.data[0][3] * (temp.data[2][0] * temp.data[3][2] - temp.data[2][2] * temp.data[3][0])) / det;
    
    data[1][2] = (temp.data[0][0] * (temp.data[1][3] * temp.data[3][2] - temp.data[1][2] * temp.data[3][3]) +
                  temp.data[0][2] * (temp.data[1][0] * temp.data[3][3] - temp.data[1][3] * temp.data[3][0]) +
                  temp.data[0][3] * (temp.data[1][2] * temp.data[3][0] - temp.data[1][0] * temp.data[3][2])) / det;
    
    data[1][3] = (temp.data[0][0] * (temp.data[1][2] * temp.data[2][3] - temp.data[1][3] * temp.data[2][2]) +
                  temp.data[0][2] * (temp.data[1][3] * temp.data[2][0] - temp.data[1][0] * temp.data[2][3]) +
                  temp.data[0][3] * (temp.data[1][0] * temp.data[2][2] - temp.data[1][2] * temp.data[2][0])) / det;
    
    data[2][0] = (temp.data[1][0] * (temp.data[2][1] * temp.data[3][3] - temp.data[2][3] * temp.data[3][1]) +
                  temp.data[1][1] * (temp.data[2][3] * temp.data[3][0] - temp.data[2][0] * temp.data[3][3]) +
                  temp.data[1][3] * (temp.data[2][0] * temp.data[3][1] - temp.data[2][1] * temp.data[3][0])) / det;
    
    data[2][1] = (temp.data[0][0] * (temp.data[2][3] * temp.data[3][1] - temp.data[2][1] * temp.data[3][3]) +
                  temp.data[0][1] * (temp.data[2][0] * temp.data[3][3] - temp.data[2][3] * temp.data[3][0]) +
                  temp.data[0][3] * (temp.data[2][1] * temp.data[3][0] - temp.data[2][0] * temp.data[3][1])) / det;
    
    data[2][2] = (temp.data[0][0] * (temp.data[1][1] * temp.data[3][3] - temp.data[1][3] * temp.data[3][1]) +
                  temp.data[0][1] * (temp.data[1][3] * temp.data[3][0] - temp.data[1][0] * temp.data[3][3]) +
                  temp.data[0][3] * (temp.data[1][0] * temp.data[3][1] - temp.data[1][1] * temp.data[3][0])) / det;
    
    data[2][3] = (temp.data[0][0] * (temp.data[1][3] * temp.data[2][1] - temp.data[1][1] * temp.data[2][3]) +
                  temp.data[0][1] * (temp.data[1][0] * temp.data[2][3] - temp.data[1][3] * temp.data[2][0]) +
                  temp.data[0][3] * (temp.data[1][1] * temp.data[2][0] - temp.data[1][0] * temp.data[2][1])) / det;
    
    data[3][0] = (temp.data[1][0] * (temp.data[2][2] * temp.data[3][1] - temp.data[2][1] * temp.data[3][2]) +
                  temp.data[1][1] * (temp.data[2][0] * temp.data[3][2] - temp.data[2][2] * temp.data[3][0]) +
                  temp.data[1][2] * (temp.data[2][1] * temp.data[3][0] - temp.data[2][0] * temp.data[3][1])) / det;
    
    data[3][1] = (temp.data[0][0] * (temp.data[2][1] * temp.data[3][2] - temp.data[2][2] * temp.data[3][1]) +
                  temp.data[0][1] * (temp.data[2][2] * temp.data[3][0] - temp.data[2][0] * temp.data[3][2]) +
                  temp.data[0][2] * (temp.data[2][0] * temp.data[3][1] - temp.data[2][1] * temp.data[3][0])) / det;
    
    data[3][2] = (temp.data[0][0] * (temp.data[1][2] * temp.data[3][1] - temp.data[1][1] * temp.data[3][2]) +
                  temp.data[0][1] * (temp.data[1][0] * temp.data[3][2] - temp.data[1][2] * temp.data[3][0]) +
                  temp.data[0][2] * (temp.data[1][1] * temp.data[3][0] - temp.data[1][0] * temp.data[3][1])) / det;
    
    data[3][3] = (temp.data[0][0] * (temp.data[1][1] * temp.data[2][2] - temp.data[1][2] * temp.data[2][1]) +
                  temp.data[0][1] * (temp.data[1][2] * temp.data[2][0] - temp.data[1][0] * temp.data[2][2]) +
                  temp.data[0][2] * (temp.data[1][0] * temp.data[2][1] - temp.data[1][1] * temp.data[2][0])) / det;
  }
  
  double determinant() {
    // Complete 4x4 matrix determinant calculation
    return 
      data[0][0] * (
        data[1][1] * (data[2][2] * data[3][3] - data[2][3] * data[3][2]) -
        data[1][2] * (data[2][1] * data[3][3] - data[2][3] * data[3][1]) +
        data[1][3] * (data[2][1] * data[3][2] - data[2][2] * data[3][1])
      ) -
      data[0][1] * (
        data[1][0] * (data[2][2] * data[3][3] - data[2][3] * data[3][2]) -
        data[1][2] * (data[2][0] * data[3][3] - data[2][3] * data[3][0]) +
        data[1][3] * (data[2][0] * data[3][2] - data[2][2] * data[3][0])
      ) +
      data[0][2] * (
        data[1][0] * (data[2][1] * data[3][3] - data[2][3] * data[3][1]) -
        data[1][1] * (data[2][0] * data[3][3] - data[2][3] * data[3][0]) +
        data[1][3] * (data[2][0] * data[3][1] - data[2][1] * data[3][0])
      ) -
      data[0][3] * (
        data[1][0] * (data[2][1] * data[3][2] - data[2][2] * data[3][1]) -
        data[1][1] * (data[2][0] * data[3][2] - data[2][2] * data[3][0]) +
        data[1][2] * (data[2][0] * data[3][1] - data[2][1] * data[3][0])
      );
  }
}