import '../../../shared/models/child_model.dart';
import '../../../core/database/database_helper.dart';

abstract class ChildRepository {
  Future<int> addChild(ChildModel child);
  Future<List<ChildModel>> getChildren();
  Future<int> updateChild(ChildModel child);
  Future<int> deleteChild(int id);
}

class ChildRepositoryImpl implements ChildRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> addChild(ChildModel child) async {
    return await _dbHelper.insertChild(child);
  }

  @override
  Future<List<ChildModel>> getChildren() async {
    return await _dbHelper.getAllChildren();
  }

  @override
  Future<int> updateChild(ChildModel child) async {
    return await _dbHelper.updateChild(child);
  }

  @override
  Future<int> deleteChild(int id) async {
    return await _dbHelper.deleteChild(id);
  }
}
