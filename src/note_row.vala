namespace NoteMe {

    [GtkTemplate (ui = "/com/github/agustingv/noteme/ui/note-row.ui")]
    public class NoteRow : Gtk.Box {

        [GtkChild] unowned Gtk.Label       title_label;
        [GtkChild] unowned Gtk.Label       preview_label;
        [GtkChild] unowned Gtk.DrawingArea color_strip;

        public Note note { get; construct; }

        public NoteRow (Note note) {
            Object (note: note);
        }

        construct {
            color_strip.set_draw_func (draw_color);

            note.notify["title"].connect (update_labels);
            note.notify["body"].connect  (update_labels);
            note.notify["color"].connect (() => color_strip.queue_draw ());

            update_labels ();
        }

        private void update_labels () {
            title_label.label   = note.title.length > 0 ? note.title : "Untitled";
            var preview         = strip_markup (note.body).replace ("\n", " ");
            preview_label.label = preview.length > 60 ? preview.substring (0, 60) + "…" : preview;
        }

        private string strip_markup (string markup) {
            var sb = new StringBuilder ();
            int i = 0;
            int len = markup.length;
            while (i < len) {
                if (markup[i] == '<') {
                    // Skip to end of tag
                    int close = markup.index_of (">", i);
                    i = close >= 0 ? close + 1 : len;
                } else if (markup[i] == '&') {
                    int semi = markup.index_of (";", i);
                    if (semi >= 0) {
                        string entity = markup.substring (i + 1, semi - i - 1);
                        if      (entity == "lt")  sb.append_c ('<');
                        else if (entity == "gt")  sb.append_c ('>');
                        else if (entity == "amp") sb.append_c ('&');
                        i = semi + 1;
                    } else {
                        sb.append_c ('&');
                        i++;
                    }
                } else {
                    unichar c = markup.get_char (i);
                    sb.append_unichar (c);
                    i += (int) c.to_utf8 (null);
                }
            }
            return sb.str;
        }

        private void draw_color (Gtk.DrawingArea _da, Cairo.Context cr, int w, int h) {
            if (note.color == "") return;
            var rgba = Gdk.RGBA ();
            rgba.parse (note.color);
            cr.set_source_rgba (rgba.red, rgba.green, rgba.blue, rgba.alpha);
            cr.rectangle (0, 0, w, h);
            cr.fill ();
        }
    }
}
