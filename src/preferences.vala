namespace NoteMe {

    public class Preferences : Object {

        private string config_path;
        private KeyFile keyfile;

        public string? editor_font_desc    { get; set; }
        public int     image_display_width { get; set; default = 320; }

        public Preferences () {
            editor_font_desc    = "Sans 12";
            image_display_width = 320;
            var config_dir = Path.build_filename (
                Environment.get_user_config_dir (), "noteme"
            );
            DirUtils.create_with_parents (config_dir, 0755);
            config_path = Path.build_filename (config_dir, "preferences");
            keyfile     = new KeyFile ();
            load ();
        }

        private void load () {
            try {
                keyfile.load_from_file (config_path, KeyFileFlags.NONE);
                editor_font_desc    = keyfile.get_string  ("Editor", "font-desc");
                image_display_width = keyfile.get_integer ("Images", "display-width");
            } catch { /* use defaults */ }
        }

        public void save () {
            keyfile.set_string  ("Editor", "font-desc",      editor_font_desc ?? "Sans 12");
            keyfile.set_integer ("Images", "display-width",  image_display_width);
            try {
                keyfile.save_to_file (config_path);
            } catch (Error e) {
                warning ("Could not save preferences: %s", e.message);
            }
        }
    }
}
