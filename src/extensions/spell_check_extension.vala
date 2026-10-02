namespace NoteMe {

    public class SpellCheckExtension : Object, IExtension {
        public string id          { get { return "spell-check"; } }
        public string name        { get { return _("Spell Checker"); } }
        public string description { get { return _("Underlines misspelled words. Right-click a word to see suggestions."); } }

        private const int MAX_SUGGESTIONS = 5;
        private const int CHECK_DELAY_MS  = 400;

        private ExtensionHost?        host;
        private Gtk.TextView?         view;
        private Gtk.TextTag?          error_tag;
        private Gtk.DropDown?         lang_dropdown;
        private Gtk.GestureClick?     click;
        private SimpleActionGroup?    actions;
        private GLib.Menu?            spell_menu;
        private GLib.MenuModel?       previous_menu;

        private Enchant.Broker?       broker;
        private unowned Enchant.Dict? dict;
        private string[]              languages = {};

        // Word the context menu currently refers to
        private Gtk.TextMark?         word_start;
        private Gtk.TextMark?         word_end;

        private uint                  check_source  = 0;
        private ulong                 changed_id    = 0;
        private ulong                 cursor_id     = 0;

        public void activate (ExtensionHost h) {
            host = h;
            view = h.getTextView ();
            if (view == null) return;

            broker    = new Enchant.Broker ();
            languages = listLanguages ();

            var buffer = view.buffer;
            error_tag = new Gtk.TextTag ("spell-error");
            error_tag.underline = Pango.Underline.ERROR;
            buffer.tag_table.add (error_tag);

            Gtk.TextIter start;
            buffer.get_start_iter (out start);
            word_start = buffer.create_mark (null, start, true);
            word_end   = buffer.create_mark (null, start, false);

            setupActions ();
            setupLanguageSelector ();

            spell_menu    = new GLib.Menu ();
            previous_menu = view.extra_menu;

            click = new Gtk.GestureClick ();
            click.button = Gdk.BUTTON_SECONDARY;
            click.propagation_phase = Gtk.PropagationPhase.CAPTURE;
            click.pressed.connect (onRightClick);
            h.addTextViewController (click);

            changed_id = buffer.changed.connect (scheduleCheck);
            cursor_id  = buffer.notify["cursor-position"].connect (onCursorMoved);
            h.note_selected.connect (onNoteSelected);

            var lang = loadLanguage ();
            setLanguage (lang != null && lang in languages ? lang : defaultLanguage ());
        }

        public void deactivate () {
            if (check_source != 0) {
                Source.remove (check_source);
                check_source = 0;
            }
            if (host != null) {
                host.note_selected.disconnect (onNoteSelected);
                if (click != null)         host.removeTextViewController (click);
                if (lang_dropdown != null) host.removeFooterWidget (lang_dropdown);
            }
            if (view != null) {
                var buffer = view.buffer;
                if (changed_id != 0) buffer.disconnect (changed_id);
                if (cursor_id != 0)  buffer.disconnect (cursor_id);
                if (word_start != null) buffer.delete_mark (word_start);
                if (word_end != null)   buffer.delete_mark (word_end);
                if (error_tag != null)  buffer.tag_table.remove (error_tag);
                view.extra_menu = previous_menu;
                view.insert_action_group ("spell", null);
            }
            if (dict != null) broker.free_dict (dict);

            changed_id    = 0;
            cursor_id     = 0;
            word_start    = null;
            word_end      = null;
            error_tag     = null;
            click         = null;
            lang_dropdown = null;
            actions       = null;
            spell_menu    = null;
            previous_menu = null;
            dict          = null;
            broker        = null;
            view          = null;
            host          = null;
        }

        // Language selection

        private string[] listLanguages () {
            var found = new GenericArray<string> ();
            broker.list_dicts ((lang_tag, provider_name, provider_desc, provider_file) => {
                if (!found.find_with_equal_func (lang_tag, str_equal))
                    found.add (lang_tag);
            });
            found.sort (strcmp);
            return found.data;
        }

        private string? defaultLanguage () {
            // e.g. "es_ES.UTF-8" -> "es_ES", then "es"
            foreach (var name in Intl.get_language_names ()) {
                var tag = name.split (".")[0].split ("@")[0];
                if (tag != "C" && tag != "POSIX" && tag in languages) return tag;
            }
            if ("en_US" in languages) return "en_US";
            return languages.length > 0 ? languages[0] : null;
        }

        private void setupLanguageSelector () {
            lang_dropdown = new Gtk.DropDown.from_strings (languages);
            lang_dropdown.enable_search  = true;
            lang_dropdown.expression     = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");
            lang_dropdown.tooltip_text   = _("Spell checking language");
            lang_dropdown.sensitive      = languages.length > 0;
            lang_dropdown.add_css_class ("flat");
            lang_dropdown.notify["selected"].connect (() => {
                var item = lang_dropdown.selected_item as Gtk.StringObject;
                if (item != null) {
                    setLanguage (item.string);
                    saveLanguage (item.string);
                }
            });
            host.addFooterWidget (lang_dropdown);
        }

        private void setLanguage (string? lang) {
            if (lang == null || !(lang in languages)) {
                if (dict != null) broker.free_dict (dict);
                dict = null;
                clearErrors ();
                return;
            }

            // Keep the selector in sync when the language is set programmatically
            for (uint i = 0; i < languages.length; i++) {
                if (languages[i] == lang && lang_dropdown.selected != i) {
                    lang_dropdown.selected = i;  // re-enters through notify["selected"]
                    return;
                }
            }

            unowned Enchant.Dict? new_dict = broker.request_dict (lang);
            if (new_dict == null) {
                warning ("Could not load spelling dictionary %s: %s", lang, broker.get_error ());
                return;
            }
            if (dict != null && dict != new_dict) broker.free_dict (dict);
            dict = new_dict;
            checkAll (false);
        }

        private string settingsPath () {
            return Path.build_filename (Environment.get_user_config_dir (), "noteme", "spell-check");
        }

        private string? loadLanguage () {
            var kf = new KeyFile ();
            try {
                kf.load_from_file (settingsPath (), KeyFileFlags.NONE);
                return kf.get_string ("Spell", "language");
            } catch {
                return null;
            }
        }

        private void saveLanguage (string lang) {
            var kf = new KeyFile ();
            kf.set_string ("Spell", "language", lang);
            try {
                kf.save_to_file (settingsPath ());
            } catch (Error e) {
                warning ("Could not save spell checker settings: %s", e.message);
            }
        }

        // Checking

        private void onNoteSelected (Note? note) {
            // The editor content is replaced right after the selection changes
            scheduleCheck ();
        }

        private void onCursorMoved () {
            // Re-check once the cursor leaves the word being typed
            if (check_source == 0) scheduleCheck ();
        }

        private void scheduleCheck () {
            if (check_source != 0) Source.remove (check_source);
            check_source = Timeout.add (CHECK_DELAY_MS, () => {
                check_source = 0;
                checkAll (true);
                return Source.REMOVE;
            });
        }

        private void clearErrors () {
            if (view == null || error_tag == null) return;
            Gtk.TextIter start, end;
            view.buffer.get_bounds (out start, out end);
            view.buffer.remove_tag (error_tag, start, end);
        }

        // skip_cursor_word avoids flagging the word that is still being typed
        private void checkAll (bool skip_cursor_word) {
            clearErrors ();
            if (dict == null || view == null) return;

            var buffer   = view.buffer;
            var code_tag = buffer.tag_table.lookup ("code");
            Gtk.TextIter cursor, start, end;
            buffer.get_iter_at_mark (out cursor, buffer.get_insert ());
            buffer.get_bounds (out start, out end);

            var iter = start;
            while (iter.forward_word_end ()) {
                var ws = iter;
                ws.backward_word_start ();
                if (code_tag != null && ws.has_tag (code_tag)) continue;
                if (skip_cursor_word && cursor.in_range (ws, iter)) continue;
                if (skip_cursor_word && cursor.equal (iter))        continue;
                if (isMisspelled (buffer.get_text (ws, iter, false)))
                    buffer.apply_tag (error_tag, ws, iter);
            }
        }

        private bool isMisspelled (string word) {
            if (word.char_count () < 2) return false;
            // Skip numbers and identifiers such as "v2" or "mp3"
            for (int i = 0; i < word.length; ) {
                unichar c = word.get_char (i);
                if (c.isdigit ()) return false;
                i += (int) c.to_utf8 (null);
            }
            return dict.check (word) > 0;
        }

        // Context menu

        private void setupActions () {
            actions = new SimpleActionGroup ();

            var replace = new SimpleAction ("replace", VariantType.STRING);
            replace.activate.connect ((a, param) => replaceWord (param.get_string ()));
            actions.add_action (replace);

            var add = new SimpleAction ("add", null);
            add.activate.connect (() => {
                var word = targetWord ();
                if (word != null && dict != null) dict.add (word);
                checkAll (false);
            });
            actions.add_action (add);

            var ignore = new SimpleAction ("ignore", null);
            ignore.activate.connect (() => {
                var word = targetWord ();
                if (word != null && dict != null) dict.add_to_session (word);
                checkAll (false);
            });
            actions.add_action (ignore);

            view.insert_action_group ("spell", actions);
        }

        private void onRightClick (int n_press, double x, double y) {
            int bx, by;
            view.window_to_buffer_coords (Gtk.TextWindowType.WIDGET, (int) x, (int) y, out bx, out by);
            Gtk.TextIter iter;
            view.get_iter_at_location (out iter, bx, by);
            updateMenu (iter);
        }

        private void updateMenu (Gtk.TextIter iter) {
            spell_menu.remove_all ();
            view.extra_menu = previous_menu;
            if (dict == null || !iter.has_tag (error_tag)) return;

            var ws = iter;
            var we = iter;
            if (!ws.starts_tag (error_tag)) ws.backward_to_tag_toggle (error_tag);
            if (!we.ends_tag (error_tag))   we.forward_to_tag_toggle (error_tag);
            view.buffer.move_mark (word_start, ws);
            view.buffer.move_mark (word_end, we);

            var word        = view.buffer.get_text (ws, we, false);
            var suggestions = new GLib.Menu ();
            unowned string[] list = dict.suggest (word);
            for (int i = 0; i < list.length && i < MAX_SUGGESTIONS; i++) {
                var item = new GLib.MenuItem (list[i], null);
                item.set_action_and_target_value ("spell.replace", new Variant.string (list[i]));
                suggestions.append_item (item);
            }
            if (list.length > 0) dict.free_string_list (list);
            if (suggestions.get_n_items () == 0)
                suggestions.append (_("No Suggestions"), "spell.none");

            var word_actions = new GLib.Menu ();
            word_actions.append (_("Add to Dictionary"), "spell.add");
            word_actions.append (_("Ignore All"),        "spell.ignore");

            spell_menu.append_section (null, suggestions);
            spell_menu.append_section (null, word_actions);
            if (previous_menu != null) spell_menu.append_section (null, previous_menu);
            view.extra_menu = spell_menu;
        }

        private string? targetWord () {
            if (view == null) return null;
            Gtk.TextIter ws, we;
            view.buffer.get_iter_at_mark (out ws, word_start);
            view.buffer.get_iter_at_mark (out we, word_end);
            var word = view.buffer.get_text (ws, we, false);
            return word.length > 0 ? word : null;
        }

        private void replaceWord (string replacement) {
            var buffer = view.buffer;
            var word   = targetWord ();
            if (word == null) return;
            Gtk.TextIter ws, we;
            buffer.get_iter_at_mark (out ws, word_start);
            buffer.get_iter_at_mark (out we, word_end);

            buffer.begin_user_action ();
            buffer.delete (ref ws, ref we);
            buffer.insert (ref ws, replacement, -1);
            buffer.end_user_action ();

            dict.store_replacement (word, replacement);
        }
    }
}
