namespace NoteMe {

    public class Note : Object {
        public string title  { get; set; default = ""; }
        public string body   { get; set; default = ""; }
        public string color  { get; set; default = ""; }
        public bool   pinned { get; set; default = false; }
        public string created_at { get; construct; }

        public Note (string title = "", string body = "") {
            Object (created_at: new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S"));
            this.title = title;
            this.body  = body;
        }

        private Note.restore (string created_at, string title, string body, string color, bool pinned) {
            Object (created_at: created_at);
            this.title  = title;
            this.body   = body;
            this.color  = color;
            this.pinned = pinned;
        }

        // Serialise to a simple key=value block separated by blank lines.
        public string to_string () {
            return "title=%s\nbody=%s\ncreated_at=%s\ncolor=%s\npinned=%s".printf (
                title.replace ("\n", "\\n"),
                body.replace  ("\n", "\\n"),
                created_at,
                color,
                pinned.to_string ()
            );
        }

        public static Note? from_string (string data) {
            string title      = "";
            string body       = "";
            string color      = "";
            bool   pinned     = false;
            string created_at = new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S");

            string[] lines = data.split ("\n");
            for (int i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.has_prefix ("title="))
                    title = line.substring (6).replace ("\\n", "\n");
                else if (line.has_prefix ("body="))
                    body = line.substring (5).replace ("\\n", "\n");
                else if (line.has_prefix ("color="))
                    color = line.substring (6);
                else if (line.has_prefix ("created_at="))
                    created_at = line.substring (11);
                else if (line.has_prefix ("pinned="))
                    pinned = line.substring (7) == "true";
            }

            return new Note.restore (created_at, title, body, color, pinned);
        }
    }
}
