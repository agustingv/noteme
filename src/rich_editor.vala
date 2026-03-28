namespace NoteMe {

    [GtkTemplate (ui = "/com/github/agustingv/noteme/ui/rich-editor.ui")]
    public class RichEditor : Gtk.Box {

        [GtkChild] unowned Gtk.ToggleButton bold_button;
        [GtkChild] unowned Gtk.ToggleButton italic_button;
        [GtkChild] unowned Gtk.ToggleButton underline_button;
        [GtkChild] unowned Gtk.ToggleButton code_button;
        [GtkChild] unowned Gtk.ToggleButton list_button;
        [GtkChild] unowned Gtk.TextView     text_view;

        private Gtk.TextTag    tag_bold;
        private Gtk.TextTag    tag_italic;
        private Gtk.TextTag    tag_underline;
        private Gtk.TextTag    tag_code;
        private Gtk.CssProvider font_provider;
        private bool            updating = false;

        public signal void changed ();

        construct {
            var buffer = text_view.buffer;

            tag_bold = new Gtk.TextTag ("bold");
            tag_bold.weight = Pango.Weight.BOLD;
            buffer.tag_table.add (tag_bold);

            tag_italic = new Gtk.TextTag ("italic");
            tag_italic.style = Pango.Style.ITALIC;
            buffer.tag_table.add (tag_italic);

            tag_underline = new Gtk.TextTag ("underline");
            tag_underline.underline = Pango.Underline.SINGLE;
            buffer.tag_table.add (tag_underline);

            tag_code = new Gtk.TextTag ("code");
            tag_code.family          = "Monospace";
            tag_code.background      = "rgba(128,128,128,0.15)";
            tag_code.paragraph_background = "rgba(128,128,128,0.08)";
            buffer.tag_table.add (tag_code);

            // Font provider — registered once, CSS updated via set_font_desc()
            font_provider = new Gtk.CssProvider ();
            text_view.add_css_class ("noteme-editor");
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                font_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            buffer.changed.connect    (() => { if (!updating) changed (); });
            buffer.apply_tag.connect  ((_t, _s, _e) => { if (!updating) changed (); });
            buffer.remove_tag.connect ((_t, _s, _e) => { if (!updating) changed (); });
            buffer.notify["cursor-position"].connect (() => update_toolbar_state ());

            // Keyboard shortcuts scoped to the text view
            var ctrl = new Gtk.ShortcutController ();
            ctrl.add_shortcut (new Gtk.Shortcut (
                new Gtk.KeyvalTrigger (Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK),
                new Gtk.CallbackAction ((_w, _a) => { bold_button.active = !bold_button.active; return true; })
            ));
            ctrl.add_shortcut (new Gtk.Shortcut (
                new Gtk.KeyvalTrigger (Gdk.Key.i, Gdk.ModifierType.CONTROL_MASK),
                new Gtk.CallbackAction ((_w, _a) => { italic_button.active = !italic_button.active; return true; })
            ));
            ctrl.add_shortcut (new Gtk.Shortcut (
                new Gtk.KeyvalTrigger (Gdk.Key.u, Gdk.ModifierType.CONTROL_MASK),
                new Gtk.CallbackAction ((_w, _a) => { underline_button.active = !underline_button.active; return true; })
            ));
            ctrl.add_shortcut (new Gtk.Shortcut (
                new Gtk.KeyvalTrigger (Gdk.Key.grave, Gdk.ModifierType.CONTROL_MASK),
                new Gtk.CallbackAction ((_w, _a) => { code_button.active = !code_button.active; return true; })
            ));
            ctrl.add_shortcut (new Gtk.Shortcut (
                new Gtk.KeyvalTrigger (Gdk.Key.l,
                    Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK),
                new Gtk.CallbackAction ((_w, _a) => { list_button.active = !list_button.active; return true; })
            ));
            text_view.add_controller (ctrl);

            // Enter key: continue list on the next line
            var key_ctrl = new Gtk.EventControllerKey ();
            key_ctrl.key_pressed.connect (on_key_pressed);
            text_view.add_controller (key_ctrl);
        }

        private void update_toolbar_state () {
            Gtk.TextIter cursor;
            text_view.buffer.get_iter_at_mark (out cursor, text_view.buffer.get_insert ());
            updating = true;
            bold_button.active      = cursor.has_tag (tag_bold);
            italic_button.active    = cursor.has_tag (tag_italic);
            underline_button.active = cursor.has_tag (tag_underline);
            code_button.active      = cursor.has_tag (tag_code);
            var ls = cursor;
            ls.set_line_offset (0);
            list_button.active = line_has_bullet (ls);
            updating = false;
        }

        [GtkCallback]
        private void on_bold_toggled () {
            if (!updating) apply_tag (tag_bold, bold_button.active);
        }

        [GtkCallback]
        private void on_italic_toggled () {
            if (!updating) apply_tag (tag_italic, italic_button.active);
        }

        [GtkCallback]
        private void on_underline_toggled () {
            if (!updating) apply_tag (tag_underline, underline_button.active);
        }

        [GtkCallback]
        private void on_code_toggled () {
            if (!updating) apply_tag (tag_code, code_button.active);
        }

        [GtkCallback]
        private void on_list_toggled () {
            if (updating) return;
            var buffer = text_view.buffer;

            Gtk.TextIter sel_start, sel_end;
            bool has_sel = buffer.get_selection_bounds (out sel_start, out sel_end);
            if (!has_sel) {
                buffer.get_iter_at_mark (out sel_start, buffer.get_insert ());
                sel_end = sel_start;
            }

            int first_line = sel_start.get_line ();
            int last_line  = sel_end.get_line ();
            // Exclude the next line when selection ends at column 0
            if (sel_end.get_line_offset () == 0 && last_line > first_line)
                last_line--;

            // Check if every line in the range already has a bullet
            bool all_bulleted = true;
            for (int l = first_line; l <= last_line && all_bulleted; l++) {
                Gtk.TextIter li;
                buffer.get_iter_at_line (out li, l);
                if (!line_has_bullet (li)) all_bulleted = false;
            }

            buffer.begin_user_action ();
            if (all_bulleted) {
                // Remove bullets — iterate in reverse so line numbers stay valid
                for (int l = last_line; l >= first_line; l--) {
                    Gtk.TextIter li, bullet_end;
                    buffer.get_iter_at_line (out li, l);
                    if (!line_has_bullet (li)) continue;
                    bullet_end = li;
                    bullet_end.forward_chars (2); // '•' + ' '
                    buffer.delete (ref li, ref bullet_end);
                }
            } else {
                for (int l = first_line; l <= last_line; l++) {
                    Gtk.TextIter li;
                    buffer.get_iter_at_line (out li, l);
                    if (!line_has_bullet (li))
                        buffer.insert (ref li, "• ", -1);
                }
            }
            buffer.end_user_action ();
            update_toolbar_state ();
        }

        // Returns true if the line beginning at `iter` starts with "• "
        private bool line_has_bullet (Gtk.TextIter iter) {
            if (iter.get_char () != '•') return false;
            var next = iter;
            next.forward_char ();
            return next.get_char () == ' ';
        }

        // Enter key handler: continue list or exit empty list item
        private bool on_key_pressed (uint keyval, uint _keycode, Gdk.ModifierType state) {
            if (keyval != Gdk.Key.Return && keyval != Gdk.Key.KP_Enter) return false;
            // Ignore if modifier keys are held (Shift+Enter etc.)
            if ((state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) != 0)
                return false;

            var buffer = text_view.buffer;
            Gtk.TextIter cursor;
            buffer.get_iter_at_mark (out cursor, buffer.get_insert ());

            Gtk.TextIter line_start = cursor;
            line_start.set_line_offset (0);
            if (!line_has_bullet (line_start)) return false;

            // If cursor is right after "• " (empty list item) → exit list
            var after_bullet = line_start;
            after_bullet.forward_chars (2);
            if (cursor.compare (after_bullet) <= 0) {
                // Delete the bullet and let GTK insert the newline normally
                buffer.begin_user_action ();
                buffer.delete (ref line_start, ref after_bullet);
                buffer.end_user_action ();
                return false;
            }

            // Otherwise continue the list on the next line
            buffer.begin_user_action ();
            buffer.insert_at_cursor ("\n• ", -1);
            buffer.end_user_action ();
            return true;
        }

        private void apply_tag (Gtk.TextTag tag, bool add) {
            var buffer = text_view.buffer;
            Gtk.TextIter start, end;
            if (!buffer.get_selection_bounds (out start, out end)) return;
            if (add)
                buffer.apply_tag (tag, start, end);
            else
                buffer.remove_tag (tag, start, end);
        }

        public new void grab_focus () {
            text_view.grab_focus ();
        }

        public void set_font_desc (string font_desc) {
            var desc    = Pango.FontDescription.from_string (font_desc);
            var family  = desc.get_family () ?? "Sans";
            int size_pt = desc.get_size () / Pango.SCALE;
            if (size_pt <= 0) size_pt = 12;
            font_provider.load_from_string (
                ".noteme-editor text { font-family: %s; font-size: %dpt; }".printf (family, size_pt)
            );
        }

        // ── Serialisation ─────────────────────────────────────────────────────

        public string get_markup () {
            var buffer = text_view.buffer;
            var sb = new StringBuilder ();
            Gtk.TextIter iter;
            buffer.get_start_iter (out iter);

            while (!iter.is_end ()) {
                foreach (unowned Gtk.TextTag tag in iter.get_toggled_tags (false))
                    sb.append (close_tag (tag.name));
                foreach (unowned Gtk.TextTag tag in iter.get_toggled_tags (true))
                    sb.append (open_tag (tag.name));
                append_escaped (sb, iter.get_char ());
                iter.forward_char ();
            }

            // Close any tags still open at the very end
            Gtk.TextIter end_iter;
            buffer.get_end_iter (out end_iter);
            foreach (unowned Gtk.TextTag tag in end_iter.get_toggled_tags (false))
                sb.append (close_tag (tag.name));

            return sb.str;
        }

        public void set_markup (string markup) {
            updating = true;
            parse_markup (markup);
            updating = false;
        }

        private string open_tag (string? name) {
            switch (name) {
                case "bold":      return "<b>";
                case "italic":    return "<i>";
                case "underline": return "<u>";
                case "code":      return "<code>";
                default:          return "";
            }
        }

        private string close_tag (string? name) {
            switch (name) {
                case "bold":      return "</b>";
                case "italic":    return "</i>";
                case "underline": return "</u>";
                case "code":      return "</code>";
                default:          return "";
            }
        }

        private void append_escaped (StringBuilder sb, unichar c) {
            switch (c) {
                case '<': sb.append ("&lt;");  break;
                case '>': sb.append ("&gt;");  break;
                case '&': sb.append ("&amp;"); break;
                default:  sb.append_unichar (c); break;
            }
        }

        // ── Deserialisation ───────────────────────────────────────────────────

        private void parse_markup (string markup) {
            var buffer = text_view.buffer;
            buffer.set_text ("", 0);

            // Collect plain text + (name, char_start, char_end) triples
            var plain    = new StringBuilder ();
            var t_names  = new GenericArray<string> ();
            var t_starts = new GenericArray<int> ();
            var t_ends   = new GenericArray<int> ();

            // stack: parallel arrays
            var s_names  = new GenericArray<string> ();
            var s_starts = new GenericArray<int> ();

            int bi = 0;          // byte index into markup
            int ci = 0;          // char offset in plain text

            while (bi < markup.length) {
                char b = markup[bi];

                if (b == '<') {
                    int close = markup.index_of (">", bi);
                    if (close < 0) break;
                    string tag_str = markup.substring (bi + 1, close - bi - 1);
                    bi = close + 1;

                    if (tag_str == "b" || tag_str == "i" || tag_str == "u" || tag_str == "code") {
                        string name = tag_str == "b" ? "bold" : tag_str == "i" ? "italic" :
                                      tag_str == "u" ? "underline" : "code";
                        s_names.add (name);
                        s_starts.add (ci);
                    } else if (s_names.length > 0) {
                        // closing tag — pop last opened
                        int last = (int) s_names.length - 1;
                        t_names.add (s_names[last]);
                        t_starts.add (s_starts[last]);
                        t_ends.add (ci);
                        s_names.remove_index (last);
                        s_starts.remove_index (last);
                    }

                } else if (b == '&') {
                    int semi = markup.index_of (";", bi);
                    if (semi >= 0) {
                        string entity = markup.substring (bi + 1, semi - bi - 1);
                        unichar ec = 0;
                        if      (entity == "lt")  ec = '<';
                        else if (entity == "gt")  ec = '>';
                        else if (entity == "amp") ec = '&';
                        if (ec != 0) { plain.append_unichar (ec); ci++; }
                        bi = semi + 1;
                    } else {
                        plain.append_c ('&'); ci++; bi++;
                    }

                } else {
                    unichar uc = markup.get_char (bi);
                    plain.append_unichar (uc);
                    ci++;
                    bi += uc.to_utf8 (null);
                }
            }

            buffer.set_text (plain.str, -1);

            for (int k = 0; k < t_names.length; k++) {
                Gtk.TextIter s, e;
                buffer.get_iter_at_offset (out s, t_starts[k]);
                buffer.get_iter_at_offset (out e, t_ends[k]);
                var tag = buffer.tag_table.lookup (t_names[k]);
                if (tag != null) buffer.apply_tag (tag, s, e);
            }
        }
    }
}
