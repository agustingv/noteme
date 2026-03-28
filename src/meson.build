resources = gnome.compile_resources(
  'noteme-resources',
  '../data/noteme.gresource.xml',
  source_dir: '../data',
  c_name: 'noteme',
)

config_vala = configure_file(
  input:  'config.vala.in',
  output: 'config.vala',
  configuration: {
    'GETTEXT_PACKAGE': meson.project_name(),
    'LOCALE_DIR': get_option('prefix') / get_option('localedir'),
  },
)

sources = files(
  'main.vala',
  'application.vala',
  'preferences.vala',
  'preferences_dialog.vala',
  'note.vala',
  'note_store.vala',
  'note_row.vala',
  'rich_editor.vala',
  'main_window.vala',
) + [config_vala]

dependencies = [
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
]

executable('noteme',
  sources + resources,
  dependencies: dependencies,
  vala_args: ['--target-glib=2.76'],
  install: true,
)
