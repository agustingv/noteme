# NoteMe

A simple note-taking application for GNOME, built with GTK4, libadwaita, and Vala.

## Features

- Create, edit, and delete notes
- Rich text formatting: **Bold**, *Italic*, Underline, `Inline Code`, and Bullet Lists
- Color labels for notes
- Search notes by title
- Notes sorted by creation time (newest first)
- Customizable editor font
- Notes saved automatically
- English and Spanish interface

## Screenshots

_Coming soon_

## Requirements

- GTK4 >= 4.0
- libadwaita >= 1.4
- Vala >= 0.56
- Meson >= 0.59

## Building

```sh
meson setup build
ninja -C build
```

## Running

```sh
./build/src/noteme
```

## Installing

```sh
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

## Data locations

- Notes: `~/.local/share/noteme/notes/`
- Preferences: `~/.config/noteme/preferences`

## License

GPL-3.0-or-later

## Links

- Repository: https://github.com/agustingv/noteme
- Issues: https://github.com/agustingv/noteme/issues
