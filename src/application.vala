namespace NoteMe 
{

    public class Application : Adw.Application 
    {

        private Preferences prefs;
        private ExtensionManager ext_manager;

        public Application () 
        {
            Object (
                application_id: "io.github.agustingv.noteme",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        construct 
        {
            prefs = new Preferences ();
            ext_manager = new ExtensionManager ();
            ext_manager.register (new MarkdownPreviewExtension ());
            ext_manager.register (new WordCountExtension ());
            ext_manager.register (new NoteInfoExtension ());
            ext_manager.register (new ImageExtension ());
            ext_manager.load_from_directory (
                // Path differs between running from build dir and installed app, but this is fine since both will be in the same place relative to the executable
                Path.build_filename (Environment.get_user_data_dir (), "noteme", "extensions")
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

            var backup_action = new SimpleAction ("backups", null);
            backup_action.activate.connect (show_backups);
            add_action (backup_action);

            set_accels_for_action ("app.preferences", { "<Ctrl>comma" });
        }

        protected override void activate () 
        {
            var win = this.active_window;
            if (win == null) {
                win = new NoteMe.MainWindow (this, prefs, ext_manager);
            }
            win.present ();
        }

        private void show_preferences ()
        {
            var dialog = new PreferencesDialog (prefs);
            dialog.font_changed.connect ((desc) => {
                foreach (var window in get_windows ())
                    if (window is MainWindow)
                        ((MainWindow) window).apply_font_settings ();
            });
            dialog.image_size_changed.connect (() => {
                foreach (var window in get_windows ())
                    if (window is MainWindow)
                        ((MainWindow) window).apply_image_settings ();
            });
            dialog.present (active_window);
        }

        private void show_extensions ()
        {
            var dialog = new ExtensionsDialog (ext_manager);
            dialog.present (active_window);
        }

        private void show_backups ()
        {
            var dialog = new BackupDialog (prefs);
            dialog.present (active_window);
        }

        private void show_about () 
        {

            var dialog = new Adw.AboutDialog ();
            dialog.application_name = "NoteMe";
            dialog.application_icon = "io.github.agustingv.noteme";
            dialog.version          = "1.0.0";
            dialog.developer_name   = "NoteMe Contributors";
            dialog.license_type     = Gtk.License.GPL_3_0;
            dialog.website          = "https://github.com/agustingv/noteme";
            dialog.issue_url        = "https://github.com/agustingv/noteme/issues";
            dialog.comments         = _("A simple note-taking app");
            dialog.present (active_window);
        }
    }
}
