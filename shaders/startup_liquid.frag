#version 460 core

// L'intro de Kinos : un lent travelling dans une galerie de lames de verre.
// La lumière s'allume dans leurs arêtes et court vers le fond, où le K
// s'éclaire, rétroéclairé ; ses rayons traversent la brume, la poussière y
// scintille, et un reflet d'objectif marque le clap. Le K et KINOS sont
// peints par-dessus (cf. StartupMark) : ici, leur pochoir flouté seulement.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// Secondes de l'horloge, et depuis le clap (négatif avant).
uniform float uTime;
uniform float uWave;
// Intensité globale (0 : le noir seul).
uniform float uIntensity;
// Centre des lettres (pixels) et force des rayons (0 à l'ouverture).
uniform vec2 uCentre;
uniform float uRays;
uniform vec3 uBlack;
uniform vec3 uInk;
uniform vec3 uHot;
uniform float uGrain;
// Teinte de la dominante (0 à 1) et force des irisations (0 : gris, sans
// dominante).
uniform float uHue;
uniform float uIris;
// La caméra (profondeur parcourue, décalage latéral), le front de la
// lumière dans les arêtes, l'éclairage du K, le reflet d'objectif et la
// sortie du noir (cf. StartupAurora.galleryAt).
uniform float uDepth;
uniform float uSide;
uniform float uIgnite;
uniform float uLit;
uniform float uFlare;
uniform float uFade;
// Le pochoir des lettres, flou léger puis flou large.
uniform sampler2D uGlow;
uniform sampler2D uSpill;

out vec4 fragColor;

float hash(float p) {
  return fract(sin(p * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
             mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
             f.y);
}

vec3 hsv(float h, float s, float v) {
  vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0,
                 0.0, 1.0);
  return v * mix(vec3(1.0), k, s);
}

float glowAt(vec2 uv) {
  return texture(uGlow, uv).a;
}

// La galerie : six plans de lames, du plus proche au plus lointain, avec
// un couloir libre au centre où la caméra avance. La mise au point est à
// cette distance ; au-delà comme en deçà, les arêtes s'élargissent.
const float kFirst = 1.6;
const float kGap = 1.45;
const float kFocus = 3.0;
const float kCorridor = 0.55;

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec2 uv = px / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 centreUv = uCentre / uSize;
  vec2 d = (uv - centreUv) * vec2(aspect, 1.0);
  float r = length(d);
  vec3 color = uBlack;

  // La brume : une clarté autour du K, plus forte quand il s'éclaire.
  float haze = exp(-r * 2.2);
  color += mix(uInk, uHot, 0.4) * haze * 0.10 *
           (0.3 + 0.7 * uLit * (uWave > 0.0 ? 1.0 : 0.5));

  // Avant le clap, le K s'éclaire en retenue ; au clap, toute sa
  // brillance d'un coup.
  float burst = uWave > 0.0 ? smoothstep(0.0, 0.18, uWave) : 0.0;
  float shine = uLit * mix(0.32, 1.0, burst);

  // La lumière des lettres, très étalée : ce que le verre proche en reçoit.
  float spill = texture(uSpill, uv).a * 3.5 * shine;

  // Les lames, du fond vers l'avant. Chacune a sa largeur, sa lumière, son
  // allure de reflet ; certaines penchent, et toutes oscillent un peu.
  for (int layer = 5; layer >= 0; layer--) {
    float plane = kFirst + float(layer) * kGap;
    float depth = plane - uDepth;
    if (depth < 0.15) continue;
    vec2 w = d * depth + vec2(uSide, 0.0);
    float density = 1.25;
    float x = w.x * density + float(layer) * 3.17;
    // La lumière s'allume plan après plan, vers le fond.
    float on = smoothstep(plane - 0.2, plane + 0.6, uIgnite);
    float fog = exp(-depth * 0.17);
    float defocus = abs(depth - kFocus) * 0.012;
    float soft = mix(1.0, 1.0 / (1.0 + defocus * 30.0), 0.5);
    // Une lame penchée déborde de sa case : chaque point regarde aussi les
    // lames voisines, pour qu'aucune ne soit coupée.
    for (int k = -2; k <= 2; k++) {
      float cell = floor(x) + float(k);
      float id = cell + float(layer) * 31.0;
      // Le centre de la lame, qui oscille, et sa pente : la plupart presque
      // droites, une sur trois franchement penchée.
      float centre = (cell + 0.5 - float(layer) * 3.17) / density +
                     0.05 * sin(uTime * (0.25 + 0.3 * hash(id + 4.0)) + id);
      float lean = hash(id + 5.0) < 0.33 ? (hash(id + 6.0) - 0.5) * 0.9
                                         : (hash(id + 6.0) - 0.5) * 0.12;
      lean += 0.03 * sin(uTime * 0.3 + id * 1.7);
      float width = (0.5 + 0.5 * hash(id + 1.0)) / density;
      float local = (w.x - centre) + w.y * lean;
      if (abs(local) > width * 0.5) continue;
      float g = local / width + 0.5;
      // Le couloir de la caméra écarte les lames entières, jamais en biais.
      float side = smoothstep(kCorridor, kCorridor + 0.2, abs(centre));
      // Les arêtes ne sont jamais plus fines qu'un pixel et demi.
      float pixel = depth / (uSize.y * width);
      float edge =
          exp(-pow(g / max(0.012 + defocus, 1.5 * pixel), 2.0)) * 0.9 +
          exp(-pow((1.0 - g) / max(0.009 + defocus, 1.5 * pixel), 2.0)) * 0.5;
      float sheen = pow(
          noise(vec2(w.y * 1.4 - uTime * (0.15 + 0.6 * hash(id + 13.0)), id)),
          2.0);
      float tint = fract(g * 0.6 + w.y * 0.12 + hash(id));
      vec3 iris = hsv(fract(uHue + (tint - 0.5) * 0.32), 0.75 * uIris, 1.0);
      float spread =
          smoothstep(0.15, 0.5, g) * smoothstep(0.95, 0.55, g) *
          (0.4 + 0.6 * noise(vec2(w.y * 2.0 + uTime * 0.2, id * 3.0)));
      float own = 0.45 + 0.55 * hash(id + 2.0);
      color += mix(uHot, vec3(1.0), 0.2) * spill *
               (edge * 0.9 + spread * 0.6) * side * fog;
      color += (vec3(1.0) * edge * (0.3 + 0.7 * sheen) * on +
                iris * spread * sheen * 0.9 * on + vec3(0.014)) *
               side * fog * own * soft;
    }
  }

  // Le K éclairé : ses rayons dans la brume, avec la poussière qui y
  // scintille, et sa brillance.
  if (uLit > 0.0) {
    if (uRays > 0.0) {
      vec2 toward = centreUv - uv;
      float light = 0.0;
      float weight = 1.0;
      for (int i = 0; i < 36; i++) {
        light += glowAt(uv + toward * (float(i) / 36.0) * 0.85) * weight;
        weight *= 0.955;
      }
      light = light / 14.0 * shine * uRays;
      vec2 grain = uv * vec2(aspect, 1.0);
      float dust =
          smoothstep(0.986, 1.0,
                     noise(grain * 130.0 + vec2(uTime * 0.4, -uTime * 0.7))) +
          smoothstep(0.975, 1.0,
                     noise(grain * 55.0 - vec2(uTime * 0.2, uTime * 0.35))) *
              0.6;
      color += mix(uInk, uHot, clamp(light, 0.0, 1.0)) * light *
               (1.0 + dust * 1.6);
    }
    float flash = uWave > 0.0 ? exp(-uWave * 3.0) : 0.0;
    color += mix(uHot, vec3(1.0), 0.25) * glowAt(uv) * (0.45 * shine + flash);
  }

  // Le reflet d'objectif du clap : un trait horizontal et un halo, puis
  // quelques reflets discrets de la dominante.
  if (uFlare > 0.001) {
    float streak = exp(-abs(d.y) / 0.004) * exp(-abs(d.x) * 1.3);
    float bloom = exp(-dot(d, d) / 0.01);
    color += (mix(uHot, vec3(1.0), 0.5) * streak * 1.4 +
              mix(uInk, vec3(1.0), 0.3) * bloom * 0.6) *
             uFlare;
    for (int i = 1; i < 4; i++) {
      vec2 ghost = vec2(-0.12 * float(i) * aspect, 0.05 * float(i));
      float gd = length(d - ghost);
      color += hsv(fract(uHue + 0.1 * float(i)), 0.6 * uIris, 1.0) *
               smoothstep(0.05, 0.035, gd) * 0.08 * uFlare;
    }
  }

  color = mix(uBlack, color, uIntensity * uFade);
  color += (hash2(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
