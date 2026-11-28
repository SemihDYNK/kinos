#version 460 core

// La lumière de l'intro de Kinos : des traînées qui convergent vers le
// centre et s'y condensent en K, avant le clap ; puis des rayons
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

float glowAt(vec2 uv) {
  return texture(uGlow, uv).a;
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
  float edge = exp(-pow(g / max(0.025, 1.5 * pixel), 2.0)) * 0.8 +
               exp(-pow((1.0 - g) / max(0.015, 1.5 * pixel), 2.0)) * 0.45;
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
// éteint, trois traînées par couloir, chacune à son instant et son allure.
const float kLanes = 170.0;

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
  float spill = uWave > 0.0 ? texture(uSpill, uv).a * 2.2 *
                                  smoothstep(0.0, 0.5, uWave)
                            : 0.0;

  // Le verre, éclairé par la lumière arrivée : deux couches de larges
  // lames, d'angles et de vitesses différents, plus claires près des
  // lettres.
  if (uWave > 0.0) {
    float lit = smoothstep(0.1, 0.9, uWave);
    vec3 panes = glass(d, 0.0, 0.03, 1.6, -0.62, spill) +
                 glass(d * 0.8 + vec2(0.3, 0.0), 1.0, -0.02, 1.0, -0.74,
                       spill) *
                     0.5;
    color += panes * lit * (1.1 - smoothstep(0.0, 1.0, r * 0.9)) * 1.1;
  }

  // La condensation : des traînées filent des bords vers le centre, en
  // accélérant, et s'éclairent en atteignant le K ; de plus en plus
  // nombreuses, la dernière arrive quand la branche s'ouvre pour le clap.
  if (uWave > -2.7 && uWave < 0.0) {
    float lane = (angle + 3.14159) / 6.28318 * kLanes;
    float id = floor(lane);
    float across = fract(lane);
    float reach = clamp(r / (0.95 * aspect * 0.5), 0.0, 1.2);
    // Un couloir n'est jamais plus fin qu'un pixel et demi (crénelage).
    float lanePixel = kLanes / (6.28318 * max(r, 1e-3) * uSize.y);
    float thin = exp(-pow((across - 0.5) / max(0.08, 1.5 * lanePixel), 2.0));
    for (int k = 0; k < 2; k++) {
      float seed = id * 2.0 + float(k);
      float arrive = mix(-1.9, -0.15, pow(hash(seed + 11.0), 0.6));
      float span = 0.5 + 0.5 * hash(seed);
      float len = 0.15 + 0.45 * hash(seed + 21.0);
      float travel = clamp((uWave - (arrive - span)) / span, 0.0, 1.0);
      float head = 1.15 * (1.0 - travel * travel);
      float streak = smoothstep(head + len, head, reach) *
                     smoothstep(head - 0.01, head, reach);
      float live = step(0.001, travel) * step(travel, 0.999);
      float keep = step(0.55, hash(seed + 3.0));
      vec3 tone = mix(mix(uInk, uHot, hash(seed + 5.0)), vec3(1.0),
                      0.4 * hash(seed + 9.0));
      color += tone * streak * thin * keep * live *
               mix(0.5, 1.8, 1.0 - clamp(reach, 0.0, 1.0)) *
               smoothstep(0.04, 0.16, r) * 1.6;
    }
  }

  // La lumière accumulée dessine le K : un K flou qui s'intensifie, où
  // les pièces viennent se solidifier.
  float condense = smoothstep(-2.2, -0.9, uWave) *
                   (1.0 - smoothstep(-0.35, 0.1, uWave));
  // La lumière forme le K : elle s'y dépose par plaques qui s'étendent et
  // se rejoignent à mesure qu'elle s'accumule, un liseré plus vif au bord
  // de ce qu'elle a déjà couvert.
  vec2 grain = uv * vec2(aspect, 1.0);
  float field = 0.7 * noise(grain * 9.0 + uTime * 0.3) +
                0.3 * noise(grain * 23.0 - uTime * 0.5);
  float gathered = smoothstep(-2.3, -0.6, uWave) * 1.3 - 0.15;
  float formed = smoothstep(field - 0.12, field + 0.12, gathered);
  float rim = exp(-pow((gathered - field) / 0.05, 2.0));
  color += mix(uHot, vec3(1.0), 0.3) * glowAt(uv) * condense *
           (formed * 1.1 + rim * 1.4);

  if (uWave > 0.0) {
    // Les rayons : la lumière derrière les lettres, étirée depuis leur
    // centre vers l'extérieur, juste après le clap.
    if (uRays > 0.0) {
      vec2 toward = centreUv - uv;
      float light = 0.0;
      float weight = 1.0;
      for (int i = 0; i < 40; i++) {
        light += glowAt(uv + toward * (float(i) / 40.0) * 0.55) * weight;
        weight *= 0.94;
      }
      light = light / 45.0 * smoothstep(0.05, 0.5, uWave) * uRays;
      vec3 beam = mix(uInk, uHot, clamp(light * 0.7, 0.0, 1.0));
      float dust =
          smoothstep(0.985, 1.0,
                     noise(uv * vec2(aspect, 1.0) * 140.0 +
                           vec2(uTime * 0.5, -uTime * 0.8))) *
          1.4;
      color += beam * light * (1.0 + dust);
    }
  }

  // La brillance des lettres chargées : leur pochoir flouté, plus vif au
  // clap.
  float charge = smoothstep(-1.3, -0.15, uWave);
  if (charge > 0.0) {
    // Une lueur fine et constante, que la lumière condensée relaie : la
    // barre du K ne paraît plus s'amincir puis s'épaissir.
    float bloom = glowAt(uv);
    float flash = uWave > 0.0 ? exp(-uWave * 3.0) : 0.0;
    color += mix(uHot, vec3(1.0), 0.25) * bloom * charge *
             (0.18 * (1.0 - condense) + 1.2 * flash);
  }

  color = mix(uBlack, color, uIntensity);
  color += (hash2(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
