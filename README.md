# NoteMe

A simple note-taking application for GNOME, built with GTK4, libadwaita, and Vala.

## Features

- Create, edit, and delete notes
- Rich text formatting: **Bold**, *Italic*, Underline, `Inline Code`, and Bullet Lists
- Markdown headings (`#`, `##`, `###`) and blockquotes (`>`) in the editor
- Live markdown preview (side-by-side)
- Pin notes to keep them at the top of the list
- Color labels for notes
- Insert images into notes
- Export notes to Markdown (`.md`) or plain text (`.txt`)
- Search notes by title
- Notes sorted by date (pinned notes first, then newest first)
- Customizable editor font
- Cursor position indicator (line and column)
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

## Flatpak

The manifest is `io.github.agustingv.noteme.yml` at the root of the repository.

### Prerequisites

Install the GNOME runtime and SDK (one-time):

```sh
flatpak install flathub org.gnome.Platform//47 org.gnome.Sdk//47
```

### Build and install

```sh
flatpak-builder --user --install --force-clean .flatpak-build io.github.agustingv.noteme.yml
```

`--force-clean` removes any previous build directory. The result is installed under your user Flatpak store.

### Run

```sh
flatpak run io.github.agustingv.noteme
```

### Uninstall

```sh
flatpak uninstall io.github.agustingv.noteme
```

> **Note on app data inside Flatpak:** paths that normally resolve to `~/.local/share/noteme/` and `~/.config/noteme/` are transparently redirected by the sandbox to `~/.var/app/io.github.agustingv.noteme/data/noteme/` and `~/.var/app/io.github.agustingv.noteme/config/noteme/` respectively. Image files inserted into notes are stored in the sandboxed data directory as well.

## Installing

```sh
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+B` | Bold |
| `Ctrl+I` | Italic |
| `Ctrl+U` | Underline |
| `Ctrl+\`` | Inline code |
| `Ctrl+Shift+L` | Toggle bullet list |
| `Ctrl+Shift+P` | Toggle markdown preview |

## Extensions

Extensions can add widgets to the editor toolbar and react to note events. Built-in extensions are managed via the **Extensions** entry in the main menu.

### Installing external extensions

Place compiled `.so` files in `~/.local/share/noteme/plugins/`. They are loaded automatically at startup.

### Writing an extension (Vala)

Create a file `my_extension.vala`:

```vala
public class MyExtension : Object, NoteMe.IExtension {
    public string id          { get { return "my-extension"; } }
    public string name        { get { return "My Extension"; } }
    public string description { get { return "Does something useful."; } }

    private Gtk.Button btn;
    private NoteMe.ExtensionHost? host;

    public void activate (NoteMe.ExtensionHost h) {
        host = h;
        btn  = h.add_toolbar_button ("dialog-information-symbolic", "Show note title");
        btn.sensitive = false;
        btn.clicked.connect (() => {
            if (host.current_note != null)
                print ("Note: %s\n", host.current_note.title);
        });
        h.note_selected.connect ((note) => btn.sensitive = note != null);
    }

    public void deactivate () {
        host?.remove_toolbar_widget (btn);
        host = null;
    }
}

// Required entry point — must be exported with C linkage
[CCode (cname = "noteme_plugin_new")]
public NoteMe.IExtension? noteme_plugin_new () {
    return new MyExtension ();
}
```

### Compiling an extension

You need the NoteMe Vala sources on the include path so the compiler can see `IExtension` and `ExtensionHost`. The simplest way is to point `--vapidir` at the installed VAPI or compile against the source tree directly.

```sh
valac --pkg gtk4 --pkg libadwaita-1 \
      --pkg gmodule-2.0 \
      --vapidir /path/to/noteme/vapi \
      --pkg noteme \
      -X -fPIC -X -shared \
      -o my_extension.so \
      my_extension.vala
```

If you are building against the source tree (no installed VAPI), compile the relevant interface sources together with your plugin:

```sh
valac --pkg gtk4 --pkg libadwaita-1 --pkg gmodule-2.0 \
      -X -fPIC -X -shared \
      -o my_extension.so \
      /path/to/noteme/src/note.vala \
      /path/to/noteme/src/extension.vala \
      my_extension.vala
```

Then copy the result to the plugins directory:

```sh
mkdir -p ~/.local/share/noteme/plugins
cp my_extension.so ~/.local/share/noteme/plugins/
```

### Extension API reference

| Symbol | Description |
|---|---|
| `host.current_note` | The currently selected `Note`, or `null` |
| `host.add_toolbar_widget(w)` | Append any widget to the editor toolbar |
| `host.remove_toolbar_widget(w)` | Remove a previously added toolbar widget |
| `host.add_toolbar_button(icon, tooltip)` | Create a styled flat icon button, add it to the toolbar, and return it |
| `host.add_footer_widget(w)` | Append a widget to the editor footer (left of the cursor position) |
| `host.remove_footer_widget(w)` | Remove a previously added footer widget |
| `host.note_selected(note)` | Signal: fired when the selected note changes |
| `host.note_content_changed()` | Signal: fired when the note body is edited |

## Data locations

- Notes: `~/.local/share/noteme/notes/`
- Preferences: `~/.config/noteme/preferences`
- Plugins: `~/.local/share/noteme/plugins/`

## License

GPL-3.0-or-later

## Links

- Repository: https://github.com/agustingv/noteme
- Issues: https://github.com/agustingv/noteme/issues
