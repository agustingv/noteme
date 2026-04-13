namespace NoteMe
{
    public class BackupDialog : Adw.PreferencesDialog
    {
        private string? selected_backup = null;

        public BackupDialog (Preferences prefs)
        {
            Object (title: _("Backups"));

            var page = new Adw.PreferencesPage ();
            page.icon_name = "drive-harddisk-symbolic";
            page.title     = _("Backups");
            add (page);

            var dest_group = new Adw.PreferencesGroup ();
            dest_group.title = _("Create Backup");
            page.add (dest_group);

            var folder_row = new Adw.ActionRow ();
            folder_row.title    = _("Destination Folder");
            folder_row.subtitle = resolve_folder (prefs.backup_folder);

            var folder_btn = new Gtk.Button.from_icon_name ("folder-open-symbolic");
            folder_btn.tooltip_text = _("Choose folder…");
            folder_btn.add_css_class ("flat");
            folder_btn.valign = Gtk.Align.CENTER;
            folder_row.add_suffix (folder_btn);
            folder_row.activatable_widget = folder_btn;
            dest_group.add (folder_row);

            folder_btn.clicked.connect (() => {
                var fd = new Gtk.FileDialog ();
                fd.title = _("Choose Backup Folder");
                if (prefs.backup_folder.length > 0)
                    fd.initial_folder = GLib.File.new_for_path (prefs.backup_folder);
                var parent = get_root () as Gtk.Window;
                fd.select_folder.begin (parent, null, (obj, res) => {
                    try {
                        var folder = fd.select_folder.end (res);
                        prefs.backup_folder = folder.get_path ();
                        prefs.save ();
                        folder_row.subtitle = resolve_folder (prefs.backup_folder);
                    } catch { /* cancelled */ }
                });
            });

            var backup_status_row = new Adw.ActionRow ();
            backup_status_row.visible = false;
            dest_group.add (backup_status_row);

            var create_row = new Adw.ActionRow ();
            create_row.title    = _("Create Backup");
            create_row.subtitle = _("Archives all notes and images into a tar.gz file");

            var create_btn = new Gtk.Button.with_label (_("Create Backup"));
            create_btn.add_css_class ("suggested-action");
            create_btn.valign = Gtk.Align.CENTER;
            create_row.add_suffix (create_btn);
            create_row.activatable_widget = create_btn;
            dest_group.add (create_row);

            create_btn.clicked.connect (() => {
                run_backup (prefs, create_btn, backup_status_row);
            });
            
            var import_group = new Adw.PreferencesGroup ();
            import_group.title       = _("Restore Backup");
            import_group.description = _("Restoring a backup will overwrite current notes and images. The app must be restarted afterwards.");
            page.add (import_group);

            var file_row = new Adw.ActionRow ();
            file_row.title    = _("Backup File");
            file_row.subtitle = _("No file selected");

            var file_btn = new Gtk.Button.from_icon_name ("document-open-symbolic");
            file_btn.tooltip_text = _("Select backup file…");
            file_btn.add_css_class ("flat");
            file_btn.valign = Gtk.Align.CENTER;
            file_row.add_suffix (file_btn);
            file_row.activatable_widget = file_btn;
            import_group.add (file_row);

            var restore_row = new Adw.ActionRow ();
            restore_row.title    = _("Restore");
            restore_row.subtitle = _("Overwrites current data with the selected backup");

            var restore_btn = new Gtk.Button.with_label (_("Restore Backup"));
            restore_btn.add_css_class ("destructive-action");
            restore_btn.valign    = Gtk.Align.CENTER;
            restore_btn.sensitive = false;
            restore_row.add_suffix (restore_btn);
            restore_row.activatable_widget = restore_btn;
            import_group.add (restore_row);

            file_btn.clicked.connect (() => {
                var fd = new Gtk.FileDialog ();
                fd.title = _("Select Backup File");

                var filter = new Gtk.FileFilter ();
                filter.name = _("Backup archives");
                filter.add_pattern ("*.tar.gz");
                filter.add_pattern ("*.tgz");

                var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
                filters.append (filter);
                fd.filters        = filters;
                fd.default_filter = filter;

                if (prefs.backup_folder.length > 0)
                    fd.initial_folder = GLib.File.new_for_path (prefs.backup_folder);

                var parent = get_root () as Gtk.Window;
                fd.open.begin (parent, null, (obj, res) => {
                    try {
                        var file = fd.open.end (res);
                        selected_backup   = file.get_path ();
                        file_row.subtitle = GLib.Path.get_basename (selected_backup);
                        restore_btn.sensitive = true;
                    } catch { /* cancelled */ }
                });
            });

            restore_btn.clicked.connect (() => {
                confirm_restore (restore_btn);
            });
        }

        private void confirm_restore (Gtk.Button restore_btn)
        {
            var window  = get_root () as Gtk.Window;
            var confirm = new Adw.AlertDialog (
                _("Restore Backup?"),
                _("This will overwrite all current notes and images. The application must be restarted to apply the changes.")
            );
            confirm.add_response ("cancel",  _("Cancel"));
            confirm.add_response ("restore", _("Restore"));
            confirm.set_response_appearance ("restore", Adw.ResponseAppearance.DESTRUCTIVE);
            confirm.default_response = "cancel";
            confirm.choose.begin (window, null, (obj, res) => {
                if (confirm.choose.end (res) == "restore")
                    run_restore (restore_btn);
            });
        }

        private void run_restore (Gtk.Button restore_btn)
        {
            if (selected_backup == null) return;

            string data_dir = GLib.Environment.get_user_data_dir ();
            restore_btn.sensitive = false;

            try {
                var proc = new GLib.Subprocess.newv (
                    { "tar", "-xzf", selected_backup, "-C", data_dir },
                    GLib.SubprocessFlags.STDERR_PIPE
                );
                proc.wait_async.begin (null, (obj, res) => {
                    try {
                        proc.wait_async.end (res);
                        if (proc.get_successful ()) {
                            show_restart_dialog ();
                        } else {
                            show_error (_("Restore failed"), read_stderr (proc));
                            restore_btn.sensitive = true;
                        }
                    } catch (Error e) {
                        show_error (_("Restore error"), e.message);
                        restore_btn.sensitive = true;
                    }
                });
            } catch (Error e) {
                show_error (_("Restore error"), e.message);
                restore_btn.sensitive = true;
            }
        }

        private void show_restart_dialog ()
        {
            var window  = get_root () as Gtk.Window;
            var dialog  = new Adw.AlertDialog (
                _("Backup Restored"),
                _("The backup has been restored. Please restart the application to apply the changes.")
            );
            dialog.add_response ("close",   _("Close"));
            dialog.add_response ("restart", _("Restart Now"));
            dialog.set_response_appearance ("restart", Adw.ResponseAppearance.SUGGESTED);
            dialog.default_response = "restart";
            dialog.choose.begin (window, null, (obj, res) => {
                if (dialog.choose.end (res) == "restart") {
                    try {
                        string exe = GLib.Environment.get_prgname ();
                        GLib.Process.spawn_async (
                            null,
                            { exe },
                            null,
                            GLib.SpawnFlags.SEARCH_PATH,
                            null, null
                        );
                    } catch {}
                    window?.close ();
                }
            });
        }

        private void run_backup (Preferences prefs, Gtk.Button btn, Adw.ActionRow status_row)
        {
            string dest_folder = resolve_folder (prefs.backup_folder);
            string data_dir    = GLib.Environment.get_user_data_dir ();
            string timestamp   = new DateTime.now_local ().format ("%Y-%m-%dT%H-%M-%S");
            string filename    = "noteme-backup-%s.tar.gz".printf (timestamp);
            string dest        = GLib.Path.build_filename (dest_folder, filename);

            btn.sensitive      = false;
            status_row.visible = false;

            try {
                var proc = new GLib.Subprocess.newv (
                    { "tar", "-czf", dest, "-C", data_dir, "noteme" },
                    GLib.SubprocessFlags.STDERR_PIPE
                );
                proc.wait_async.begin (null, (obj, res) => {
                    try {
                        proc.wait_async.end (res);
                        if (proc.get_successful ()) {
                            status_row.title    = _("Backup created");
                            status_row.subtitle = filename;
                            status_row.visible  = true;
                        } else {
                            show_error (_("Backup failed"), read_stderr (proc));
                        }
                    } catch (Error e) {
                        show_error (_("Backup error"), e.message);
                    }
                    btn.sensitive = true;
                });
            } catch (Error e) {
                show_error (_("Backup error"), e.message);
                btn.sensitive = true;
            }
        }

        private string read_stderr (GLib.Subprocess proc)
        {
            try {
                var bytes = proc.get_stderr_pipe ()?.read_bytes (4096, null);
                if (bytes != null) return (string) bytes.get_data ();
            } catch {}
            return "";
        }

        private void show_error (string title, string detail)
        {
            var window = get_root () as Gtk.Window;
            var dialog = new Adw.AlertDialog (title, detail.length > 0 ? detail : null);
            dialog.add_response ("ok", _("OK"));
            dialog.present (window);
        }

        private string resolve_folder (string stored)
        {
            if (stored.length > 0) return stored;
            string? docs = GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOCUMENTS);
            return docs ?? GLib.Environment.get_home_dir ();
        }
    }
}
