import 'package:dio/dio.dart';

/// Fetches a raw (lat, lon, u_ms, v_ms) vector grid from sealanka-be (see
/// `/wind/grid`, `/ocean/currents/grid`) for client-side particle-flow
/// rendering — see [ParticleFlowLayer]. Returns an empty list on any
/// failure (no cached grid yet, network error) so the map still renders,
/// just without the animated overlay, rather than blocking the page.
Future<List<List<double>>> fetchVectorGrid(Dio dio, String path,
    {Map<String, dynamic>? queryParameters}) async {
  try {
    final response = await dio.get(path, queryParameters: queryParameters);
    final points = (response.data['points'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    return points;
  } on DioException {
    return const [];
  }
}
