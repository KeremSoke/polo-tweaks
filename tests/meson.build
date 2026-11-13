accel_test = executable('accel-test', ['accel-test.vala', accel_source],
  dependencies: [gtk_dep, glib_dep],
  vala_args: ['--target-glib=2.66'])
test('accelerator parsing', accel_test)
