namespace NoteMe {

    [GtkTemplate (ui = "/io/github/agustingv/noteme/ui/main-window.ui")]
    public class MainWindow : Adw.ApplicationWindow {

        [GtkChild] unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] unowned Gtk.ListBox      notes_list;
        [GtkChild] unowned RichEditor       rich_editor;
        [GtkChild] unowned Gtk.Entry        title_entry;
        [GtkChild] unowned Gtk.Stack        content_stack;
        [GtkChild] unowned Gtk.Button       delete_button;
        [GtkChild] unowned Gtk.MenuButton   color_button;
        [GtkChild] unowned Gtk.SearchEntry  search_entry;

        private NoteStore           store;
        private Note?               current_note = null;
        private bool                updating     = false;
        private bool                resorting    = false;
        private ExtensionHost       host;
        private Gtk.CustomSorter    sorter;
        private Gtk.SortListModel   sort_model;

        public Preferences       prefs       { get; construct; }
        public ExtensionManager  ext_manager { get; construct; }

        public MainWindow (Gtk.Application app, Preferences prefs, ExtensionManager ext_manager) {
            Object (application: app, prefs: prefs, ext_manager: ext_manager);
        }

        construct {
            store = new NoteStore ();

            var custom_filter = new Gtk.CustomFilter ((obj) => {
                var query = search_entry.text.strip ().down ();
                if (query == "") return true;
                return ((Note) obj).title.down ().contains (query);
            });
            var filter_model = new Gtk.FilterListModel (store.store, custom_filter);

            sorter = new Gtk.CustomSorter ((a, b) => {
                var na = (Note) a;
                var nb = (Note) b;
                if (na.pinned != nb.pinned) return na.pinned ? -1 : 1;
                return strcmp (nb.updated_at, na.updated_at);
            });
            sort_model = new Gtk.SortListModel (filter_model, sorter);

            notes_list.bind_model (sort_model, (obj) => {
                var note_row = new NoteRow ((Note) obj);
                note_row.pin_toggled.connect ((note) => {
                    note.pinned = !note.pinned;
                    store.save (note);
                    sorter.changed (Gtk.SorterChange.DIFFERENT);
                });
                return note_row;
            });

            notes_list.row_selected.connect (on_row_selected);
            title_entry.changed.connect (on_title_changed);
            rich_editor.changed.connect (on_body_changed);

            search_entry.search_changed.connect (() => custom_filter.changed (Gtk.FilterChange.DIFFERENT));

            setup_color_picker ();
            update_empty_state ();
            apply_font_settings ();
            rich_editor.image_display_width = prefs.image_display_width;

            host        = new ExtensionHost ();
            host.editor = rich_editor;
            rich_editor.changed.connect (() => {
                if (!updating) host.note_content_changed ();
            });
            host.toast_requested.connect ((msg) => {
                toast_overlay.add_toast (new Adw.Toast (msg));
            });
            ext_manager.activate_all (host);

            var first = notes_list.get_row_at_index (0);
            if (first != null) notes_list.select_row (first);
        }

        public void apply_font_settings () {
            rich_editor.set_font_desc (prefs.editor_font_desc ?? "Sans 12");
        }

        public void apply_image_settings () {
            rich_editor.image_display_width = prefs.image_display_width;
            // Reload the current note so existing embedded images resize immediately
            if (current_note != null) {
                updating = true;
                rich_editor.set_markup (current_note.body);
                updating = false;
            }
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
            var note = store.create_note ();
            for (uint i = 0; i < sort_model.get_n_items (); i++) {
                if (sort_model.get_item (i) == note) {
                    notes_list.select_row (notes_list.get_row_at_index ((int) i));
                    break;
                }
            }
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
            if (resorting) return;
            if (row == null) {
                current_note     = null;
                host.current_note = null;
                host.note_selected (null);
                update_empty_state ();
                return;
            }
            var note = ((NoteRow) row.child).note;
            if (note == current_note) return;
            current_note      = note;
            host.current_note  = current_note;
            host.note_selected (current_note);
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
            resort_and_reselect ();
        }

        private void on_body_changed () {
            if (updating || current_note == null) return;
            current_note.body = rich_editor.get_markup ();
            store.save (current_note);
            resort_and_reselect ();
        }

        private void resort_and_reselect () {
            var note   = current_note;
            resorting  = true;
            sorter.changed (Gtk.SorterChange.DIFFERENT);
            resorting  = false;
            for (uint i = 0; i < sort_model.get_n_items (); i++) {
                if (sort_model.get_item (i) == note) {
                    notes_list.select_row (notes_list.get_row_at_index ((int) i));
                    return;
                }
            }
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
