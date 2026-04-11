namespace NoteMe {

    public class ImageExtension : Object, IExtension {
        public string id          { get { return "insert-image"; } }
        public string name        { get { return _("Insert Image"); } }
        public string description { get { return _("Adds a toolbar button for inserting images into notes. Supports drag and drop."); } }

        private Gtk.Button      btn;
        private ExtensionHost?  host;
        private Gtk.DropTarget? drop_target;

        public void activate (ExtensionHost h) {
            host = h;
            btn  = h.add_toolbar_button ("image-x-generic-symbolic", _("Insert Image"));
            btn.sensitive = false;
            btn.clicked.connect (on_insert_clicked);
            h.note_selected.connect (on_note_selected);

            drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            drop_target.drop.connect (on_drop);
            h.add_text_view_controller (drop_target);
        }

        public void deactivate () {
            if (host != null) {
                host.note_selected.disconnect (on_note_selected);
                host.remove_toolbar_widget (btn);
                if (drop_target != null)
                    host.remove_text_view_controller (drop_target);
                host = null;
            }
            drop_target = null;
        }

        private void on_note_selected (Note? note) {
            btn.sensitive = note != null;
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

        private bool on_drop (GLib.Value val, double x, double y) {
            if (host == null) return false;
            if (!val.holds (typeof (Gdk.FileList))) return false;
            var file_list = (Gdk.FileList) val;
            if (file_list == null) return false;

            bool inserted = false;
            foreach (var file in file_list.get_files ()) {
                if (!is_image_file (file)) continue;
                host.place_cursor_at_coords (x, y);
                var dest_path = copy_to_images_dir (file);
                host.insert_image (dest_path ?? file.get_path ());
                inserted = true;
            }
            return inserted;
        }

        private bool is_image_file (GLib.File file) {
            try {
                var info = file.query_info (
                    GLib.FileAttribute.STANDARD_CONTENT_TYPE,
                    GLib.FileQueryInfoFlags.NONE
                );
                string? mime = info.get_content_type ();
                return mime != null && mime.has_prefix ("image/");
            } catch {
                return false;
            }
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
