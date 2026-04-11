namespace NoteMe {

    public class PreferencesDialog : Adw.PreferencesDialog {

        public signal void font_changed (string font_desc);
        public signal void image_size_changed ();

        public PreferencesDialog (Preferences prefs) {
            Object (title: _("Preferences"));

            // ── Editor page ──────────────────────────────────────────────────
            var page = new Adw.PreferencesPage ();
            page.title     = _("Editor");
            page.icon_name = "document-edit-symbolic";
            add (page);

            // ── Font group ───────────────────────────────────────────────────
            var font_group = new Adw.PreferencesGroup ();
            font_group.title = _("Font");
            page.add (font_group);

            var font_row = new Adw.ActionRow ();
            font_row.title    = _("Font");
            font_row.subtitle = prefs.editor_font_desc ?? "Sans 12";

            var font_btn = new Gtk.FontDialogButton (new Gtk.FontDialog ());
            font_btn.font_desc = Pango.FontDescription.from_string (prefs.editor_font_desc ?? "Sans 12");
            font_btn.level     = Gtk.FontLevel.FONT;
            font_btn.valign    = Gtk.Align.CENTER;
            font_row.add_suffix (font_btn);
            font_row.activatable_widget = font_btn;
            font_group.add (font_row);

            font_btn.notify["font-desc"].connect (() => {
                var desc = font_btn.font_desc.to_string ();
                font_row.subtitle = desc;
                prefs.editor_font_desc = desc;
                prefs.save ();
                font_changed (desc);
            });

            // ── Images group ─────────────────────────────────────────────────
            var img_group = new Adw.PreferencesGroup ();
            img_group.title = _("Images");
            page.add (img_group);

            int[] size_values = { 160, 320, 480 };
            var size_row = new Adw.ComboRow ();
            size_row.title = _("Display Size");
            size_row.model = new Gtk.StringList ({ _("Small (160 px)"), _("Medium (320 px)"), _("Large (480 px)") });

            int selected = 1; // default Medium
            for (int k = 0; k < size_values.length; k++) {
                if (prefs.image_display_width == size_values[k]) { selected = k; break; }
            }
            size_row.selected = selected;
            img_group.add (size_row);

            size_row.notify["selected"].connect (() => {
                prefs.image_display_width = size_values[(int) size_row.selected];
                prefs.save ();
                image_size_changed ();
            });
        }
    }
}
