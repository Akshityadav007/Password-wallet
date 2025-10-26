// Schema for encrypted export JSON

class ExportFile {
  final String version;
  final String saltBase64;
  final List<Map<String, dynamic>> entries;

  ExportFile({
    required this.version,
    required this.saltBase64,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'salt': saltBase64,
        'entries': entries,
      };
}
