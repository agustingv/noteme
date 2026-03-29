namespace NoteMe {

    [GtkTemplate (ui = "/com/github/agustingv/noteme/ui/main-window.ui")]
    public class MainWindow : Adw.ApplicationWindow {

        [GtkChild] unowned Gtk.ListBox      notes_list;
        [GtkChild] unowned RichEditor       rich_editor;
        [GtkChild] unowned Gtk.Entry        title_entry;
        [GtkChild] unowned Gtk.Stack        content_stack;
        [GtkChild] unowned Gtk.Button       delete_button;
        [GtkChild] unowned Gtk.MenuButton   color_button;
        [GtkChild] unowned Gtk.SearchEntry  search_entry;

        private NoteStore store;
        private Note?     current_note = null;
        private bool      updating     = false;

        public Preferences prefs { get; construct; }

        public MainWindow (Gtk.Application app, Preferences prefs) {
            Object (application: app, prefs: prefs);
        }

        construct {
            store = new NoteStore ();

            var custom_filter = new Gtk.CustomFilter ((obj) => {
                var query = search_entry.text.strip ().down ();
                if (query == "") return true;
                return ((Note) obj).title.down ().contains (query);
            });
            var filter_model = new Gtk.FilterListModel (store.store, custom_filter);

            notes_list.bind_model (filter_model, (obj) => {
                return new NoteRow ((Note) obj);
            });

            notes_list.row_selected.connect (on_row_selected);
            title_entry.changed.connect (on_title_changed);
            rich_editor.changed.connect (on_body_changed);

            search_entry.search_changed.connect (() => custom_filter.changed (Gtk.FilterChange.DIFFERENT));

            setup_color_picker ();
            update_empty_state ();
            apply_font_settings ();

            var first = notes_list.get_row_at_index (0);
            if (first != null) notes_list.select_row (first);
        }

        public void apply_font_settings () {
            rich_editor.set_font_desc (prefs.editor_font_desc ?? "Sans 12");
        }


        private void setup_color_picker () {
            // Preset swatch colors (empty string = no color / default)
            string[] colors = {
                "", "#f28b82", "#fbbc04", "#fff475", "#ccff90",
                "#a8dab5", "#cbf0f8", "#aecbfa", "#d7aefb", "#fdcfe8"
            };
            string[] labels = {
                _("Default"), _("Red"), _("Yellow"), _("Lemon"), _("Sage"),
                _("Mint"), _("Fog"), _("Blue"), _("Purple"), _("Pink")
            };

            var flow = new Gtk.FlowBox ();
            flow.max_children_per_line = 5;
            flow.selection_mode = Gtk.SelectionMode.NONE;
            flow.row_spacing = 4;
            flow.column_spacing = 4;
            flow.margin_start = 8;
            flow.margin_end = 8;
            flow.margin_top = 8;
            flow.margin_bottom = 8;

            for (int k = 0; k < colors.length; k++) {
                var btn = new Gtk.Button ();
                btn.tooltip_text = labels[k];
                btn.add_css_class ("flat");

                // Draw the swatch circle with Cairo to avoid deprecated StyleContext API
                var da = new Gtk.DrawingArea ();
                da.width_request  = 24;
                da.height_request = 24;
                var swatch_color = colors[k];
                da.set_draw_func ((_da, cr, w, h) => {
                    double r = (w < h ? w : h) / 2.0 - 1.0;
                    cr.arc (w / 2.0, h / 2.0, r, 0, 2 * Math.PI);
                    if (swatch_color == "") {
                        cr.set_source_rgba (0.85, 0.85, 0.85, 1.0);
                    } else {
                        var rgba = Gdk.RGBA ();
                        rgba.parse (swatch_color);
                        cr.set_source_rgba (rgba.red, rgba.green, rgba.blue, rgba.alpha);
                    }
                    cr.fill_preserve ();
                    cr.set_source_rgba (0, 0, 0, 0.2);
                    cr.set_line_width (1.0);
                    cr.stroke ();
                });
                btn.child = da;

                var color = colors[k]; // capture
                btn.clicked.connect (() => {
                    if (current_note == null) return;
                    current_note.color = color;
                    store.save (current_note);
                    color_button.popdown ();
                });

                flow.append (btn);
            }

            var popover = new Gtk.Popover ();
            popover.child = flow;
            color_button.popover = popover;
        }

        [GtkCallback]
        private void on_new_note_clicked () {
            store.create_note ();
            // New note is inserted at position 0 (newest first)
            var row = notes_list.get_row_at_index (0);
            if (row != null) notes_list.select_row (row);
            title_entry.grab_focus ();
        }

        [GtkCallback]
        private void on_delete_clicked () {
            if (current_note == null) return;

            var dialog = new Adw.AlertDialog (
                _("Delete Note?"),
                _("%s will be permanently deleted.").printf (current_note.title)
            );
            dialog.add_response ("cancel", _("Cancel"));
            dialog.add_response ("delete", _("Delete"));
            dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.default_response = "cancel";
            dialog.choose.begin (this, null, (obj, res) => {
                if (dialog.choose.end (res) == "delete") {
                    var selected = notes_list.get_selected_row ();
                    int idx = selected != null ? selected.get_index () : 0;

                    store.delete_note (current_note);
                    current_note = null;

                    // Try next row at same index (shifted up after deletion),
                    // then fall back to the row above.
                    var next = notes_list.get_row_at_index (idx);
                    if (next == null && idx > 0)
                        next = notes_list.get_row_at_index (idx - 1);

                    if (next != null)
                        notes_list.select_row (next);
                    else
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
            color_button.sensitive  = true;
        }

        private void load_note (Note note) {
            updating = true;
            title_entry.text = note.title;
            rich_editor.set_markup (note.body);
            updating = false;
        }

        private void on_title_changed () {
            if (updating || current_note == null) return;
            current_note.title = title_entry.text;
            store.save (current_note);
        }

        private void on_body_changed () {
            if (updating || current_note == null) return;
            current_note.body = rich_editor.get_markup ();
            store.save (current_note);
        }

        private void update_empty_state () {
            if (store.store.get_n_items () == 0 || current_note == null) {
                content_stack.visible_child_name = "empty";
                delete_button.sensitive = false;
                color_button.sensitive  = false;
            }
        }
    }
}
