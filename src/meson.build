resources = gnome.compile_resources(
  'gnotes-resources',
  '../data/gnotes.gresource.xml',
  source_dir: '../data',
  c_name: 'gnotes',
)

sources = files(
  'main.vala',
  'application.vala',
  'note.vala',
  'note_store.vala',
  'note_row.vala',
  'main_window.vala',
)

dependencies = [
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
]

executable('gnotes',
  sources + resources,
  dependencies: dependencies,
  vala_args: ['--target-glib=2.76'],
  install: true,
)
