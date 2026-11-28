#version 460 core

// La lumière de l'intro de Kinos, au clap : des traînées qui filent des
// bords vers les lettres (une fois chacune, puis plus rien), des rayons
// qui traversent le K et KINOS, avec de la poussière dans la lumière, et
// derrière, des lames de verre irisées qui glissent. Les
// lettres elles-mêmes sont peintes par-dessus (cf. StartupMark) : ici, leur
// pochoir seulement.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// Secondes depuis le début de l'intro, et depuis le clap (négatif avant).
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

// Une couche de lames de verre en diagonale qui glissent : une arête vive,
// un reflet qui court le long du verre, et à l'intérieur une irisation
// limitée aux teintes voisines de la dominante.
vec3 glass(vec2 d, float depth, float speed, float density) {
  float turn = -0.62;
  vec2 q = vec2(cos(turn) * d.x - sin(turn) * d.y,
                sin(turn) * d.x + cos(turn) * d.y);
  float x = q.x * density + uTime * speed + depth * 7.0;
  float id = floor(x);
  float f = fract(x);
  float width = 0.55 + 0.45 * hash(id + depth);
  float inside = step(f, width);
  float g = f / width;
  float edge = exp(-pow(g / 0.025, 2.0)) * 1.4 +
               exp(-pow((1.0 - g) / 0.015, 2.0)) * 0.9;
  float sheen =
      pow(noise(vec2(q.y * 1.5 - uTime * speed * sign(speed) * 1.0, id)), 3.0);
  float spread = smoothstep(0.15, 0.5, g) * smoothstep(0.95, 0.55, g) *
                 (0.4 + 0.6 * noise(vec2(q.y * 2.0 + uTime * 0.2, id * 3.0)));
  float tint = fract(g * 0.6 + q.y * 0.15 + hash(id));
  vec3 iris = hsv(fract(uHue + (tint - 0.5) * 0.32), 0.75 * uIris, 1.0);
  vec3 c = vec3(0.025) + iris * spread * 0.55 * sheen * 2.0 +
           vec3(0.9) * edge * (0.25 + 0.75 * sheen) + uInk * 0.05 * g;
  return c * inside;
}

// Traînées : autant de couloirs autour du centre, un sur trois ou presque
// éteint ; chacune part d'un instant à elle, à sa vitesse, et ne passe
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

  if (uWave > 0.0) {
    // Le verre, éclairé par la lumière qui arrive : deux couches qui
    // glissent en sens contraires, plus claires près des lettres.
    float lit = smoothstep(0.3, 1.6, uWave);
    vec3 panes = glass(d, 0.0, 0.035, 2.2) +
                 glass(d * 1.4 + vec2(0.3, 0.0), 1.0, -0.06, 3.0) * 0.55;
    color += panes * lit * (1.1 - smoothstep(0.0, 1.0, r * 0.9)) * 1.1;

    // Les traînées, des bords vers les lettres.
    float lane = (angle + 3.14159) / 6.28318 * kLanes;
    float id = floor(lane);
    float across = fract(lane);
    float delay = hash(id + 11.0) * 0.45;
    float speed = 1.6 + 1.4 * hash(id);
    float travel = clamp((uWave - delay) * speed, 0.0, 1.25);
    float reach = clamp(r / (0.95 * aspect * 0.5), 0.0, 1.2);
    float head = 1.15 - travel;
    float streak = smoothstep(head + kLength, head, reach) *
                   smoothstep(head - 0.01, head, reach);
    float live = step(0.0, uWave - delay) * step(travel, 1.2);
    float thin = exp(-pow((across - 0.5) / 0.07, 2.0));
    float keep = step(0.3, hash(id + 3.0));
    vec3 tone = mix(mix(uInk, uHot, hash(id + 5.0)), vec3(1.0),
                    0.3 * hash(id + 9.0));
    color += tone * streak * thin * keep * live * smoothstep(0.05, 0.2, r) *
             2.4;

    // Les rayons : la lumière derrière les lettres, étirée depuis leur
    // centre vers l'extérieur, une fois les traînées arrivées.
    if (uRays > 0.0) {
      vec2 toward = centreUv - uv;
      float light = 0.0;
      float weight = 1.0;
      for (int i = 0; i < 40; i++) {
        light += mask(uv + toward * (float(i) / 40.0) * 0.8) * weight;
        weight *= 0.95;
      }
      light = light / 16.0 * smoothstep(0.5, 1.1, uWave) * uRays;
      vec3 beam = mix(uInk, uHot, clamp(light * 0.7, 0.0, 1.0));
      float dust =
          smoothstep(0.985, 1.0,
                     noise(uv * vec2(aspect, 1.0) * 140.0 +
                           vec2(uTime * 0.5, -uTime * 0.8))) *
          1.4;
      color += beam * light * (1.1 + dust);
    }

    // Une lueur douce autour des lettres, chargées de lumière.
    float halo = 0.0;
    for (int i = 0; i < 8; i++) {
      float a = float(i) * 0.785;
      halo += mask(uv + vec2(cos(a), sin(a)) * 0.012);
    }
    color += mix(uInk, uHot, 0.5) * halo / 8.0 * 0.25 *
             smoothstep(0.2, 1.2, uWave);
  }

  color = mix(uBlack, color, uIntensity);
  color += (hash2(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
