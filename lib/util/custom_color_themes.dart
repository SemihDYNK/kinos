import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ColorThemes {
  // Renommé depuis `fladder` — un préréglage de couleur de marque garde
  // le nom du projet actuel, pas celui d'avant le fork. Un utilisateur
  // ayant déjà ce thème enregistré (chaîne persistée "fladder") retombe
  // sur le thème par défaut au lieu de planter (ColorThemes? est
  // nullable, $enumDecodeNullable généré ne lève pas sur une valeur
  // inconnue) — impact mineur, une préférence de couleur, pas une perte
  // de données.
  kinos(
    name: 'Kinos',
    color: kDebugMode ? Colors.purpleAccent : Colors.orange,
  ),
  deepOrange(
    name: 'Deep Orange',
    color: Colors.deepOrange,
  ),
  amber(
    name: 'Amber',
    color: Colors.amber,
  ),
  green(
    name: 'Green',
    color: Colors.green,
  ),
  lightGreen(
    name: 'Light Green',
    color: Colors.lightGreen,
  ),
  lime(
    name: 'Lime',
    color: Colors.lime,
  ),
  cyan(
    name: 'Cyan',
    color: Colors.cyan,
  ),
  blue(
    name: 'Blue',
    color: Colors.blue,
  ),
  lightBlue(
    name: 'Light Blue',
    color: Colors.lightBlue,
  ),
  indigo(
    name: 'Indigo',
    color: Colors.indigo,
  ),
  deepBlue(
    name: 'Deep Blue',
    color: Color.fromARGB(255, 1, 34, 94),
  ),
  brown(
    name: 'Brown',
    color: Colors.brown,
  ),
  purple(
    name: 'Purple',
    color: Colors.purple,
  ),
  deepPurple(
    name: 'Deep Purple',
    color: Colors.deepPurple,
  ),
  blueGrey(
    name: 'Blue Grey',
    color: Colors.blueGrey,
  ),
  ;

  const ColorThemes({
    required this.name,
    required this.color,
  });

  final String name;
  final Color color;

  ColorScheme get schemeLight {
    return ColorScheme.fromSeed(seedColor: color, brightness: Brightness.light);
  }

  ColorScheme get schemeDark {
    return ColorScheme.fromSeed(seedColor: color, brightness: Brightness.dark);
  }
}
