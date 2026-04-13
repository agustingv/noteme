namespace NoteMe {

    // Persists notes to ~/.local/share/gnotes/notes/
    public class NoteStore : Object {
        private string notes_dir;
        private ListStore _store;

        public ListStore store { get { return _store; } }

        public NoteStore () {
            notes_dir = Path.build_filename (
                Environment.get_user_data_dir (), "noteme", "notes"
            );
            DirUtils.create_with_parents (notes_dir, 0755);
            _store = new ListStore (typeof (Note));
            loadAll ();
        }

        private string notePath (Note note) {
            return Path.build_filename (notes_dir, note.created_at.replace (":", "-") + ".note");
        }

        private void loadAll () {
            var notes = new GenericArray<Note> ();
            try {
                var dir = Dir.open (notes_dir);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    if (!name.has_suffix (".note")) continue;
                    var path = Path.build_filename (notes_dir, name);
                    string contents;
                    FileUtils.get_contents (path, out contents);
                    var note = Note.from_string (contents);
                    if (note != null) notes.add (note);
                }
            } catch (Error e) {
                warning ("Could not load notes: %s", e.message);
            }

            notes.sort ((a, b) => {
                if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                return strcmp (b.updated_at, a.updated_at);
            });
            foreach (var note in notes)
                _store.append (note);
        }

        public void save (Note note) {
            note.updated_at = new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S");
            try {
                FileUtils.set_contents (notePath (note), note.to_string ());
            } catch (Error e) {
                warning ("Could not save note: %s", e.message);
            }
        }

        public void deleteNote (Note note) {
            if (FileUtils.unlink (notePath (note)) != 0)
                warning ("Could not delete note file: %s", notePath (note));
            uint pos;
            if (_store.find (note, out pos))
                _store.remove (pos);
        }

        public Note createNote () {
            var note = new Note ("Untitled", "");
            _store.insert (0, note);
            save (note);
            return note;
        }
    }
}
