namespace NoteMe 
{

    [GtkTemplate (ui = "/io/github/agustingv/noteme/ui/rich-editor.ui")]
    public class RichEditor : Gtk.Box 
    {

        [GtkChild] unowned Gtk.ToggleButton  bold_button;
        [GtkChild] unowned Gtk.ToggleButton  italic_button;
        [GtkChild] unowned Gtk.ToggleButton  underline_button;
        [GtkChild] unowned Gtk.ToggleButton  code_button;
        [GtkChild] unowned Gtk.ToggleButton  list_button;
        [GtkChild] unowned Gtk.TextView      text_view;
        [GtkChild] unowned Gtk.Paned         preview_pane;
        [GtkChild] unowned Gtk.Label         position_label;
        [GtkChild] unowned Gtk.Box           extension_box;
        [GtkChild] unowned Gtk.Box           footer_extension_box;

        private Gtk.TextTag     tag_bold;
        private Gtk.TextTag     tag_italic;
        private Gtk.TextTag     tag_underline;
        private Gtk.TextTag     tag_code;
        private Gtk.CssProvider font_provider;
        private bool            updating = false;

        public int image_display_width { get; set; default = 320; }

        // Maps each in-buffer child anchor to its image source path
        private HashTable<Gtk.TextChildAnchor, string> anchor_images =
            new HashTable<Gtk.TextChildAnchor, string> (direct_hash, direct_equal);

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
            tag_code.family               = "Monospace";
            tag_code.background           = "rgba(128,128,128,0.15)";
            tag_code.paragraph_background = "rgba(128,128,128,0.08)";
            buffer.tag_table.add (tag_code);

            font_provider = new Gtk.CssProvider ();
            text_view.add_css_class ("noteme-editor");

            // it is deprecated since 4.10 versión and will be disapear en gtk 5, but I don't know other way to update the font when is change in settings
            // TODO: find a way to update the font without using deprecated API
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                font_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            buffer.changed.connect (() => {
                if (!updating) changed ();
            });
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

            int line = cursor.get_line () + 1;
            int col  = cursor.get_line_offset () + 1;
            position_label.label = "Ln %d, Col %d".printf (line, col);
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

        [GtkCallback]
        private void on_export_clicked () {
            var dialog = new Gtk.FileDialog ();
            dialog.title = _("Export Note");
            dialog.initial_name = "note.md";

            var md_filter = new Gtk.FileFilter ();
            md_filter.name = _("Markdown files");
            md_filter.add_suffix ("md");

            var txt_filter = new Gtk.FileFilter ();
            txt_filter.name = _("Text files");
            txt_filter.add_suffix ("txt");

            var all_filter = new Gtk.FileFilter ();
            all_filter.name = _("All files");
            all_filter.add_pattern ("*");

            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (md_filter);
            filters.append (txt_filter);
            filters.append (all_filter);
            dialog.filters = filters;
            dialog.default_filter = md_filter;

            var parent = get_ancestor (typeof (Gtk.Window)) as Gtk.Window;
            dialog.save.begin (parent, null, (obj, res) => {
                try {
                    var file = dialog.save.end (res);
                    string content = markup_to_markdown (get_markup ());
                    string? new_etag;
                    file.replace_contents (
                        content.data, null, false,
                        GLib.FileCreateFlags.REPLACE_DESTINATION,
                        out new_etag, null
                    );
                } catch (Error e) {
                    // User cancelled or I/O error — nothing to do
                }
            });
        }

        // Convert stored HTML-like markup to inline markdown for export and preview.
        public string markup_to_markdown (string markup) {
            var sb = new StringBuilder ();
            int i = 0;
            int len = markup.length;
            while (i < len) {
                if (markup[i] == '<') {
                    int close = markup.index_of (">", i);
                    if (close < 0) break;
                    string tag = markup.substring (i + 1, close - i - 1);
                    if (tag.has_prefix ("img ")) {
                        string? src = parse_img_src (tag);
                        sb.append ("![image](%s)".printf (src ?? ""));
                    } else switch (tag) {
                        case "b":     sb.append ("**"); break;
                        case "/b":    sb.append ("**"); break;
                        case "i":     sb.append ("*");  break;
                        case "/i":    sb.append ("*");  break;
                        case "u":     sb.append ("__"); break;
                        case "/u":    sb.append ("__"); break;
                        case "code":  sb.append ("`");  break;
                        case "/code": sb.append ("`");  break;
                    }
                    i = close + 1;
                } else if (markup[i] == '&') {
                    int semi = markup.index_of (";", i);
                    if (semi >= 0) {
                        string entity = markup.substring (i + 1, semi - i - 1);
                        if      (entity == "lt")  sb.append_c ('<');
                        else if (entity == "gt")  sb.append_c ('>');
                        else if (entity == "amp") sb.append_c ('&');
                        i = semi + 1;
                    } else {
                        sb.append_c ('&');
                        i++;
                    }
                } else {
                    unichar c = markup.get_char (i);
                    sb.append_unichar (c);
                    i += (int) c.to_utf8 (null);
                }
            }
            return sb.str;
        }

        // Returns true if the line beginning at `iter` starts with "• "
        private bool line_has_bullet (Gtk.TextIter iter) 
        {
            if (iter.get_char () != '•') return false;
            var next = iter;
            next.forward_char ();
            return next.get_char () == ' ';
        }

        // Enter key handler: continue list or exit empty list item
        private bool on_key_pressed (uint keyval, uint _keycode, Gdk.ModifierType state) 
        {
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
            if (cursor.compare (after_bullet) <= 0) 
            {
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

        private void apply_tag (Gtk.TextTag tag, bool add) 
        {
            var buffer = text_view.buffer;
            Gtk.TextIter start, end;
            if (!buffer.get_selection_bounds (out start, out end)) return;
            if (add)
                buffer.apply_tag (tag, start, end);
            else
                buffer.remove_tag (tag, start, end);
        }

        public void set_preview_widget (Gtk.Widget? widget)
        {
            preview_pane.end_child = widget;
        }

        public void center_preview_pane ()
        {
            int w = preview_pane.get_width ();
            preview_pane.set_position (w > 0 ? w / 2 : 400);
        }

        public void add_text_view_controller (Gtk.EventController controller)
        {
            text_view.add_controller (controller);
        }

        public void remove_text_view_controller (Gtk.EventController controller)
        {
            text_view.remove_controller (controller);
        }

        // Move the cursor to the given widget-relative coordinates (used for drop positioning)
        public void place_cursor_at_coords (double x, double y)
        {
            int bx, by;
            text_view.window_to_buffer_coords (Gtk.TextWindowType.WIDGET, (int) x, (int) y, out bx, out by);
            Gtk.TextIter iter;
            text_view.get_iter_at_location (out iter, bx, by);
            text_view.buffer.place_cursor (iter);
        }

        public void add_extension_widget (Gtk.Widget widget)
        {
            extension_box.append (widget);
        }

        public void remove_extension_widget (Gtk.Widget widget) 
        {
            extension_box.remove (widget);
        }

        // Insert an image at the current cursor position
        public void insert_image_at_cursor (string src_path) 
        {
            var buffer = text_view.buffer;
            Gtk.TextIter cursor;
            buffer.get_iter_at_mark (out cursor, buffer.get_insert ());
            var anchor = buffer.create_child_anchor (cursor);
            anchor_images.set (anchor, src_path);
            text_view.add_child_at_anchor (make_image_widget (src_path), anchor);
            if (!updating) changed ();
        }

        public void add_footer_extension_widget (Gtk.Widget widget) 
        {
            footer_extension_box.append (widget);
        }

        public void remove_footer_extension_widget (Gtk.Widget widget) 
        {
            footer_extension_box.remove (widget);
        }

        public new void grab_focus () 
        {
            text_view.grab_focus ();
        }

        public void set_font_desc (string font_desc) 
        {
            var desc    = Pango.FontDescription.from_string (font_desc);
            var family  = desc.get_family () ?? "Sans";
            int size    = desc.get_size ();
            if (size <= 0) size = 12 * Pango.SCALE;
            string size_css = desc.get_size_is_absolute ()
                ? "%dpx".printf (size / Pango.SCALE)
                : "%dpt".printf (size / Pango.SCALE);
            font_provider.load_from_string (
                "textview.noteme-editor { font-family: \"%s\"; font-size: %s; }".printf (family, size_css)
            );
        }

        // Serialisation

        public string get_markup () 
        {
            var buffer = text_view.buffer;
            var sb = new StringBuilder ();
            Gtk.TextIter iter;
            buffer.get_start_iter (out iter);

            while (!iter.is_end ()) 
            {
                var anchor = iter.get_child_anchor ();
                if (anchor != null) {
                    var src = anchor_images.get (anchor);
                    if (src != null)
                        sb.append ("<img src=\"%s\"/>".printf (GLib.Markup.escape_text (src)));
                    iter.forward_char ();
                    continue;
                }
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

        public void set_markup (string markup) 
        {
            updating = true;
            parse_markup (markup);
            updating = false;
        }

        private string open_tag (string? name) {
            switch (name) 
            {
                case "bold":      
                    return "<b>";
                case "italic":    
                    return "<i>";
                case "underline": 
                    return "<u>";
                case "code":      
                    return "<code>";
                default:          
                    return "";
            }
        }

        private string close_tag (string? name) 
        {
            switch (name) 
            {
                case "bold":      
                    return "</b>";
                case "italic":    
                    return "</i>";
                case "underline": 
                    return "</u>";
                case "code":      
                    return "</code>";
                default:          
                    return "";
            }
        }

        private void append_escaped (StringBuilder sb, unichar c) 
        {
            switch (c) 
            {
                case '<': 
                    sb.append ("&lt;");  break;
                case '>': 
                    sb.append ("&gt;");  break;
                case '&': 
                    sb.append ("&amp;"); break;
                default:  
                    sb.append_unichar (c); break;
            }
        }

        // Deserialisation
        private void parse_markup (string markup) 
        {
            var buffer = text_view.buffer;
            buffer.set_text ("", 0);
            anchor_images.remove_all ();

            // Tag open/close stack (parallel arrays)
            var s_names  = new GenericArray<string> ();
            var s_starts = new GenericArray<int> ();
            // Collected tag ranges to apply at the end
            var t_names  = new GenericArray<string> ();
            var t_starts = new GenericArray<int> ();
            var t_ends   = new GenericArray<int> ();

            int bi = 0;

            while (bi < markup.length) {
                char b = markup[bi];

                if (b == '<') 
                {
                    int close = markup.index_of (">", bi);
                    if (close < 0) break;
                    string tag_str = markup.substring (bi + 1, close - bi - 1);
                    bi = close + 1;

                    if (tag_str.has_prefix ("img ")) 
                    {
                        // Self-closing image tag: <img src="..."/>
                        string? src = parse_img_src (tag_str);
                        if (src != null) 
                        {
                            Gtk.TextIter end_it;
                            buffer.get_end_iter (out end_it);
                            var anchor = buffer.create_child_anchor (end_it);
                            anchor_images.set (anchor, src);
                            text_view.add_child_at_anchor (make_image_widget (src), anchor);
                        }
                    } 
                    else if (tag_str == "b" || tag_str == "i" || tag_str == "u" || tag_str == "code") 
                    {
                        Gtk.TextIter end_it;
                        buffer.get_end_iter (out end_it);
                        string name = tag_str == "b" ? "bold" : tag_str == "i" ? "italic" :
                                      tag_str == "u" ? "underline" : "code";
                        s_names.add (name);
                        s_starts.add (end_it.get_offset ());
                    } 
                    else if (s_names.length > 0) 
                    {
                        Gtk.TextIter end_it;
                        buffer.get_end_iter (out end_it);
                        int last = (int) s_names.length - 1;
                        t_names.add  (s_names[last]);
                        t_starts.add (s_starts[last]);
                        t_ends.add   (end_it.get_offset ());
                        s_names.remove_index  (last);
                        s_starts.remove_index (last);
                    }

                } 
                else 
                {
                    // Collect a plain-text chunk up to the next tag
                    var chunk = new StringBuilder ();
                    while (bi < markup.length && markup[bi] != '<') 
                    {
                        if (markup[bi] == '&') 
                        {
                            int semi = markup.index_of (";", bi);
                            if (semi >= 0) 
                            {
                                string entity = markup.substring (bi + 1, semi - bi - 1);
                                if      (entity == "lt")  chunk.append_c ('<');
                                else if (entity == "gt")  chunk.append_c ('>');
                                else if (entity == "amp") chunk.append_c ('&');
                                bi = semi + 1;
                            } 
                            else 
                            { 
                                chunk.append_c ('&'); bi++; 
                            }
                        }
                        else 
                        {
                            unichar c = markup.get_char (bi);
                            chunk.append_unichar (c);
                            bi += (int) c.to_utf8 (null);
                        }
                    }
                    if (chunk.len > 0) 
                    {
                        Gtk.TextIter end_it;
                        buffer.get_end_iter (out end_it);
                        buffer.insert (ref end_it, chunk.str, -1);
                    }
                }
            }

            // Apply all collected tag ranges
            for (int k = 0; k < t_names.length; k++) 
            {
                Gtk.TextIter s, e;
                buffer.get_iter_at_offset (out s, t_starts[k]);
                buffer.get_iter_at_offset (out e, t_ends[k]);
                var tag = buffer.tag_table.lookup (t_names[k]);
                if (tag != null) buffer.apply_tag (tag, s, e);
            }
        }

        private string? parse_img_src (string tag_str) 
        {
            int start = tag_str.index_of ("src=\"");
            if (start < 0) return null;
            start += 5;
            int end = tag_str.index_of ("\"", start);
            if (end < 0) return null;
            return tag_str.substring (start, end - start)
                          .replace ("&amp;",  "&")
                          .replace ("&lt;",   "<")
                          .replace ("&gt;",   ">")
                          .replace ("&quot;", "\"");
        }

        private Gtk.Widget make_image_widget (string path)
        {
            var picture = new Gtk.Picture.for_filename (path);
            picture.content_fit    = Gtk.ContentFit.SCALE_DOWN;
            picture.width_request  = image_display_width;
            picture.height_request = image_display_width * 3 / 4;
            picture.margin_top     = 4;
            picture.margin_bottom  = 4;
            picture.halign         = Gtk.Align.START;
            return picture;
        }
    }
}
