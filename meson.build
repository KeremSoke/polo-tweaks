project('polo-tweaks', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0',
  license: 'GPL-3.0-or-later',
  default_options: ['warning_level=1'])

gettext_package = meson.project_name()
prefix = get_option('prefix')

add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_package), language: 'c')
add_project_arguments('-w', language: 'c')

subdir('po')
subdir('src')
subdir('data')
subdir('tests')
