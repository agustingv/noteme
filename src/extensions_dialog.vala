namespace NoteMe {

    public class ExtensionsDialog : Adw.PreferencesDialog {

        public ExtensionsDialog (ExtensionManager manager) {
            Object (title: _("Extensions"));

            var page = new Adw.PreferencesPage ();
            page.icon_name = "application-x-addon-symbolic";
            page.title     = _("Extensions");
            add (page);

            var group = new Adw.PreferencesGroup ();
            group.title       = _("Installed Extensions");
            group.description = _("External plugins can be placed in ~/.local/share/noteme/plugins/ as .so files.");
            page.add (group);

            var extensions = manager.get_extensions ();
            for (int i = 0; i < extensions.length; i++) {
                var ext = extensions[i];
                var row = new Adw.SwitchRow ();
                row.title    = ext.name;
                row.subtitle = ext.description;
                row.active   = manager.get_active (ext);
                var captured = ext;
                row.notify["active"].connect (() => manager.set_active (captured, row.active));
                group.add (row);
            }
        }
    }
}
