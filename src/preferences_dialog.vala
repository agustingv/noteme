namespace NoteMe {

    public class PreferencesDialog : Adw.PreferencesDialog {

        public signal void font_changed (string font_desc);

        public PreferencesDialog (Preferences prefs) {
            Object (title: _("Preferences"));

            // ── Editor page ──────────────────────────────────────────────────
            var page = new Adw.PreferencesPage ();
            page.title    = _("Editor");
            page.icon_name = "document-edit-symbolic";
            add (page);

            // ── Font group ───────────────────────────────────────────────────
            var group = new Adw.PreferencesGroup ();
            group.title = _("Font");
            page.add (group);

            // Font picker row
            var font_row = new Adw.ActionRow ();
            font_row.title    = _("Font");
            font_row.subtitle = prefs.editor_font_desc;

            var font_btn = new Gtk.FontDialogButton (new Gtk.FontDialog ());
            font_btn.font_desc = Pango.FontDescription.from_string (prefs.editor_font_desc);
            font_btn.level     = Gtk.FontLevel.FONT;
            font_btn.valign    = Gtk.Align.CENTER;
            font_row.add_suffix (font_btn);
            font_row.activatable_widget = font_btn;
            group.add (font_row);

            font_btn.notify["font-desc"].connect (() => {
                var desc = font_btn.font_desc.to_string ();
                font_row.subtitle = desc;
                prefs.editor_font_desc = desc;
                prefs.save ();
                font_changed (desc);
            });
        }
    }
}
