namespace NoteMe {

    public class NoteInfoExtension : Object, IExtension {
        public string id          { get { return "note-info"; } }
        public string name        { get { return _("Note Info"); } }
        public string description { get { return _("Shows detailed statistics about the current note."); } }

        private Gtk.Button     btn;
        private ExtensionHost? host;

        public void activate (ExtensionHost h) {
            host = h;
            btn  = h.addToolbarButton ("dialog-information-symbolic", _("Note Information"));
            btn.sensitive = false;
            btn.clicked.connect (showInfo);
            h.note_selected.connect ((note) => btn.sensitive = note != null);
        }

        public void deactivate () {
            host?.removeToolbarWidget (btn);
            host = null;
        }

        private void showInfo () {
            var note = host?.current_note;
            if (note == null) return;

            string plain         = stripMarkup (note.body);
            int    words         = countWords (plain);
            int    chars_total   = plain.char_count ();
            int    chars_no_sp   = countCharsNoSpaces (plain);
            int    lines         = plain == "" ? 0 : plain.split ("\n").length;
            int    read_min      = (int) Math.ceil (words / 200.0);

            var win = new Adw.Window ();
            win.title          = _("Note Information");
            win.default_width  = 360;
            win.default_height = -1;
            win.modal          = true;
            var parent = btn.get_root () as Gtk.Window;
            if (parent != null) win.set_transient_for (parent);

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (new Adw.HeaderBar ());

            var scroll = new Gtk.ScrolledWindow ();
            scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroll.propagate_natural_height = true;

            var page = new Adw.PreferencesPage ();

            // ── General ───────────────────────────────────────────────────────
            var general = new Adw.PreferencesGroup ();
            general.title = _("General");
            page.add (general);

            addRow (general, _("Title"),   note.title.length > 0 ? note.title : _("Untitled"));
            addRow (general, _("Created"), formatDate (note.created_at));
            addRow (general, _("Color"),   note.color.length > 0 ? note.color : _("None"));
            addRow (general, _("Pinned"),  note.pinned ? _("Yes") : _("No"));

            // ── Statistics ────────────────────────────────────────────────────
            var stats = new Adw.PreferencesGroup ();
            stats.title = _("Statistics");
            page.add (stats);

            addRow (stats, _("Words"),                    words.to_string ());
            addRow (stats, _("Characters"),               chars_total.to_string ());
            addRow (stats, _("Characters (no spaces)"),   chars_no_sp.to_string ());
            addRow (stats, _("Lines"),                    lines.to_string ());
            addRow (stats, _("Estimated reading time"),
                     read_min <= 1 ? _("< 1 min") : _("%d min").printf (read_min));

            scroll.child = page;
            toolbar_view.content = scroll;
            win.content = toolbar_view;
            win.present ();
        }

        private void addRow (Adw.PreferencesGroup group, string title, string value) {
            var row = new Adw.ActionRow ();
            row.title = title;
            var lbl = new Gtk.Label (value);
            lbl.add_css_class ("dim-label");
            lbl.valign = Gtk.Align.CENTER;
            lbl.ellipsize = Pango.EllipsizeMode.END;
            lbl.max_width_chars = 24;
            row.add_suffix (lbl);
            group.add (row);
        }

        private string formatDate (string iso) {
            // iso = "YYYY-MM-DDTHH:MM:SS"
            if (iso.length < 19) return iso;
            return "%s  %s".printf (iso.substring (0, 10), iso.substring (11, 8));
        }

        private int countWords (string text) {
            int  count   = 0;
            bool in_word = false;
            for (int i = 0; i < text.length; ) {
                unichar c = text.get_char (i);
                if (c.isspace ()) { in_word = false; }
                else if (!in_word) { count++; in_word = true; }
                i += (int) c.to_utf8 (null);
            }
            return count;
        }

        private int countCharsNoSpaces (string text) {
            int count = 0;
            for (int i = 0; i < text.length; ) {
                unichar c = text.get_char (i);
                if (!c.isspace ()) count++;
                i += (int) c.to_utf8 (null);
            }
            return count;
        }

        private string stripMarkup (string markup) {
            var sb = new StringBuilder ();
            int i  = 0;
            while (i < markup.length) {
                if (markup[i] == '<') {
                    int close = markup.index_of (">", i);
                    i = close >= 0 ? close + 1 : markup.length;
                } else if (markup[i] == '&') {
                    int semi = markup.index_of (";", i);
                    if (semi >= 0) {
                        string entity = markup.substring (i + 1, semi - i - 1);
                        if      (entity == "lt")  sb.append_c ('<');
                        else if (entity == "gt")  sb.append_c ('>');
                        else if (entity == "amp") sb.append_c ('&');
                        i = semi + 1;
                    } else { sb.append_c ('&'); i++; }
                } else {
                    unichar c = markup.get_char (i);
                    sb.append_unichar (c);
                    i += (int) c.to_utf8 (null);
                }
            }
            return sb.str;
        }
    }
}
