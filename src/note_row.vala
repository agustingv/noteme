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
            var preview         = note.body.replace ("\n", " ");
            preview_label.label = preview.length > 60 ? preview.substring (0, 60) + "…" : preview;
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
