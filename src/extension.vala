namespace NoteMe 
{

    // C ABI entry point that external .so extensions must export:
    //   NoteMe.IExtension* noteme_plugin_new ();
    [CCode (has_target = false)]
    public delegate IExtension? ExtensionFactory ();


    public interface IExtension : Object 
    {
        public abstract string id { get; }
        public abstract string name { get; }
        public abstract string description { get; }
        public abstract void activate (ExtensionHost host);
        public abstract void deactivate ();
    }

    // Extension API provided to extensions for interacting with the main app
    public class ExtensionHost : Object
    {

        public Note? current_note { get; internal set; }
        internal weak RichEditor? editor;

        public signal void toast_requested (string message);
        public signal void save_note_requested ();

        // Emitted when the selected note changes (null = no selection)
        public signal void note_selected (Note? note);

        // Emitted when the body of the current note changes
        public signal void note_content_changed ();

        // Add a widget to the right-hand side of the editor toolbar
        public void add_toolbar_widget (Gtk.Widget widget) 
        {
            editor?.add_extension_widget (widget);
        }

        public void remove_toolbar_widget (Gtk.Widget widget) 
        {
            editor?.remove_extension_widget (widget);
        }

        // Convenience: create a styled flat icon button, add it to the toolbar,
        // and return it so the caller can connect clicked/other signals.
        public Gtk.Button add_toolbar_button (string icon_name, string tooltip) 
        {
            var btn = new Gtk.Button.from_icon_name (icon_name);
            btn.tooltip_text = tooltip;
            btn.add_css_class ("flat");
            add_toolbar_widget (btn);
            return btn;
        }

        // Insert an image at the editor's current cursor position
        public void insert_image (string path) 
        {
            editor?.insert_image_at_cursor (path);
        }

        // Add a widget to the editor footer (left of the cursor-position label)
        public void add_footer_widget (Gtk.Widget widget)
        {
            editor?.add_footer_extension_widget (widget);
        }

        public void remove_footer_widget (Gtk.Widget widget)
        {
            editor?.remove_footer_extension_widget (widget);
        }

        // Show a brief notification in the main window
        public void show_toast (string message)
        {
            toast_requested (message);
        }

        // Persist the current note to disk (use after modifying note.body directly)
        public void save_current_note ()
        {
            save_note_requested ();
        }

        // Add/remove an event controller on the editor's text view
        public void add_text_view_controller (Gtk.EventController controller)
        {
            editor?.add_text_view_controller (controller);
        }

        public void remove_text_view_controller (Gtk.EventController controller)
        {
            editor?.remove_text_view_controller (controller);
        }

        // Position the cursor at widget-relative coordinates (useful for drop targets)
        public void place_cursor_at_coords (double x, double y)
        {
            editor?.place_cursor_at_coords (x, y);
        }

        // Get the current note body converted to markdown
        public string get_note_markdown ()
        {
            if (editor == null) return "";
            return editor.markup_to_markdown (editor.get_markup ());
        }

        // Set or clear the preview panel (right side of the editor pane)
        public void set_preview_widget (Gtk.Widget? widget)
        {
            editor?.set_preview_widget (widget);
        }

        // Split the preview pane at the center
        public void center_preview_pane ()
        {
            editor?.center_preview_pane ();
        }

        // Show the "locked" placeholder instead of the editor text view
        public void set_editor_locked (bool locked)
        {
            editor?.set_locked (locked);
        }

        // Allow/disallow editing in the text view
        public void set_editor_editable (bool editable)
        {
            editor?.set_editable (editable);
        }

        // Replace editor content without firing the note-save path
        public void set_editor_markup_silent (string markup)
        {
            editor?.set_markup_silent (markup);
        }

        // Get raw markup from editor
        public string get_note_markup ()
        {
            return editor?.get_markup () ?? "";
        }
    }

    // Manages registration, loading, and lifecycle of extensions
    public class ExtensionManager : Object 
    {

        private class ExtEntry : Object 
        {
            public IExtension ext;
            public bool active = false;
            public ExtEntry (IExtension e) { ext = e; }
        }

        // Keeps GModule handles alive so their symbols remain valid
        private class ModuleHolder : Object 
        {
            // glib 2.0 Module 
            // @see https://valadoc.org/glib-2.0/GLib.Module.html
            private GLib.Module? mod;
            public ModuleHolder (owned GLib.Module? m) { mod = (owned) m; }
        }

        // glib 2.0 GenericArray
        // @see https://valadoc.org/glib-2.0/GLib.GenericArray.html
        private GenericArray<ExtEntry> entries = new GenericArray<ExtEntry> ();
        private GenericArray<ModuleHolder> mod_holders = new GenericArray<ModuleHolder> ();
        private ExtensionHost? host = null;

        // Register a built-in extension
        public void register (IExtension ext)
        {
            entries.add (new ExtEntry (ext));
        }

        // Load all .so plugins from a directory
        public void load_from_directory (string dir_path) 
        {
            try 
            {
                var dir = Dir.open (dir_path);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    if (!name.has_suffix (".so")) continue;
                    load_plugin (Path.build_filename (dir_path, name));
                }
            } 
            catch (Error e) 
            { 
                warning ("Could not load extensions from %s: %s", dir_path, e.message); 
            }
        }

        private void load_plugin (string path) 
        {
            var mod = GLib.Module.open (path, GLib.ModuleFlags.LAZY);
            if (mod == null) 
            {
                warning ("Cannot open plugin %s: %s", path, GLib.Module.error ());
                return;
            }
            void* sym;
            if (!mod.symbol ("noteme_plugin_new", out sym)) 
            {
                warning ("Plugin %s missing noteme_plugin_new symbol", path);
                return;
            }
            var ext = ((ExtensionFactory) sym) ();
            if (ext == null) return;
            register (ext);
            mod_holders.add (new ModuleHolder ((owned) mod));
        }

        // Activate all registered extensions with the given host
        public void activate_all (ExtensionHost exthost) 
        {
            host = exthost;
            for (int i = 0; i < entries.length; i++) 
            {
                entries[i].ext.activate (host);
                entries[i].active = true;
            }
        }

        // Deactivate all active extensions (e.g. on shutdown)
        public void deactivate_all () 
        {
            for (int i = entries.length - 1; i >= 0; i--) {
                if (entries[i].active) {
                    entries[i].ext.deactivate ();
                    entries[i].active = false;
                }
            }
        }

        // Toggle a single extension at runtime
        public void set_active (IExtension ext, bool active) 
        {
            for (int i = 0; i < entries.length; i++) 
            {
                if (entries[i].ext != ext) continue;
                if (active == entries[i].active) return;
                if (active && host != null) 
                {
                    entries[i].ext.activate (host);
                    entries[i].active = true;
                } 
                else 
                {
                    entries[i].ext.deactivate ();
                    entries[i].active = false;
                }
                return;
            }
        }

        public bool get_active (IExtension ext) 
        {
            for (int i = 0; i < entries.length; i++)
                if (entries[i].ext == ext) return entries[i].active;
            return false;
        }

        public GenericArray<IExtension> get_extensions () 
        {
            var list = new GenericArray<IExtension> ();
            for (int i = 0; i < entries.length; i++)
                list.add (entries[i].ext);
            return list;
        }
    }
}
