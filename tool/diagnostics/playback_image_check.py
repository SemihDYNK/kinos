"""Run under xvfb-run after building playback_probe.dart (Weston, FFmpeg, Pillow).

Checks actual video pixels; a progressing playback clock can hide broken textures.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image

bundle = Path(__file__).resolve().parents[2] / 'build/linux/x64/profile/bundle/kinos'
with tempfile.TemporaryDirectory(prefix='kinos-video-') as work:
    root = Path(work)
    clip = root / 'red.mp4'
    subprocess.run([
        'ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i',
        'color=c=red:size=640x360:rate=24', '-t', '5', '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p', str(clip),
    ], check=True)
    env = dict(os.environ, XDG_RUNTIME_DIR=work, LIBGL_ALWAYS_SOFTWARE='1')
    with (root / 'weston.log').open('w') as weston_log:
        weston = subprocess.Popen([
            'weston', '--backend=x11', '--renderer=gl', '--width=1200',
            '--height=800', '--socket=video-test', '--no-config', '--idle-time=0',
        ], env=env, stdout=weston_log, stderr=weston_log)
        app = None
        try:
            for _ in range(50):
                if (root / 'video-test').exists():
                    break
                time.sleep(0.1)
            assert (root / 'video-test').exists(), 'Weston failed to start'
            with (root / 'app.log').open('w') as app_log:
                app = subprocess.Popen([str(bundle), str(clip)], stdout=app_log,
                    stderr=app_log, env=dict(env, WAYLAND_DISPLAY='video-test',
                                            GDK_BACKEND='wayland'))
                time.sleep(3)
                screenshot = root / 'frame.png'
                subprocess.run([
                    'ffmpeg', '-v', 'error', '-y', '-f', 'x11grab', '-i',
                    os.environ['DISPLAY'], '-frames:v', '1', str(screenshot),
                ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                with Image.open(screenshot) as frame:
                    red = sum(r > 180 and g < 70 and b < 70
                              for r, g, b in frame.convert('RGB').get_flattened_data())
                try:
                    result = app.wait(timeout=20)
                except subprocess.TimeoutExpired as error:
                    raise AssertionError('Playback did not finish:\n' + (root / 'app.log').read_text()) from error
                assert result == 0 and red > 100000, (
                    f'Video image missing: exit={result}, red_pixels={red}\n'
                    + (root / 'app.log').read_text())
                print(f'VIDEO_IMAGE_OK: {red} red pixels, clean playback shutdown')
        finally:
            if app is not None and app.poll() is None:
                app.kill()
                app.wait()
            weston.terminate()
            weston.wait()
