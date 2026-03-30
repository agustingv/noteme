namespace NoteMe {

    // C ABI entry point that external .so plugins must export:
    //   NoteMe.IExtension* noteme_plugin_new ();
    [CCode (has_target = false)]
    public delegate IExtension? ExtensionFactory ();

    // Interface every extension (built-in or external) must implement
    public interface IExtension : Object {
        public abstract string id          { get; }
        public abstract string name        { get; }
        public abstract string description { get; }
        public abstract void activate   (ExtensionHost host);
        public abstract void deactivate ();
    }

    // Stable API surface provided to extensions
    public class ExtensionHost : Object {

        public Note? current_note { get; internal set; }
        internal weak RichEditor? editor;

        // Emitted when the selected note changes (null = no selection)
        public signal void note_selected (Note? note);
        // Emitted when the body of the current note changes
        public signal void note_content_changed ();

        // Add a widget to the right-hand side of the editor toolbar
        public void add_toolbar_widget (Gtk.Widget w) {
            editor?.add_extension_widget (w);
        }

        public void remove_toolbar_widget (Gtk.Widget w) {
            editor?.remove_extension_widget (w);
        }
    }

    // Manages registration, loading, and lifecycle of extensions
    public class ExtensionManager : Object {

        private class ExtEntry : Object {
            public IExtension ext;
            public bool       active = false;
            public ExtEntry (IExtension e) { ext = e; }
        }

        // Keeps GModule handles alive so their symbols remain valid
        private class ModuleHolder : Object {
            private GLib.Module? mod;
            public ModuleHolder (owned GLib.Module? m) { mod = (owned) m; }
        }

        private GenericArray<ExtEntry>     entries     = new GenericArray<ExtEntry> ();
        private GenericArray<ModuleHolder> mod_holders = new GenericArray<ModuleHolder> ();
        private ExtensionHost?             host        = null;

        // Register a built-in extension
        public void register (IExtension ext) {
            entries.add (new ExtEntry (ext));
        }

        // Load all .so plugins from a directory
        public void load_from_directory (string dir_path) {
            try {
                var dir = Dir.open (dir_path);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    if (!name.has_suffix (".so")) continue;
                    load_plugin (Path.build_filename (dir_path, name));
                }
            } catch { /* directory may not exist */ }
        }

        private void load_plugin (string path) {
            var mod = GLib.Module.open (path, GLib.ModuleFlags.LAZY);
            if (mod == null) {
                warning ("Cannot open plugin %s: %s", path, GLib.Module.error ());
                return;
            }
            void* sym;
            if (!mod.symbol ("noteme_plugin_new", out sym)) {
                warning ("Plugin %s missing noteme_plugin_new symbol", path);
                return;
            }
            var ext = ((ExtensionFactory) sym) ();
            if (ext == null) return;
            register (ext);
            mod_holders.add (new ModuleHolder ((owned) mod));
        }

        // Activate all registered extensions with the given host
        public void activate_all (ExtensionHost h) {
            host = h;
            for (int i = 0; i < entries.length; i++) {
                entries[i].ext.activate (h);
                entries[i].active = true;
            }
        }

        // Deactivate all active extensions (e.g. on shutdown)
        public void deactivate_all () {
            for (int i = entries.length - 1; i >= 0; i--) {
                if (entries[i].active) {
                    entries[i].ext.deactivate ();
                    entries[i].active = false;
                }
            }
        }

        // Toggle a single extension at runtime
        public void set_active (IExtension ext, bool active) {
            for (int i = 0; i < entries.length; i++) {
                if (entries[i].ext != ext) continue;
                if (active == entries[i].active) return;
                if (active && host != null) {
                    entries[i].ext.activate (host);
                    entries[i].active = true;
                } else {
                    entries[i].ext.deactivate ();
                    entries[i].active = false;
                }
                return;
            }
        }

        public bool get_active (IExtension ext) {
            for (int i = 0; i < entries.length; i++)
                if (entries[i].ext == ext) return entries[i].active;
            return false;
        }

        public GenericArray<IExtension> get_extensions () {
            var list = new GenericArray<IExtension> ();
            for (int i = 0; i < entries.length; i++)
                list.add (entries[i].ext);
            return list;
        }
    }
}
