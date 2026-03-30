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
        btn  = new Gtk.Button.with_label ("Hi");
        btn.add_css_class ("flat");
        btn.clicked.connect (() => {
            if (host.current_note != null)
                print ("Note: %s\n", host.current_note.title);
        });
        h.add_toolbar_widget (btn);
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
| `host.add_toolbar_widget(w)` | Append a widget to the editor toolbar |
| `host.remove_toolbar_widget(w)` | Remove a previously added toolbar widget |
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
