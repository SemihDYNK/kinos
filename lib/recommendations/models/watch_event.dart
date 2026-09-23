import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';

/// Un visionnage — une œuvre, un signal, les traits qu'elle porte. Type
/// d'entrée du moteur, indépendant de Jellyfin : un adaptateur
/// (`lib/recommendations/adapters/`) construit ces événements à partir
/// de l'historique réel, mais le moteur lui-même n'importe jamais rien
/// du client Jellyfin — c'est ce qui le rend testable avec de simples
/// fixtures.
class WatchEvent {
  final String itemId;
  final List<TraitKey> traits;
  final WatchSignal signal;

  /// Date du signal (dernier visionnage/abandon) — sert à
  /// l'amortissement temporel. `null` : signal non daté, aucun
  /// amortissement appliqué (poids plein) plutôt qu'un événement
  /// silencieusement exclu.
  final DateTime? occurredAt;

  const WatchEvent({
    required this.itemId,
    required this.traits,
    required this.signal,
    this.occurredAt,
  });
}
