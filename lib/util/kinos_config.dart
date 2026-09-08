class KinosConfig {
  static KinosConfig _instance = KinosConfig._();
  KinosConfig._();

  static String? get baseUrl => _instance._baseUrl;
  static set baseUrl(String? value) => _instance._baseUrl = value;
  String? _baseUrl;

  static String? get seerrBaseUrl => _instance._seerrBaseUrl;
  static set seerrBaseUrl(String? value) => _instance._seerrBaseUrl = value;
  String? _seerrBaseUrl;

  static void fromJson(Map<String, dynamic> json) => _instance = KinosConfig._fromJson(json);

  factory KinosConfig._fromJson(Map<String, dynamic> json) {
    final config = KinosConfig._();
    final newUrl = json['baseUrl'] as String?;
    final newSeerrUrl = json['seerrBaseUrl'] as String?;

    config._baseUrl = newUrl?.isEmpty == true ? null : newUrl;
    config._seerrBaseUrl = newSeerrUrl?.isEmpty == true ? null : newSeerrUrl;

    return config;
  }
}
