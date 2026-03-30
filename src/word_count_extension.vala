namespace NoteMe {

    public class WordCountExtension : Object, IExtension {
        public string id          { get { return "word-count"; } }
        public string name        { get { return _("Word Count"); } }
        public string description { get { return _("Shows word and character count in the editor toolbar."); } }

        private Gtk.Label      label;
        private ExtensionHost? host;

        public void activate (ExtensionHost h) {
            host  = h;
            label = new Gtk.Label ("");
            label.add_css_class ("dim-label");
            label.add_css_class ("caption");
            label.margin_start = 4;
            label.margin_end   = 4;
            h.add_toolbar_widget (label);
            h.note_selected.connect        (() => update ());
            h.note_content_changed.connect (() => update ());
            update ();
        }

        public void deactivate () {
            host?.remove_toolbar_widget (label);
            host = null;
        }

        private void update () {
            if (host?.current_note == null) { label.label = ""; return; }
            string text  = strip_markup (host.current_note.body);
            int    words = count_words (text);
            int    chars = text.char_count ();
            label.label  = _("%d words · %d chars").printf (words, chars);
        }

        private int count_words (string text) {
            int  count   = 0;
            bool in_word = false;
            for (int i = 0; i < text.length; ) {
                unichar c = text.get_char (i);
                if (c.isspace ()) {
                    in_word = false;
                } else if (!in_word) {
                    count++;
                    in_word = true;
                }
                i += (int) c.to_utf8 (null);
            }
            return count;
        }

        private string strip_markup (string markup) {
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
