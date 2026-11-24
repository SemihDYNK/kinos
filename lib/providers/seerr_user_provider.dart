import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/seerr/seerr_models.dart';

part 'seerr_user_provider.g.dart';

@riverpod
class SeerrUser extends _$SeerrUser {
  @override
  SeerrUserModel? build() {
    _fetchUser();
    return null;
  }

  Future<void> _fetchUser() async {
    // Sans serveur Seerr configuré (ou injoignable), pas d'utilisateur :
    // l'échec reste silencieux au lieu de remonter en exception non gérée.
    try {
      final api = ref.read(seerrApiProvider);
      final response = await api.me();
      if (response.isSuccessful && response.body is SeerrUserModel) {
        state = response.body as SeerrUserModel;
      }
    } catch (_) {}
  }

  Future<SeerrUserModel?> refreshUser() async {
    final api = ref.read(seerrApiProvider);
    final response = await api.me();
    if (response.isSuccessful && response.body is SeerrUserModel) {
      state = response.body as SeerrUserModel;
      return response.body as SeerrUserModel;
    }
    return null;
  }

  void clearUser() {
    state = null;
  }
}
