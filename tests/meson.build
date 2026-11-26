accel_test = executable('accel-test', ['accel-test.vala', accel_source],
  dependencies: [gtk_dep, glib_dep],
  vala_args: ['--target-glib=2.66'])
test('accelerator parsing', accel_test)

hot_corners_schemas = custom_target('hot-corners-schemas',
  input: 'org.mate.polo.hot-corners.gschema.xml',
  output: 'gschemas.compiled',
  build_by_default: true,
  command: [find_program('glib-compile-schemas'), '--strict', '--targetdir', meson.current_build_dir(),
            meson.current_source_dir()])
hot_corners_test = executable('hot-corners-test',
  ['hot-corners-test.vala', accel_source, hot_corners_page_sources],
  dependencies: [gtk_dep, glib_dep, gio_dep, m_dep] + monitor_info_deps,
  vala_args: ['--target-glib=2.66'] + monitor_info_vala_args,
  c_args: monitor_info_c_args)
test('hot corners page', hot_corners_test,
  env: ['GSETTINGS_BACKEND=memory', 'GSETTINGS_SCHEMA_DIR=' + meson.current_build_dir()],
  depends: hot_corners_schemas)
