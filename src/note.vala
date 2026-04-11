namespace NoteMe 
{

    public class Note : Object 
    {
        public string id         { get; construct; }
        public string title      { get; set; default = ""; }
        public string body       { get; set; default = ""; }
        public string color      { get; set; default = ""; }
        public bool   pinned     { get; set; default = false; }
        public string created_at { get; construct; }
        public string updated_at { get; set; }

        public Note (string title = "", string body = "")
        {
            string now = new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S");
            Object (id: GLib.Uuid.string_random (), created_at: now);
            this.updated_at = now;
            this.title = title;
            this.body  = body;
        }

        private Note.restore (string id, string created_at, string updated_at, string title, string body, string color, bool pinned)
        {
            Object (id: id, created_at: created_at);
            this.updated_at = updated_at;
            this.title  = title;
            this.body   = body;
            this.color  = color;
            this.pinned = pinned;
        }

        // Serialise to a simple key=value block separated by blank lines.
        public string to_string ()
        {
            return "id=%s\ntitle=%s\nbody=%s\ncreated_at=%s\nupdated_at=%s\ncolor=%s\npinned=%s".printf (
                id,
                title.replace ("\n", "\\n"),
                body.replace  ("\n", "\\n"),
                created_at,
                updated_at,
                color,
                pinned.to_string ()
            );
        }

        public static Note? from_string (string data)
        {
            string id         = GLib.Uuid.string_random ();
            string title      = "";
            string body       = "";
            string color      = "";
            bool   pinned     = false;
            string now        = new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S");
            string created_at = now;
            string updated_at = now;

            string[] lines = data.split ("\n");
            for (int i = 0; i < lines.length; i++)
            {
                var line = lines[i];
                if (line.has_prefix ("id="))
                    id = line.substring (3);
                else if (line.has_prefix ("title="))
                    title = line.substring (6).replace ("\\n", "\n");
                else if (line.has_prefix ("body="))
                    body = line.substring (5).replace ("\\n", "\n");
                else if (line.has_prefix ("color="))
                    color = line.substring (6);
                else if (line.has_prefix ("created_at="))
                    created_at = line.substring (11);
                else if (line.has_prefix ("updated_at="))
                    updated_at = line.substring (11);
                else if (line.has_prefix ("pinned="))
                    pinned = line.substring (7) == "true";
            }

            return new Note.restore (id, created_at, updated_at, title, body, color, pinned);
        }
    }
}
