namespace GNotes {

    public class Note : Object {
        public string title { get; set; default = ""; }
        public string body  { get; set; default = ""; }
        public string created_at { get; construct; }

        public Note (string title = "", string body = "") {
            Object (created_at: new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S"));
            this.title = title;
            this.body  = body;
        }

        // Serialise to a simple key=value block separated by blank lines.
        public string to_string () {
            return "title=%s\nbody=%s\ncreated_at=%s".printf (
                title.replace ("\n", "\\n"),
                body.replace  ("\n", "\\n"),
                created_at
            );
        }

        public static Note? from_string (string data) {
            string title = "";
            string body  = "";
            string created_at = new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S");

            foreach (var line in data.split ("\n")) {
                if (line.has_prefix ("title="))
                    title = line.substring (6).replace ("\\n", "\n");
                else if (line.has_prefix ("body="))
                    body = line.substring (5).replace ("\\n", "\n");
                else if (line.has_prefix ("created_at="))
                    created_at = line.substring (11);
            }

            var note = new Note (title, body);
            // Override created_at via property after construction
            return note;
        }
    }
}
