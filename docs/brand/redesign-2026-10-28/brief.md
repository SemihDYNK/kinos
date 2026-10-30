# Kinos — reprise vectorielle du logo

Brief : application desktop de cinéma et séries, personnelle et éditoriale.
Qualités : expressif, compact, sobre, net, lisible. Noir/blanc ; le caractère
vient des lettres, sans effet de verre intégré au dessin. Usages prioritaires :
monogramme 16–28 px, mot-symbole d’environ 132 px dans le rail déployé.
Équité conservée : le K sculpté préféré par l’utilisateur. À corriger : rythme
irrégulier de K–I–N–O–S et S artificiel. Pas de questions supplémentaires :
le contexte de cette conversation constitue le brief.

Repérage : bibliothèque du skill (30 identités media-entertainment), recherche
de la lettre K, étude de la construction de Wire, Adyen et Go. Ces marques
restent des références de technique et ne sont pas copiées. Clichés écartés :
triangle de lecture rapporté, clap, bobine, faisceau littéral, rouge obligatoire.
Carte de mots : Kinos → cinéma → cadre, regard, rythme, projection ; sobriété
→ une couleur, grands pleins ; expression → une seule lettre distinctive.

## Longue liste et sélection

1. Signature sculptée + lettres lisibles — retenue A, continuité la plus forte.
2. K découpé à 45° + capitales condensées — retenue B, plus cinématographique.
3. k à ascendant et minuscules denses — retenue C, mot-symbole plus souple.
4. O transformé en écran — écarté, idée trop littérale et détail petit.
5. K enfermé dans un cadre — écarté, encombre le rail et banalise le symbole.
6. Ligature KI — écartée, fragilise la lecture du nom.
7. Monogramme KS — écarté, le nom est déjà court et perd son rythme.
8. K en faisceau — écarté, l’utilisateur a préféré Signature.
9. Mot-symbole très étendu — écarté, ne tient pas dans le rail.
10. Signature manuscrite — écartée, peu cohérente avec l’interface.

A obtient le meilleur équilibre continuité/lisibilité/simplicité. B privilégie
l’impact mais évoque davantage un générique de film. C se lit bien mais change
la casse et s’éloigne de la direction initiale.

## Construction et tests

Symboles en viewBox 256 × 256. Lettres vectorisées à partir d’Inter Black
(A/C) et Barlow Condensed Bold (B), polices déjà présentes et distribuées sous
SIL OFL dans le projet. Le K reste dessiné spécifiquement ; aucune police
n’est requise pour afficher les SVG. Capitales à 204 unités avec débordement
optique des courbes ; espaces resserrés près des lettres rondes.

Deux passes distinctes conservées. V2 corrige le raccord du k de C, centre
les silhouettes et arrondit les coordonnées. Les angles légèrement différents
des multiples de 15° dans les lettres INOS proviennent du dessin de la police
et ne sont pas des erreurs de construction du symbole. Les planches montrent
les symboles à 64/32/16 px ; contrôles noir/blanc, inversés et miroir conservés.
Ce repérage n’est pas une vérification juridique d’antériorité.

Les concepts sont séparés des actifs actuellement utilisés dans l’app.
