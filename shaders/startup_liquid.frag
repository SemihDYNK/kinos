#version 460 core

// La lumière de l'intro de Kinos, au clap : des traînées qui filent des
// bords vers les lettres (une fois chacune, puis plus rien), des rayons
// qui traversent le K et KINOS, avec de la poussière dans la lumière, et
// derrière, des lames de verre irisées qui glissent. Les
// lettres elles-mêmes sont peintes par-dessus (cf. StartupMark) : ici, leur
// pochoir seulement.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// Secondes depuis le début de l'intro, et depuis le clap (négatif avant :
// les traînées partent un peu avant).
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
// Teinte de la dominante (0 à 1) et force des irisations du verre (0 : gris,
// sans dominante).
uniform float uHue;
uniform float uIris;
uniform sampler2D uMask;

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

float mask(vec2 uv) {
  return texture(uMask, uv).a;
}

vec3 hsv(float h, float s, float v) {
  vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0,
                 0.0, 1.0);
  return v * mix(vec3(1.0), k, s);
}

// Une couche de lames de verre qui glissent : une arête vive, un reflet
// qui court le long du verre, et à l'intérieur une irisation limitée aux
// teintes voisines de la dominante. Pour qu'elles ne soient pas toutes
// pareilles, chaque couche a son angle et sa vitesse, les lames ondulent
// un peu, et chacune a sa lumière et l'allure de son reflet.
vec3 glass(vec2 d, float depth, float speed, float density, float turn,
           float glow) {
  vec2 q = vec2(cos(turn) * d.x - sin(turn) * d.y,
                sin(turn) * d.x + cos(turn) * d.y);
  float bend = 0.18 * sin(q.y * 0.9 + uTime * 0.25 + depth * 2.3);
  float x = (q.x + bend) * density + uTime * speed + depth * 7.0;
  float id = floor(x);
  float f = fract(x);
  float width = 0.45 + 0.55 * hash(id + depth);
  float inside = step(f, width);
  float g = f / width;
  // Les arêtes ne sont jamais plus fines qu'un pixel et demi : plus
  // fines, elles crénelaient.
  float pixel = density / (uSize.y * width);
  float edge = exp(-pow(g / max(0.025, 1.5 * pixel), 2.0)) * 1.4 +
               exp(-pow((1.0 - g) / max(0.015, 1.5 * pixel), 2.0)) * 0.9;
  float pace = 0.15 + 0.7 * hash(id + 13.0 + depth);
  float sheen = pow(noise(vec2(q.y * 1.5 - uTime * pace, id)), 3.0);
  float spread = smoothstep(0.15, 0.5, g) * smoothstep(0.95, 0.55, g) *
                 (0.4 + 0.6 * noise(vec2(q.y * 2.0 + uTime * 0.2, id * 3.0)));
  float tint = fract(g * 0.6 + q.y * 0.15 + hash(id));
  vec3 iris = hsv(fract(uHue + (tint - 0.5) * 0.32), 0.75 * uIris, 1.0);
  float own = 0.35 + 0.65 * hash(id + 2.0 + depth);
  vec3 c = vec3(0.025) + iris * spread * 0.55 * sheen * 2.0 +
           vec3(0.9) * edge * (0.25 + 0.75 * sheen) + uInk * 0.05 * g;
  // La lumière des lettres renvoyée par le verre proche : ses arêtes et
  // son irisation s'allument de leurs couleurs.
  vec3 letterLight = mix(uHot, vec3(1.0), 0.2);
  c += letterLight * glow * (edge * 0.9 + spread * 0.5 + 0.06);
  return c * inside * mix(own, 1.0, clamp(glow, 0.0, 1.0));
}

// Traînées : autant de couloirs autour du centre, un sur trois ou presque
// éteint ; chacune arrive à un instant à elle, à sa vitesse, et ne passe
// qu'une fois.
const float kLanes = 150.0;
const float kLength = 0.28;

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec2 uv = px / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 centreUv = uCentre / uSize;
  vec2 d = (uv - centreUv) * vec2(aspect, 1.0);
  float r = length(d);
  float angle = atan(d.y, d.x);
  vec3 color = uBlack;

  // La lumière des lettres, très étalée : ce que le verre autour d'elles
  // en reçoit.
  float spill = 0.0;
  if (uWave > 0.0) {
    for (int i = 0; i < 12; i++) {
      float a = float(i) * 0.5236;
      spill += mask(uv + vec2(cos(a) / aspect, sin(a)) * 0.07);
      spill += mask(uv + vec2(cos(a + 0.26) / aspect, sin(a + 0.26)) * 0.14) *
               0.6;
    }
    spill = spill / 12.0 * smoothstep(0.0, 0.5, uWave);
  }

  // Le verre, éclairé par la lumière arrivée : trois couches d'angles,
  // de finesses et de vitesses différentes, plus claires près des lettres.
  if (uWave > 0.0) {
    float lit = smoothstep(0.1, 0.9, uWave);
    vec3 panes = glass(d, 0.0, 0.03, 2.0, -0.62, spill) +
                 glass(d * 1.3 + vec2(0.3, 0.0), 1.0, -0.055, 3.1, -0.48,
                       spill) *
                     0.55 +
                 glass(d * 0.8, 2.0, 0.012, 1.3, -0.8, spill) * 0.4;
    color += panes * lit * (1.1 - smoothstep(0.0, 1.0, r * 0.9)) * 1.1;
  }

  // L'hyperespace : avant le clap, des traînées filent des bords vers le
  // K, longues ou courtes, rapides ou lentes, en plusieurs vagues, et le
  // chargent de couleur ; la dernière arrive juste avant le clap.
  if (uWave > -1.8 && uWave < 0.3) {
    float lane = (angle + 3.14159) / 6.28318 * kLanes;
    float id = floor(lane);
    float across = fract(lane);
    float reach = clamp(r / (0.95 * aspect * 0.5), 0.0, 1.2);
    // Un couloir n'est jamais plus fin qu'un pixel et demi (crénelage).
    float lanePixel = kLanes / (6.28318 * max(r, 1e-3) * uSize.y);
    float thin = exp(-pow((across - 0.5) / max(0.07, 1.5 * lanePixel), 2.0));
    for (int k = 0; k < 3; k++) {
      float seed = id * 3.0 + float(k);
      float arrive = -1.45 + 1.35 * hash(seed + 11.0);
      float span = 0.35 + 0.45 * hash(seed);
      float len = 0.25 + 0.5 * hash(seed + 21.0);
      float head = 1.15 * (arrive - uWave) / span;
      float streak = smoothstep(head + len, head, reach) *
                     smoothstep(head - 0.01, head, reach);
      float live = step(-0.05, head) * step(head, 1.2);
      float keep = step(0.35, hash(seed + 3.0));
      vec3 tone = mix(mix(uInk, uHot, hash(seed + 5.0)), vec3(1.0),
                      0.35 * hash(seed + 9.0));
      color += tone * streak * thin * keep * live *
               (0.6 + 0.8 * hash(seed + 17.0)) *
               smoothstep(0.05, 0.2, r) * 2.2;
    }
  }

  if (uWave > 0.0) {
    // Les rayons : la lumière derrière les lettres, étirée depuis leur
    // centre vers l'extérieur, juste après le clap.
    if (uRays > 0.0) {
      vec2 toward = centreUv - uv;
      float light = 0.0;
      float weight = 1.0;
      for (int i = 0; i < 40; i++) {
        light += mask(uv + toward * (float(i) / 40.0) * 0.55) * weight;
        weight *= 0.94;
      }
      light = light / 30.0 * smoothstep(0.05, 0.5, uWave) * uRays;
      vec3 beam = mix(uInk, uHot, clamp(light * 0.7, 0.0, 1.0));
      float dust =
          smoothstep(0.985, 1.0,
                     noise(uv * vec2(aspect, 1.0) * 140.0 +
                           vec2(uTime * 0.5, -uTime * 0.8))) *
          1.4;
      color += beam * light * (1.0 + dust);
    }
  }

  // La brillance des lettres chargées : un flou doux sur deux rayons (pas
  // un anneau de copies), plus vif au clap.
  float charge = smoothstep(-1.3, -0.15, uWave);
  if (charge > 0.0) {
    float near = 0.0;
    float far = 0.0;
    for (int i = 0; i < 12; i++) {
      float a = float(i) * 0.5236;
      vec2 dir = vec2(cos(a) / aspect, sin(a));
      near += mask(uv + dir * 0.006) + mask(uv + dir * 0.012);
      far += mask(uv + dir * 0.025);
    }
    float bloom = near / 24.0 * 0.5 + far / 12.0 * 0.5;
    float flash = uWave > 0.0 ? exp(-uWave * 4.0) : 0.0;
    color += mix(uHot, vec3(1.0), 0.25) * bloom * charge * (0.22 + 0.5 * flash);
  }

  color = mix(uBlack, color, uIntensity);
  color += (hash2(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
