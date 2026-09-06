/// Formatage des informations techniques du fichier — panneau
/// "Informations" de l'écran de détail.
String? formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unitIndex]}';
}

String? formatBitrate(int? bitsPerSecond) {
  if (bitsPerSecond == null || bitsPerSecond <= 0) return null;
  final mbps = bitsPerSecond / 1000000;
  return '${mbps.toStringAsFixed(mbps >= 10 ? 0 : 1)} Mb/s';
}
