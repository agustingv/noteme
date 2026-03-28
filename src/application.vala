namespace GNotes {

    public class Application : Gtk.Application {

        public Application () {
            Object (
                application_id: "com.github.gnotes",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void activate () {
            var win = this.active_window;
            if (win == null) {
                win = new GNotes.MainWindow (this);
            }
            win.present ();
        }
    }
}
