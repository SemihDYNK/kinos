"""Sons provisoires de l'intro, synthétisés (aucune licence tierce).

Usage : python3 tool/sounds/synthesize.py  -> assets/sounds/*.wav
"""
import wave
import numpy as np

RATE = 48000
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def bandpass(signal, low, high):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    spectrum[(freqs < low) | (freqs > high)] = 0
    return np.fft.irfft(spectrum, len(signal))


def save(name, signal, peak_db):
    signal = signal / np.max(np.abs(signal)) * 10 ** (peak_db / 20)
    data = (signal * 32767).astype(np.int16)
    with wave.open(f"assets/sounds/{name}.wav", "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())


def clap():
    length = .45
    time = t(length)
    # Claquement : bruit très bref, très aigu.
    snap = rng.standard_normal(len(time)) * np.exp(-time / .0018)
    snap = bandpass(snap, 1500, 12000)
    # Résonance boisée de la planchette.
    body = bandpass(rng.standard_normal(len(time)), 600, 1800) * np.exp(-time / .035)
    tone = (np.sin(2 * np.pi * 820 * time) * .5 +
            np.sin(2 * np.pi * 1240 * time) * .3) * np.exp(-time / .045)
    # Choc grave de l'impact.
    thump = np.sin(2 * np.pi * 95 * time) * np.exp(-time / .07)
    # Petite réflexion de salle.
    sound = snap * 1.0 + body * .55 + tone * .35 + thump * .5
    delay = int(.019 * RATE)
    sound[delay:] += sound[:-delay] * .18
    fade = np.minimum(1, (length - time) / .05)
    save("intro_clap", sound * fade, -3)


def projector(length, name):
    time = t(length)
    sound = np.zeros(len(time))
    # Moteur : ronronnement grave qui monte en régime.
    spin = np.minimum(1, time / .25)
    motor = (np.sin(2 * np.pi * 55 * time) * .6 +
             np.sin(2 * np.pi * 110 * time) * .3 +
             np.sin(2 * np.pi * 165 * time) * .15) * spin
    motor += bandpass(rng.standard_normal(len(time)), 80, 400) * .25 * spin
    sound += motor * .35
    # Obturateur : clics qui accélèrent jusqu'à ~24 par seconde.
    click_len = int(.006 * RATE)
    click_time = np.arange(click_len) / RATE
    position = 0.0
    while position < length - .01:
        rate = 10 + 14 * min(1, position / .3)
        start = int(position * RATE)
        click = bandpass(rng.standard_normal(click_len * 8), 1800, 7000)[:click_len]
        click *= np.exp(-click_time / .0012) * (.8 + .4 * rng.random())
        end = min(len(sound), start + click_len)
        sound[start:end] += click[:end - start]
        position += 1 / rate * (1 + .06 * rng.standard_normal())
    # Entrée et sortie en fondu.
    envelope = np.minimum(1, time / .05) * np.minimum(1, (length - time) / (length * .45))
    save(name, sound * envelope, -9)


clap()
projector(1.8, "intro_projector")
projector(.7, "intro_projector_short")
