import 'dart:ffi';

/// Temps écoulé depuis le démarrage de Windows (`GetTickCount64`).
Duration? windowsUptime() {
  final tickCount = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Uint64 Function(), int Function()>('GetTickCount64');
  return Duration(milliseconds: tickCount());
}
