project('noteme', 'vala', 'c',
  version: '1.0',
  meson_version: '>= 0.59.0',
  default_options: [
    'buildtype=debug',
    'warning_level=2',
    'default_library=static'
  ],
)

gnome = import('gnome')
i18n = import('i18n')

noteme_name = meson.project_name() 

add_project_arguments(
  ['-DGETTEXT_PACKAGE="' + noteme_name + '"',
  '-DHANDY_USE_UNSTABLE_API',
  '-w'],
  language: 'c',
)

subdir('data')
if find_program('msgfmt', required: false).found()
  subdir('po')
endif
subdir('src')
