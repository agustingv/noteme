namespace GNotes {

    // Persists notes to ~/.local/share/gnotes/notes/
    public class NoteStore : Object {
        private string notes_dir;
        private ListStore _store;

        public ListStore store { get { return _store; } }

        public NoteStore () {
            notes_dir = Path.build_filename (
                Environment.get_user_data_dir (), "gnotes", "notes"
            );
            DirUtils.create_with_parents (notes_dir, 0755);
            _store = new ListStore (typeof (Note));
            load_all ();
        }

        private string note_path (Note note) {
            return Path.build_filename (notes_dir, note.created_at.replace (":", "-") + ".note");
        }

        private void load_all () {
            try {
                var dir = Dir.open (notes_dir);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    if (!name.has_suffix (".note")) continue;
                    var path = Path.build_filename (notes_dir, name);
                    string contents;
                    FileUtils.get_contents (path, out contents);
                    var note = Note.from_string (contents);
                    if (note != null) _store.append (note);
                }
            } catch (Error e) {
                warning ("Could not load notes: %s", e.message);
            }
        }

        public void save (Note note) {
            try {
                FileUtils.set_contents (note_path (note), note.to_string ());
            } catch (Error e) {
                warning ("Could not save note: %s", e.message);
            }
        }

        public void delete_note (Note note) {
            try {
                FileUtils.unlink (note_path (note));
            } catch (Error e) {
                warning ("Could not delete note file: %s", e.message);
            }
            uint pos;
            if (_store.find (note, out pos))
                _store.remove (pos);
        }

        public Note create_note () {
            var note = new Note ("Untitled", "");
            _store.insert (0, note);
            save (note);
            return note;
        }
    }
}
