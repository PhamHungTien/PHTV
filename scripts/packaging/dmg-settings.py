"""Finder layout written directly by dmgbuild, without Apple Events."""
from pathlib import Path

app = Path(defines['app']).resolve()
background = Path(defines['background']).resolve()
if not app.is_dir() or not background.is_file():
    raise ValueError('App bundle and DMG background must exist')

format = 'UDZO'
filesystem = 'HFS+'
files = [str(app)]
symlinks = {'Applications': '/Applications'}
background = str(background)
window_rect = ((200, 120), (640, 420))
icon_locations = {'PHTV.app': (170, 210), 'Applications': (470, 210)}
icon_size = 96
text_size = 13
default_view = 'icon-view'
show_icon_preview = False
show_toolbar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False
arrange_by = None
