# dmgbuild settings for OnlyLimits — styled drag-to-Applications window.
application = defines.get('app', 'OnlyLimits.app')
appname = 'OnlyLimits.app'

files = [application]
symlinks = {'Applications': '/Applications'}
icon_locations = {
    appname: (160, 215),
    'Applications': (480, 215),
}
background = 'dmg/background.png'
default_view = 'icon-view'
window_rect = ((220, 140), (640, 420))
icon_size = 128
text_size = 12
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
format = 'UDZO'
