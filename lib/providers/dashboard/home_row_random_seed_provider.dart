import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Graine de session pour la sélection des rangées aléatoires de l'accueil
/// (jamais vus, à redécouvrir, genre, réalisateur, studio, décennie).
///
/// `SortBy=Random` côté Jellyfin retire un tri différent à chaque appel —
/// aucun paramètre de graine n'existe dans l'API, l'ordre n'est stable ni
/// sur la session, ni sur l'utilisateur. Sans correction côté client, le
/// contenu d'une rangée changerait à chaque re-fetch (retour sur l'onglet,
/// provider `autoDispose` relibéré) au lieu de rester fixe jusqu'au
/// prochain démarrage.
///
/// Tirée une seule fois par lancement, gardée en mémoire pour toute la
/// durée du processus — un `Provider` (pas `autoDispose`) : sa valeur ne
/// doit jamais changer une fois l'app démarrée.
final homeRowRandomSeedProvider = Provider<int>((ref) => Random().nextInt(1 << 31));
