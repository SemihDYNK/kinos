import 'dart:ffi';
import 'dart:io';

/// Termine Kinos tout de suite, sans démonter le moteur Flutter.
///
/// Les fils internes de libmpv (rendu vidéo, événements) peuvent encore
/// appeler leurs rappels Dart pendant que le moteur s'arrête : ces rappels
/// sont déjà libérés, et Kinos plantait à la fermeture (SIGSEGV, SIGABRT).
/// Une fois tout enregistré et les lecteurs libérés, on quitte donc le
/// processus d'un coup (`_exit`, sans destructeurs ni rappels). Windows
/// garde la sortie ordinaire.
Never hardExit([int code = 0]) {
  if (Platform.isLinux || Platform.isMacOS) {
    try {
      DynamicLibrary.process()
          .lookupFunction<Void Function(Int32), void Function(int)>(
              '_exit')(code);
    } catch (_) {}
  }
  exit(code);
}
