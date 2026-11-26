conf = configuration_data()
conf.set('VERSION', meson.project_version())
conf.set('GETTEXT_PACKAGE', gettext_package)
conf.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_vala = configure_file(input: 'config.vala.in', output: 'config.vala', configuration: conf)

gtk_dep = dependency('gtk+-3.0', version: '>= 3.24')
glib_dep = dependency('glib-2.0', version: '>= 2.66')
gio_dep = dependency('gio-2.0')
m_dep = meson.get_compiler('c').find_library('m')

mate_desktop_dep = dependency('mate-desktop-2.0', version: '>= 1.29', required: false)
monitor_info_vala_args = []
monitor_info_c_args = []
monitor_info_deps = []
if mate_desktop_dep.found() and meson.get_compiler('c').has_header('libmate-desktop/mate-monitor-info.h',
    dependencies: mate_desktop_dep, args: '-DMATE_DESKTOP_USE_UNSTABLE_API')
  monitor_info_vala_args = ['--vapidir', meson.project_source_root() / 'vapi',
                            '--define=HAVE_MATE_MONITOR_INFO']
  monitor_info_c_args = ['-DMATE_DESKTOP_USE_UNSTABLE_API']
  monitor_info_deps = [mate_desktop_dep]
endif

accel_source = files('accel.vala')
hot_corners_page_sources = files('schemas.vala', 'conflicts.vala', 'ui.vala', 'widgets.vala',
  'shortcut-widgets.vala', 'page.vala', 'screens.vala', 'hot-corner-geometry.vala', 'page-hot-corners.vala')

executable('polo-tweaks',
  [config_vala,
   'accel.vala', 'schemas.vala', 'conflicts.vala', 'ui.vala', 'widgets.vala',
   'shortcut-widgets.vala', 'page.vala',
   'page-general.vala', 'page-background.vala', 'screens.vala', 'hot-corner-geometry.vala', 'page-hot-corners.vala', 'page-wobbly.vala', 'page-animations.vala',
   'page-expo.vala', 'page-cube.vala', 'page-shortcuts.vala',
   'window.vala', 'main.vala'],
  dependencies: [gtk_dep, glib_dep, gio_dep, m_dep] + monitor_info_deps,
  vala_args: ['--target-glib=2.66'] + monitor_info_vala_args,
  c_args: monitor_info_c_args,
  install: true)
