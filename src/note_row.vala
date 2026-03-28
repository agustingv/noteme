namespace GNotes {

    [GtkTemplate (ui = "/com/github/gnotes/note-row.ui")]
    public class NoteRow : Gtk.Box {

        [GtkChild] unowned Gtk.Label title_label;
        [GtkChild] unowned Gtk.Label preview_label;

        public Note note { get; construct; }

        public NoteRow (Note note) {
            Object (note: note);
        }

        construct {
            note.notify["title"].connect (update_labels);
            note.notify["body"].connect  (update_labels);
            update_labels ();
        }

        private void update_labels () {
            title_label.label   = note.title.length > 0 ? note.title : "Untitled";
            var preview         = note.body.replace ("\n", " ");
            preview_label.label = preview.length > 60 ? preview.substring (0, 60) + "…" : preview;
        }
    }
}
