namespace NoteMe {

    public class Application : Adw.Application {

        private Preferences      prefs;
        private ExtensionManager ext_manager;

        public Application () {
            Object (
                application_id: "com.github.agustingv.noteme",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        construct {
            prefs       = new Preferences ();
            ext_manager = new ExtensionManager ();
            ext_manager.register (new WordCountExtension ());
            ext_manager.register (new NoteInfoExtension ());
            ext_manager.register (new ImageExtension ());
            ext_manager.load_from_directory (
                Path.build_filename (Environment.get_user_data_dir (), "noteme", "plugins")
            );

            var about_action = new SimpleAction ("about", null);
            about_action.activate.connect (show_about);
            add_action (about_action);

            var prefs_action = new SimpleAction ("preferences", null);
            prefs_action.activate.connect (show_preferences);
            add_action (prefs_action);

            var ext_action = new SimpleAction ("extensions", null);
            ext_action.activate.connect (show_extensions);
            add_action (ext_action);

            set_accels_for_action ("app.preferences", { "<Ctrl>comma" });
        }

        protected override void activate () {
            var win = this.active_window;
            if (win == null) {
                win = new NoteMe.MainWindow (this, prefs, ext_manager);
            }
            win.present ();
        }

        private void show_preferences (SimpleAction _action, Variant? _param) {
            var dialog = new PreferencesDialog (prefs);
            dialog.font_changed.connect ((desc) => {
                foreach (var w in get_windows ()) {
                    if (w is MainWindow)
                        ((MainWindow) w).apply_font_settings ();
                }
            });
            dialog.present (active_window);
        }

        private void show_extensions (SimpleAction _action, Variant? _param) {
            var dialog = new ExtensionsDialog (ext_manager);
            dialog.present (active_window);
        }

        private void show_about (SimpleAction _action, Variant? _param) {
            var dialog = new Adw.AboutDialog ();
            dialog.application_name = "NoteMe";
            dialog.application_icon = "com.github.agustingv.noteme";
            dialog.version          = "1.0.0";
            dialog.developer_name   = "NoteMe Contributors";
            dialog.license_type     = Gtk.License.GPL_3_0;
            dialog.website          = "https://github.com/agustingv/noteme";
            dialog.issue_url        = "https://github.com/agustingv/noteme/issues";
            dialog.comments         = _("A simple note-taking app built with GTK4 and Vala.");
            dialog.present (active_window);
        }
    }
}
