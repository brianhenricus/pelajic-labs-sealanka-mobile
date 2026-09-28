import 'package:flutter/material.dart';

/// Real Sri Lanka coastline (111-point simplified boundary, WGS84 lon/lat
/// degrees) -- fetched from a public country-boundary GeoJSON source and
/// verified by rendering in a browser preview before being ported here, so
/// this reads as an actual top-down map of the island (Jaffna peninsula,
/// real coastline detail) rather than a rough hand-drawn approximation.
const List<Offset> _kSriLankaLonLat = [
  Offset(80.19608, 9.84710),
  Offset(80.11780, 9.84033),
  Offset(80.01892, 9.83898),
  Offset(79.91318, 9.80786),
  Offset(79.84177, 9.77808),
  Offset(79.78409, 9.72395),
  Offset(79.74701, 9.67251),
  Offset(79.74701, 9.60346),
  Offset(79.77722, 9.56825),
  Offset(79.85687, 9.54929),
  Offset(79.89395, 9.57908),
  Offset(79.96124, 9.57367),
  Offset(80.03677, 9.57231),
  Offset(80.10818, 9.52898),
  Offset(80.12329, 9.47480),
  Offset(80.06012, 9.41926),
  Offset(80.02579, 9.38403),
  Offset(80.02853, 9.32577),
  Offset(80.08072, 9.28240),
  Offset(80.08896, 9.21734),
  Offset(80.04089, 9.12108),
  Offset(79.99832, 9.03836),
  Offset(79.94751, 9.00852),
  Offset(79.92416, 9.05192),
  Offset(79.88297, 9.09396),
  Offset(79.78271, 9.12515),
  Offset(79.70169, 9.11972),
  Offset(79.64127, 9.09260),
  Offset(79.58633, 9.10210),
  Offset(79.56985, 9.08311),
  Offset(79.61243, 9.05870),
  Offset(79.65912, 9.06006),
  Offset(79.72229, 9.05328),
  Offset(79.78683, 9.02480),
  Offset(79.85413, 8.95969),
  Offset(79.90768, 8.88100),
  Offset(79.89395, 8.80773),
  Offset(79.93927, 8.73172),
  Offset(79.90768, 8.66385),
  Offset(79.88434, 8.57152),
  Offset(79.85001, 8.53757),
  Offset(79.81842, 8.47645),
  Offset(79.81430, 8.51448),
  Offset(79.79095, 8.55929),
  Offset(79.76074, 8.50904),
  Offset(79.77173, 8.44249),
  Offset(79.77859, 8.40309),
  Offset(79.74838, 8.34059),
  Offset(79.70581, 8.25634),
  Offset(79.67560, 8.21829),
  Offset(79.68521, 8.04835),
  Offset(79.78546, 7.69058),
  Offset(79.76486, 7.63341),
  Offset(79.77310, 7.54629),
  Offset(79.82941, 7.27257),
  Offset(79.81155, 7.22897),
  Offset(79.79919, 7.19764),
  Offset(79.85825, 6.98777),
  Offset(79.79919, 6.96051),
  Offset(79.79919, 6.92506),
  Offset(79.82529, 6.90461),
  Offset(79.83902, 6.84053),
  Offset(79.94888, 6.53910),
  Offset(79.94339, 6.47224),
  Offset(79.98047, 6.41220),
  Offset(80.00931, 6.30574),
  Offset(80.03952, 6.20609),
  Offset(80.10544, 6.07501),
  Offset(80.20981, 6.00536),
  Offset(80.34576, 5.94800),
  Offset(80.49133, 5.91931),
  Offset(80.56824, 5.90565),
  Offset(80.60669, 5.92341),
  Offset(80.71655, 5.93570),
  Offset(80.79620, 5.98761),
  Offset(80.90744, 6.04770),
  Offset(81.22879, 6.14465),
  Offset(81.40732, 6.22247),
  Offset(81.55151, 6.32076),
  Offset(81.71219, 6.47634),
  Offset(81.84402, 6.73689),
  Offset(81.89484, 7.02185),
  Offset(81.88385, 7.14722),
  Offset(81.89621, 7.31616),
  Offset(81.84814, 7.44554),
  Offset(81.78360, 7.65928),
  Offset(81.71631, 7.75318),
  Offset(81.65314, 7.82257),
  Offset(81.60095, 7.85522),
  Offset(81.61057, 7.91099),
  Offset(81.55975, 7.96404),
  Offset(81.57623, 7.99940),
  Offset(81.53778, 8.01164),
  Offset(81.50208, 8.05515),
  Offset(81.46088, 8.14624),
  Offset(81.37436, 8.46015),
  Offset(81.34552, 8.53621),
  Offset(81.29883, 8.53621),
  Offset(81.23566, 8.50225),
  Offset(81.26175, 8.55250),
  Offset(81.24527, 8.59053),
  Offset(81.23840, 8.64484),
  Offset(81.18622, 8.73579),
  Offset(81.11343, 8.85658),
  Offset(81.06262, 8.87829),
  Offset(80.95139, 9.03429),
  Offset(80.84702, 9.28511),
  Offset(80.56000, 9.53169),
  Offset(80.34164, 9.70364),
  Offset(80.27161, 9.84304),
];

/// Equirectangular projection (lon = x, lat = -y, north-up) -- the same
/// simple projection already used elsewhere in the app for small-scale Sri
/// Lanka maps (see the PFZ PDF export's px()/py() helpers); negligible
/// distortion at this latitude and geographic extent.
Path _buildLocalSriLankaPath() {
  final path = Path();
  for (int i = 0; i < _kSriLankaLonLat.length; i++) {
    final p = _kSriLankaLonLat[i];
    final x = p.dx;
    final y = -p.dy; // north-up: higher latitude -> smaller y
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

final Path kSriLankaLocalPath = _buildLocalSriLankaPath();
final Rect kSriLankaLandBounds = kSriLankaLocalPath.getBounds();

/// Builds the Sri Lanka coastline scaled (preserving its real aspect
/// ratio, never stretched) to fit inside [target], centered within it.
Path buildSriLankaLandPath(Rect target) {
  final bounds = kSriLankaLandBounds;
  final scale = (target.width / bounds.width < target.height / bounds.height)
      ? target.width / bounds.width
      : target.height / bounds.height;
  final scaledW = bounds.width * scale;
  final scaledH = bounds.height * scale;
  final dx = target.left + (target.width - scaledW) / 2 - bounds.left * scale;
  final dy = target.top + (target.height - scaledH) / 2 - bounds.top * scale;

  final matrix = Matrix4.identity()
    ..translate(dx, dy)
    ..scale(scale, scale);
  return kSriLankaLocalPath.transform(matrix.storage);
}
