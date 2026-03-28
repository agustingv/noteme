namespace GNotes {

    [GtkTemplate (ui = "/com/github/gnotes/main-window.ui")]
    public class MainWindow : Adw.ApplicationWindow {

        [GtkChild] unowned Gtk.ListBox   notes_list;
        [GtkChild] unowned Gtk.TextView  editor;
        [GtkChild] unowned Gtk.Entry     title_entry;
        [GtkChild] unowned Gtk.Stack     content_stack;
        [GtkChild] unowned Gtk.Button    delete_button;

        private NoteStore store;
        private Note?     current_note = null;
        private bool      updating     = false;

        public MainWindow (Gtk.Application app) {
            Object (application: app);
        }

        construct {
            store = new NoteStore ();

            notes_list.bind_model (store.store, (obj) => {
                return new NoteRow ((Note) obj);
            });

            notes_list.row_selected.connect (on_row_selected);
            title_entry.changed.connect (on_title_changed);
            editor.buffer.changed.connect (on_body_changed);

            // Show empty state if no notes yet
            update_empty_state ();
        }

        [GtkCallback]
        private void on_new_note_clicked () {
            var note = store.create_note ();
            // Select newly added row (inserted at position 0)
            var row = notes_list.get_row_at_index (0);
            if (row != null) notes_list.select_row (row);
            title_entry.grab_focus ();
        }

        [GtkCallback]
        private void on_delete_clicked () {
            if (current_note == null) return;

            var dialog = new Adw.AlertDialog (
                "Delete Note?",
                ""%s" will be permanently deleted.".printf (current_note.title)
            );
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("delete", "Delete");
            dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.default_response = "cancel";
            dialog.choose.begin (this, null, (obj, res) => {
                if (dialog.choose.end (res) == "delete") {
                    store.delete_note (current_note);
                    current_note = null;
                    update_empty_state ();
                }
            });
        }

        private void on_row_selected (Gtk.ListBoxRow? row) {
            if (row == null) {
                current_note = null;
                update_empty_state ();
                return;
            }
            current_note = ((NoteRow) row.child).note;
            load_note (current_note);
            content_stack.visible_child_name = "editor";
            delete_button.sensitive = true;
        }

        private void load_note (Note note) {
            updating = true;
            title_entry.text      = note.title;
            editor.buffer.text    = note.body;
            updating = false;
        }

        private void on_title_changed () {
            if (updating || current_note == null) return;
            current_note.title = title_entry.text;
            store.save (current_note);
        }

        private void on_body_changed () {
            if (updating || current_note == null) return;
            current_note.body = editor.buffer.text;
            store.save (current_note);
        }

        private void update_empty_state () {
            if (store.store.get_n_items () == 0 || current_note == null) {
                content_stack.visible_child_name = "empty";
                delete_button.sensitive = false;
            }
        }
    }
}
