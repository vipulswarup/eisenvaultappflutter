abstract class DeleteProvider {
  Future<String> deleteFiles(List<String> fileIds);
  Future<String> deleteFolders(List<String> folderIds);
  Future<String> deleteDepartments(List<String> departmentIds);
  Future<String> deleteFileVersion(String fileId, String versionId);
  Future<String> deleteTrashItems(List<String> trashIds);
}
