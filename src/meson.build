conf = configuration_data()
conf.set('VERSION', meson.project_version())
conf.set('GETTEXT_PACKAGE', gettext_package)
conf.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_vala = configure_file(input: 'config.vala.in', output: 'config.vala', configuration: conf)

gtk_dep = dependency('gtk+-3.0', version: '>= 3.24')
glib_dep = dependency('glib-2.0', version: '>= 2.66')
gio_dep = dependency('gio-2.0')
m_dep = meson.get_compiler('c').find_library('m')

accel_source = files('accel.vala')

executable('polo-tweaks',
  [config_vala,
   'accel.vala', 'schemas.vala', 'conflicts.vala', 'ui.vala', 'widgets.vala',
   'shortcut-widgets.vala', 'page.vala',
   'page-general.vala', 'page-wobbly.vala', 'page-animations.vala',
   'page-expo.vala', 'page-cube.vala', 'page-shortcuts.vala',
   'window.vala', 'main.vala'],
  dependencies: [gtk_dep, glib_dep, gio_dep, m_dep],
  vala_args: ['--target-glib=2.66'],
  install: true)
