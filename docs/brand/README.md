# Kinos — Signature A

Direction validée le 28 octobre 2026 après deux passes de concepts vectoriels.
Les maîtres approuvés sont `redesign-2026-10-28/a-symbol-v2.svg` et
`redesign-2026-10-28/a-wordmark-v2.svg`. Le K est dessiné ; INOS provient
d’Inter Black converti en tracés (licence SIL OFL). Le S reste une lettre lisible.

## Production

- `icons/kinos_signature_final.svg` : monogramme du rail.
- `icons/kinos_wordmark_final.svg` : signature horizontale, ratio 949/256.
- `icons/kinos_app_icon.svg` : icône Linux graphite.
- Les anciens noms SVG restent des alias compatibles.

Les exports de bureau production/développement et Flatpak utilisent la même
source. Le rechargement à chaud charge les nouveaux noms sans réutiliser le
cache SVG précédent. Le paquet installé et son cache système suivent leur
cycle d’installation habituel.

## Kit et usage

Le dossier `signature-final/` contient SVG noirs/blancs, composition verticale,
icône, PNG, favicon, fichiers web facultatifs et présentation HTML autonome.
Le rail replié emploie le K seul ; le rail déployé et les écrans d’identité
emploient KINOS. Minimum : symbole 16 px, signature 100 px de large.
Réserver autour du logo au moins une demi-largeur de sa hampe verticale.
Palette : graphite #141414, blanc #FAFAFA ; noir sur fond clair.
Ne pas étirer, réespacer les lettres, ajouter de contours ou d’effets.
Le verre dépoli appartient à l’interface, jamais aux tracés du logo.

L’audit SVG confirme des tracés sans texte externe ni raster. Les diagonales du
N sont celles de la police : l’avertissement angulaire de l’audit est conservé
volontairement. La silhouette approuvée reste identique en version inversée.
