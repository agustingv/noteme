namespace NoteMe {

    public class ImageExtension : Object, IExtension {
        public string id          { get { return "insert-image"; } }
        public string name        { get { return _("Insert Image"); } }
        public string description { get { return _("Adds a toolbar button for inserting images into notes."); } }

        private Gtk.Button     btn;
        private ExtensionHost? host;

        public void activate (ExtensionHost h) {
            host = h;
            btn  = h.add_toolbar_button ("image-x-generic-symbolic", _("Insert Image"));
            btn.sensitive = false;
            btn.clicked.connect (on_insert_clicked);
            h.note_selected.connect ((note) => btn.sensitive = note != null);
        }

        public void deactivate () {
            host?.remove_toolbar_widget (btn);
            host = null;
        }

        private void on_insert_clicked () {
            var dialog = new Gtk.FileDialog ();
            dialog.title = _("Select Image");

            var filter = new Gtk.FileFilter ();
            filter.name = _("Images");
            filter.add_mime_type ("image/png");
            filter.add_mime_type ("image/jpeg");
            filter.add_mime_type ("image/gif");
            filter.add_mime_type ("image/webp");
            filter.add_mime_type ("image/svg+xml");

            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);
            dialog.filters        = filters;
            dialog.default_filter = filter;

            var parent = btn.get_root () as Gtk.Window;
            dialog.open.begin (parent, null, (obj, res) => {
                try {
                    var file      = dialog.open.end (res);
                    var dest_path = copy_to_images_dir (file);
                    host?.insert_image (dest_path ?? file.get_path ());
                } catch { /* user cancelled */ }
            });
        }

        // Copy the chosen file into ~/.local/share/noteme/images/ and return
        // the destination path. Returns null and logs a warning on I/O error.
        private string? copy_to_images_dir (GLib.File src) {
            var images_dir = Path.build_filename (
                Environment.get_user_data_dir (), "noteme", "images"
            );
            DirUtils.create_with_parents (images_dir, 0755);

            string src_path = src.get_path ();
            int    dot      = src_path.last_index_of (".");
            string ext      = dot >= 0 ? src_path.substring (dot) : "";
            string dest_name = "%s%s".printf (GLib.Uuid.string_random (), ext);
            string dest_path = Path.build_filename (images_dir, dest_name);

            try {
                src.copy (File.new_for_path (dest_path),
                          FileCopyFlags.OVERWRITE, null, null);
                return dest_path;
            } catch (Error e) {
                warning ("Could not copy image: %s", e.message);
                return null;
            }
        }
    }
}
