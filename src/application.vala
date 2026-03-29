namespace NoteMe {

    public class Application : Adw.Application {

        private Preferences prefs;

        public Application () {
            Object (
                application_id: "com.github.agustingv.noteme",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        construct {
            prefs = new Preferences ();

            var about_action = new SimpleAction ("about", null);
            about_action.activate.connect (show_about);
            add_action (about_action);

            var prefs_action = new SimpleAction ("preferences", null);
            prefs_action.activate.connect (show_preferences);
            add_action (prefs_action);

            set_accels_for_action ("app.preferences", { "<Ctrl>comma" });
        }

        protected override void activate () {
            var win = this.active_window;
            if (win == null) {
                win = new NoteMe.MainWindow (this, prefs);
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
