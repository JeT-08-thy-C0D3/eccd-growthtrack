import '../domain/triangulation_model.dart';

abstract class TriangulationRepository {
  Future<int> saveTriangulation(TriangulationModel triangulation);
  Future<List<TriangulationModel>> getHistory(String childId);
  Future<Map<String, dynamic>> fetchTriangulationInputs(String childId);
}
