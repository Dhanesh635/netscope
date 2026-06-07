class ExportService {
  ExportService({dynamic measurementRepository});

  Future<String?> exportLatestSession({bool share = false}) async {
    return null;
  }

  Future<String> exportSession(int sessionId, {bool share = false}) async {
    throw UnsupportedError('CSV export is not available on web.');
  }
}
