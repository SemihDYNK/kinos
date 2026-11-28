#version 460 core

// L'intro de Kinos : la caméra vole à travers une galerie de plaques de
// verre posées dans l'espace (de vraies plaques, avec leur position et leur
// orientation). Elles s'éclairent quand elle les frôle. Au bout, trois
// lames vues de profil pivotent vers elle et forment le K ; la signature
// (cf. StartupMark) prend alors le relais, rétroéclairée, avec ses rayons
// dans la brume, et un reflet d'objectif marque le clap.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// Secondes de l'horloge, et depuis le clap (négatif avant).
uniform float uTime;
uniform float uWave;
// Intensité globale (0 : le noir seul).
uniform float uIntensity;
// Centre de la signature (pixels) et force des rayons (0 à l'ouverture).
uniform vec2 uCentre;
uniform float uRays;
uniform vec3 uBlack;
uniform vec3 uInk;
uniform vec3 uHot;
uniform float uGrain;
// Teinte de la dominante (0 à 1) et force des irisations (0 : gris).
uniform float uHue;
uniform float uIris;
// La caméra : position, direction, droite, haut (cf. StartupAurora
// .flightAt).
uniform vec3 uCam;
uniform vec3 uForward;
uniform vec3 uRight;
uniform vec3 uUp;
// Angle des trois lames du K (π/2 : de profil, 0 : face à la caméra).
uniform vec3 uTurns;
// Éclairage du K, reflet d'objectif, sortie du noir.
uniform float uLit;
uniform float uFlare;
uniform float uFade;
// Taille d'une unité du signe dans l'espace, et focale.
uniform float uMarkScale;
uniform float uFocal;
// Le pochoir de la signature, flou léger puis flou large, et les trois
// pièces du K, chacune dans sa case.
uniform sampler2D uGlow;
uniform sampler2D uSpill;
uniform sampler2D uAtlas;

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

// Les plaques : candidates tirées au hasard dans le volume, écartées du
// couloir de la caméra et de l'avant du K. Hautes, pour remplir l'écran
// de haut en bas.
const int kCandidates = 54;
const float kFocus = 3.3;

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec2 uv = px / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 centreUv = uCentre / uSize;
  vec2 d = (uv - centreUv) * vec2(aspect, 1.0);
  float r = length(d);
  vec3 ray = normalize(uForward * uFocal + uRight * d.x - uUp * d.y);
  float pixel = 1.0 / (uFocal * uSize.y);
  vec3 color = uBlack;

  // Avant le clap, le K s'éclaire en retenue ; au clap, toute sa brillance.
  float burst = uWave > 0.0 ? smoothstep(0.0, 0.18, uWave) : 0.0;
  float shine = uLit * mix(0.32, 1.0, burst);
  // La signature prend le relais des trois lames quand elles ont pivoté.
  float handoff = smoothstep(-0.45, -0.3, uWave);

  // Les trois lames du K, en verre, qui pivotent vers la caméra.
  float nearestK = 1e9;
  vec3 markColor = vec3(0.0);
  if (handoff < 1.0) {
    for (int i = 0; i < 3; i++) {
      // Centre et demi-taille de chaque pièce, en unités du signe (centré).
      vec2 centre = i == 0 ? vec2(-78.0, 0.0)
                           : (i == 1 ? vec2(31.5, 59.0) : vec2(31.5, -59.0));
      vec2 extent = i == 0 ? vec2(30.0, 102.0) : vec2(79.5, 54.0);
      float turn = i == 0 ? uTurns.x : (i == 1 ? uTurns.y : uTurns.z);
      vec3 across = vec3(cos(turn), 0.0, sin(turn));
      vec3 normal = vec3(-sin(turn), 0.0, cos(turn));
      vec3 origin = vec3(centre * uMarkScale, 0.0);
      float facing = dot(ray, normal);
      if (abs(facing) < 1e-4) continue;
      float t = dot(origin - uCam, normal) / facing;
      if (t <= 0.0 || t > nearestK) continue;
      vec3 hit = uCam + ray * t - origin;
      vec2 local = vec2(dot(hit, across), hit.y) / (extent * uMarkScale);
      if (abs(local.x) > 1.0 || abs(local.y) > 1.0) continue;
      float shape = texture(uAtlas,
                            vec2((float(i) + 0.5 + local.x * 0.5) / 3.0,
                                 0.5 - local.y * 0.5)).a;
      if (shape < 0.02) continue;
      nearestK = t;
      float level = (centre.y + local.y * extent.y) / 128.0;
      vec3 grad = mix(mix(uInk, uHot, clamp(0.5 + level * 0.5, 0.0, 1.0)) * 1.15,
                      vec3(1.0), 0.15);
      float face = abs(facing);
      // De profil, un trait de verre clair ; de face, la lame colorée.
      markColor = (mix(vec3(0.05) + grad * 0.25, grad, shine) * (0.35 + 0.65 * face) +
                   vec3(1.0) * (1.0 - face) * 0.9) *
                  shape * (1.0 - handoff);
    }
  }

  // La galerie : chaque plaque, éclairée quand la caméra la frôle, plus
  // sombre derrière le K. Le verre est transparent : elles s'additionnent.
  for (int i = 0; i < kCandidates; i++) {
    float k = float(i);
    vec3 q = vec3((hash(k + 1.0) - 0.5) * 16.0, (hash(k + 3.0) - 0.5) * 0.6,
                  -16.0 + hash(k + 2.0) * 26.0);
    // Le couloir du vol, puis l'espace entre la caméra posée et le K ;
    // derrière le K, la galerie remplit tout le fond.
    if (q.z < -3.6 && abs(q.x) < 1.4) continue;
    if (q.z >= -3.6 && q.z < 0.8 && abs(q.x) < 2.1) continue;
    float yaw = (hash(k + 4.0) - 0.5) * 2.2;
    float lean = hash(k + 5.0) < 0.3 ? (hash(k + 6.0) - 0.5) * 0.7
                                      : (hash(k + 6.0) - 0.5) * 0.1;
    float halfW = 0.45 + 0.75 * hash(k + 7.0);
    float halfH = 6.0 + 3.0 * hash(k + 8.0);
    vec3 across = vec3(cos(yaw), 0.0, sin(yaw));
    vec3 upward = normalize(vec3(-sin(lean) * cos(yaw), cos(lean),
                                 -sin(lean) * sin(yaw)));
    vec3 normal = normalize(cross(across, upward));
    float facing = dot(ray, normal);
    if (abs(facing) < 1e-4) continue;
    float t = dot(q - uCam, normal) / facing;
    if (t <= 0.05) continue;
    vec3 hit = uCam + ray * t - q;
    float a = dot(hit, across) / halfW;
    float b = dot(hit, upward) / halfH;
    if (abs(a) > 1.0 || abs(b) > 1.0) continue;
    // Les bords ne sont jamais plus fins qu'un pixel et demi.
    float defocus = abs(t - kFocus) * 0.006;
    float width = max(0.006 + defocus, 1.6 * pixel * t);
    float edge = exp(-pow((1.0 - abs(a)) * halfW / width, 2.0)) +
                 0.5 * exp(-pow((1.0 - abs(b)) * halfH / width, 2.0));
    float fog = exp(-t * 0.09);
    vec3 offset = q - uCam;
    float pass = exp(-dot(offset, offset) * 0.12);
    float sheen = pow(noise(vec2(b * 2.0 - uTime * 0.4, k * 3.1)), 2.0);
    vec3 iris = hsv(fract(uHue + (a * 0.5 + 0.5) * 0.25 - 0.12 + b * 0.05),
                    0.7 * uIris, 1.0);
    float spread = smoothstep(0.95, 0.2, abs(a)) *
                   (0.4 + 0.6 * noise(vec2(b * 3.0 + uTime * 0.2, k)));
    // Celles qui entourent le K prennent aussi sa lumière.
    float around = exp(-dot(q.xz, q.xz) * 0.04) * shine;
    vec3 pane = (vec3(1.0) * edge * (0.45 + 0.55 * sheen) *
                     (0.6 + 1.8 * pass + 1.2 * around) +
                 iris * spread * sheen * 0.85 * (0.6 + 1.2 * pass + around) +
                 mix(uHot, vec3(1.0), 0.2) * edge * around * 0.6 +
                 vec3(0.012)) *
                fog;
    if (t > nearestK) pane *= 0.35;
    color += pane;
  }
  color += markColor;

  // La brume autour du K, la lumière qu'il renvoie, ses rayons et sa
  // brillance, une fois la signature en place.
  color += mix(uInk, uHot, 0.4) * exp(-r * 2.2) * 0.08 * (0.3 + 0.7 * shine);
  if (handoff > 0.0 && uLit > 0.0) {
    if (uRays > 0.0) {
      vec2 toward = centreUv - uv;
      float light = 0.0;
      float weight = 1.0;
      for (int i = 0; i < 36; i++) {
        light += glowAt(uv + toward * (float(i) / 36.0) * 0.85) * weight;
        weight *= 0.955;
      }
      light = light / 14.0 * shine * uRays * handoff;
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
    float spill = texture(uSpill, uv).a;
    color += mix(uHot, vec3(1.0), 0.25) *
             (glowAt(uv) * (0.45 * shine + flash) + spill * 0.15 * shine) *
             handoff;
  }

  // Le reflet d'objectif du clap.
  if (uFlare > 0.001) {
    float streak = exp(-abs(d.y) / 0.004) * exp(-abs(d.x) * 1.3);
    float bloom = exp(-dot(d, d) / 0.01);
    color += (mix(uHot, vec3(1.0), 0.5) * streak * 1.4 +
              mix(uInk, vec3(1.0), 0.3) * bloom * 0.6) *
             uFlare;
  }

  color = mix(uBlack, color, uIntensity * uFade);
  color += (hash2(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
