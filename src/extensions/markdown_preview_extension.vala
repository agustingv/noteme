namespace NoteMe
{
    public class MarkdownPreviewExtension : Object, IExtension
    {
        public string id          { get { return "markdown-preview"; } }
        public string name        { get { return _("Markdown Preview"); } }
        public string description { get { return _("Live markdown preview pane (Ctrl+Shift+P)"); } }

        private ExtensionHost?      host;
        private Gtk.ToggleButton?   button;
        private Gtk.ScrolledWindow? scroll;
        private Gtk.TextView?       view;

        private Gtk.TextTag? h1;
        private Gtk.TextTag? h2;
        private Gtk.TextTag? h3;
        private Gtk.TextTag? bold_tag;
        private Gtk.TextTag? italic_tag;
        private Gtk.TextTag? code_tag;
        private Gtk.TextTag? quote_tag;
        private Gtk.TextTag? underline_tag;

        public void activate (ExtensionHost h)
        {
            host = h;

            view = new Gtk.TextView ();
            view.editable           = false;
            view.cursor_visible     = false;
            view.wrap_mode          = Gtk.WrapMode.WORD_CHAR;
            view.pixels_above_lines = 4;
            view.pixels_below_lines = 4;
            view.left_margin        = 16;
            view.right_margin       = 16;
            view.top_margin         = 12;
            view.bottom_margin      = 12;

            scroll = new Gtk.ScrolledWindow ();
            scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroll.child             = view;
            scroll.visible           = false;

            setup_tags ();

            // Global shortcut so Ctrl+Shift+P works regardless of focus
            var ctrl = new Gtk.ShortcutController ();
            ctrl.scope = Gtk.ShortcutScope.GLOBAL;
            ctrl.add_shortcut (new Gtk.Shortcut (
                new Gtk.KeyvalTrigger (Gdk.Key.p,
                    Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK),
                new Gtk.CallbackAction ((_w, _a) => {
                    if (button != null) button.active = !button.active;
                    return true;
                })
            ));
            h.editor.add_controller (ctrl);

            button = new Gtk.ToggleButton ();
            button.label        = "MD";
            button.tooltip_text = _("Markdown Preview (Ctrl+Shift+P)");
            button.add_css_class ("flat");
            button.toggled.connect (on_preview_toggled);
            h.add_toolbar_widget (button);

            h.set_preview_widget (scroll);

            h.note_selected.connect (on_note_selected);
            h.note_content_changed.connect (on_content_changed);
        }

        public void deactivate ()
        {
            if (host != null) {
                host.note_selected.disconnect (on_note_selected);
                host.note_content_changed.disconnect (on_content_changed);
                host.remove_toolbar_widget (button);
                host.set_preview_widget (null);
                host = null;
            }
            button = null;
            scroll = null;
            view   = null;
        }

        private void setup_tags ()
        {
            var pb = view.buffer;

            h1        = new Gtk.TextTag (null);
            h1.weight = Pango.Weight.BOLD;
            h1.scale  = Pango.Scale.XX_LARGE;
            pb.tag_table.add (h1);

            h2        = new Gtk.TextTag (null);
            h2.weight = Pango.Weight.BOLD;
            h2.scale  = Pango.Scale.X_LARGE;
            pb.tag_table.add (h2);

            h3        = new Gtk.TextTag (null);
            h3.weight = Pango.Weight.BOLD;
            pb.tag_table.add (h3);

            bold_tag        = new Gtk.TextTag (null);
            bold_tag.weight = Pango.Weight.BOLD;
            pb.tag_table.add (bold_tag);

            italic_tag       = new Gtk.TextTag (null);
            italic_tag.style = Pango.Style.ITALIC;
            pb.tag_table.add (italic_tag);

            code_tag            = new Gtk.TextTag (null);
            code_tag.family     = "Monospace";
            code_tag.background = "rgba(128,128,128,0.15)";
            pb.tag_table.add (code_tag);

            quote_tag             = new Gtk.TextTag (null);
            quote_tag.foreground  = "gray";
            quote_tag.style       = Pango.Style.ITALIC;
            pb.tag_table.add (quote_tag);

            underline_tag           = new Gtk.TextTag (null);
            underline_tag.underline = Pango.Underline.SINGLE;
            pb.tag_table.add (underline_tag);
        }

        private void on_preview_toggled ()
        {
            if (scroll == null) return;
            scroll.visible = button.active;
            if (button.active) {
                // Defer position and render until after GTK re-lays out the pane
                GLib.Idle.add (() => {
                    host?.center_preview_pane ();
                    update_preview ();
                    return GLib.Source.REMOVE;
                });
            }
        }

        private void on_note_selected (Note? note)
        {
            if (button != null && button.active)
                update_preview ();
        }

        private void on_content_changed ()
        {
            if (button != null && button.active)
                update_preview ();
        }

        private void update_preview ()
        {
            if (host == null || view == null) return;
            string text = host.get_note_markdown ();
            var pb = view.buffer;
            pb.set_text ("", 0);
            string[] lines = text.split ("\n");
            for (int i = 0; i < lines.length; i++) {
                if (i > 0) {
                    Gtk.TextIter iter;
                    pb.get_end_iter (out iter);
                    pb.insert (ref iter, "\n", -1);
                }
                render_line (pb, lines[i]);
            }
        }

        private void render_line (Gtk.TextBuffer pb, string line)
        {
            if (line.has_prefix ("### ")) {
                render_tagged_line (pb, line.substring (4), h3);
            } else if (line.has_prefix ("## ")) {
                render_tagged_line (pb, line.substring (3), h2);
            } else if (line.has_prefix ("# ")) {
                render_tagged_line (pb, line.substring (2), h1);
            } else if (line.has_prefix ("- ") || line.has_prefix ("* ") || line.has_prefix ("• ")) {
                Gtk.TextIter iter;
                pb.get_end_iter (out iter);
                pb.insert (ref iter, "• ", -1);
                // "• " is 4 bytes (3-byte UTF-8 char + space); "-" and "*" prefixes are 2 bytes
                int skip = line.has_prefix ("• ") ? "• ".length : 2;
                render_inline (pb, line.substring (skip));
            } else if (line.has_prefix ("> ")) {
                int from = pb_end_offset (pb);
                render_inline (pb, line.substring (2));
                pb_apply_from (pb, quote_tag, from);
            } else if (line == "---" || line == "***" || line == "___") {
                Gtk.TextIter iter;
                pb.get_end_iter (out iter);
                pb.insert (ref iter, "────────────────────────────────", -1);
            } else {
                render_inline (pb, line);
            }
        }

        private void render_tagged_line (Gtk.TextBuffer pb, string text, Gtk.TextTag tag)
        {
            int from = pb_end_offset (pb);
            render_inline (pb, text);
            pb_apply_from (pb, tag, from);
        }

        private void render_inline (Gtk.TextBuffer pb, string text)
        {
            int i   = 0;
            int len = text.length;
            var plain = new StringBuilder ();

            while (i < len) {
                if (i + 1 < len && text[i] == '*' && text[i + 1] == '*') {
                    // **bold**
                    flush_plain (pb, plain);
                    int close = text.index_of ("**", i + 2);
                    if (close > i + 1) {
                        int from = pb_end_offset (pb);
                        Gtk.TextIter it; pb.get_end_iter (out it);
                        pb.insert (ref it, text.substring (i + 2, close - i - 2), -1);
                        pb_apply_from (pb, bold_tag, from);
                        i = close + 2;
                    } else { plain.append ("**"); i += 2; }
                } else if (text[i] == '*') {
                    // *italic*
                    flush_plain (pb, plain);
                    int close = text.index_of ("*", i + 1);
                    if (close > i) {
                        int from = pb_end_offset (pb);
                        Gtk.TextIter it; pb.get_end_iter (out it);
                        pb.insert (ref it, text.substring (i + 1, close - i - 1), -1);
                        pb_apply_from (pb, italic_tag, from);
                        i = close + 1;
                    } else { plain.append_c ('*'); i++; }
                } else if (i + 1 < len && text[i] == '_' && text[i + 1] == '_') {
                    // __underline__
                    flush_plain (pb, plain);
                    int close = text.index_of ("__", i + 2);
                    if (close > i + 1) {
                        int from = pb_end_offset (pb);
                        Gtk.TextIter it; pb.get_end_iter (out it);
                        pb.insert (ref it, text.substring (i + 2, close - i - 2), -1);
                        pb_apply_from (pb, underline_tag, from);
                        i = close + 2;
                    } else { plain.append ("__"); i += 2; }
                } else if (text[i] == '`') {
                    // `code`
                    flush_plain (pb, plain);
                    int close = text.index_of ("`", i + 1);
                    if (close > i) {
                        int from = pb_end_offset (pb);
                        Gtk.TextIter it; pb.get_end_iter (out it);
                        pb.insert (ref it, text.substring (i + 1, close - i - 1), -1);
                        pb_apply_from (pb, code_tag, from);
                        i = close + 1;
                    } else { plain.append_c ('`'); i++; }
                } else {
                    unichar c = text.get_char (i);
                    plain.append_unichar (c);
                    i += (int) c.to_utf8 (null);
                }
            }
            flush_plain (pb, plain);
        }

        private void flush_plain (Gtk.TextBuffer pb, StringBuilder plain)
        {
            if (plain.len == 0) return;
            Gtk.TextIter it;
            pb.get_end_iter (out it);
            pb.insert (ref it, plain.str, -1);
            plain.truncate (0);
        }

        private int pb_end_offset (Gtk.TextBuffer pb)
        {
            Gtk.TextIter it;
            pb.get_end_iter (out it);
            return it.get_offset ();
        }

        private void pb_apply_from (Gtk.TextBuffer pb, Gtk.TextTag tag, int from)
        {
            Gtk.TextIter s, e;
            pb.get_iter_at_offset (out s, from);
            pb.get_end_iter (out e);
            pb.apply_tag (tag, s, e);
        }
    }
}
