abstract class ProjectRepository {
  Future<void> saveProject(int canvasId, String filePath);
  Future<int> loadProject(String filePath);
  Future<String> getAutoSavePath();
}
