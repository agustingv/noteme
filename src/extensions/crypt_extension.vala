namespace NoteMe
{
    public class CryptExtension : Object, IExtension
    {
        public string id          { get { return "crypt"; } }
        public string name        { get { return _("Note Encryption"); } }
        public string description { get { return _("Encrypt and decrypt notes with a password (AES-256)"); } }

        private const string ENCRYPTED_PREFIX = "ENCRYPTED:";

        private ExtensionHost? host           = null;
        private Gtk.ToggleButton? lock_btn    = null;
        private ulong note_selected_id        = 0;
        private bool  updating_btn            = false;

        public void activate (ExtensionHost h)
        {
            host = h;

            lock_btn = new Gtk.ToggleButton ();
            lock_btn.icon_name   = "system-lock-screen-symbolic";
            lock_btn.tooltip_text = _("Encrypt / Decrypt Note");
            lock_btn.add_css_class ("flat");
            host.add_toolbar_widget (lock_btn);

            lock_btn.toggled.connect (on_btn_toggled);

            note_selected_id = host.note_selected.connect ((note) => {
                // load_note() runs after this signal, so defer state update
                GLib.Idle.add (() => {
                    apply_lock_state ();
                    return GLib.Source.REMOVE;
                });
            });

            apply_lock_state ();
        }

        public void deactivate ()
        {
            if (host != null && note_selected_id != 0) {
                host.disconnect (note_selected_id);
                note_selected_id = 0;
            }
            if (lock_btn != null) {
                host?.remove_toolbar_widget (lock_btn);
                lock_btn = null;
            }
            host?.set_editor_locked (false);
            host?.set_editor_editable (true);
            host = null;
        }

        // ── Helpers ──────────────────────────────────────────────────────────

        private bool note_is_encrypted ()
        {
            if (host == null || host.current_note == null) return false;
            return host.current_note.body.has_prefix (ENCRYPTED_PREFIX);
        }

        private void apply_lock_state ()
        {
            bool encrypted = note_is_encrypted ();
            set_btn_active (encrypted);
            host?.set_editor_locked (encrypted);
            host?.set_editor_editable (!encrypted);
        }

        private void set_btn_active (bool active)
        {
            updating_btn = true;
            if (lock_btn != null) lock_btn.active = active;
            updating_btn = false;
        }

        // ── Button toggled ───────────────────────────────────────────────────

        private void on_btn_toggled ()
        {
            if (updating_btn || host == null) return;

            if (lock_btn != null && lock_btn.active) {
                // User wants to encrypt
                ask_encrypt_password ();
            } else {
                // User wants to decrypt — button was active (encrypted), now off
                ask_decrypt_password ();
            }
        }

        // ── Encrypt flow ─────────────────────────────────────────────────────

        private void ask_encrypt_password ()
        {
            if (host == null || host.current_note == null) {
                set_btn_active (false);
                return;
            }

            var window = host.editor?.get_root () as Gtk.Window;

            var pass_entry    = new Gtk.PasswordEntry ();
            pass_entry.placeholder_text = _("Password");
            pass_entry.show_peek_icon   = true;
            pass_entry.hexpand = true;

            var confirm_entry = new Gtk.PasswordEntry ();
            confirm_entry.placeholder_text = _("Confirm password");
            confirm_entry.show_peek_icon   = true;
            confirm_entry.hexpand = true;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin_top    = 8;
            box.margin_bottom = 4;
            box.append (pass_entry);
            box.append (confirm_entry);

            var dialog = new Adw.AlertDialog (
                _("Encrypt Note"),
                _("Enter a password to encrypt this note. You will need the password to read it again.")
            );
            dialog.extra_child = box;
            dialog.add_response ("cancel",  _("Cancel"));
            dialog.add_response ("encrypt", _("Encrypt"));
            dialog.set_response_appearance ("encrypt", Adw.ResponseAppearance.SUGGESTED);
            dialog.default_response = "encrypt";

            dialog.choose.begin (window, null, (obj, res) => {
                if (dialog.choose.end (res) != "encrypt") {
                    set_btn_active (false);
                    return;
                }
                string pass    = pass_entry.text;
                string confirm = confirm_entry.text;
                if (pass.length == 0) {
                    host?.show_toast (_("Password cannot be empty"));
                    set_btn_active (false);
                    return;
                }
                if (pass != confirm) {
                    host?.show_toast (_("Passwords do not match"));
                    set_btn_active (false);
                    return;
                }
                do_encrypt (pass);
            });
        }

        private void do_encrypt (string password)
        {
            if (host == null || host.current_note == null) return;

            string plaintext = host.get_note_markup ();
            run_openssl.begin (false, plaintext, password, (obj, res) => {
                string? ciphertext = run_openssl.end (res);
                if (ciphertext == null || ciphertext.length == 0) {
                    host?.show_toast (_("Encryption failed"));
                    set_btn_active (false);
                    return;
                }
                // Strip trailing newline from openssl -A output
                ciphertext = ciphertext.strip ();
                string new_body = ENCRYPTED_PREFIX + ciphertext;
                if (host?.current_note != null)
                    host.current_note.body = new_body;
                host?.save_current_note ();
                host?.set_editor_locked (true);
                host?.set_editor_editable (false);
                set_btn_active (true);
                host?.show_toast (_("Note encrypted"));
            });
        }

        // ── Decrypt flow ─────────────────────────────────────────────────────

        private void ask_decrypt_password ()
        {
            if (host == null || host.current_note == null) {
                set_btn_active (false);
                return;
            }

            var window = host.editor?.get_root () as Gtk.Window;

            var pass_entry = new Gtk.PasswordEntry ();
            pass_entry.placeholder_text = _("Password");
            pass_entry.show_peek_icon   = true;
            pass_entry.hexpand = true;
            pass_entry.margin_top = 8;
            pass_entry.margin_bottom = 4;

            var dialog = new Adw.AlertDialog (
                _("Decrypt Note"),
                _("Enter the password to decrypt and view this note.")
            );
            dialog.extra_child = pass_entry;
            dialog.add_response ("cancel",  _("Cancel"));
            dialog.add_response ("decrypt", _("Decrypt"));
            dialog.set_response_appearance ("decrypt", Adw.ResponseAppearance.SUGGESTED);
            dialog.default_response = "decrypt";

            dialog.choose.begin (window, null, (obj, res) => {
                if (dialog.choose.end (res) != "decrypt") {
                    set_btn_active (true);   // stay locked
                    return;
                }
                string pass = pass_entry.text;
                if (pass.length == 0) {
                    host?.show_toast (_("Password cannot be empty"));
                    set_btn_active (true);
                    return;
                }
                do_decrypt (pass);
            });
        }

        private void do_decrypt (string password)
        {
            if (host == null || host.current_note == null) return;

            string body = host.current_note.body;
            if (!body.has_prefix (ENCRYPTED_PREFIX)) return;

            string ciphertext = body.substring (ENCRYPTED_PREFIX.length);
            run_openssl.begin (true, ciphertext, password, (obj, res) => {
                string? plaintext = run_openssl.end (res);
                if (plaintext == null || plaintext.length == 0) {
                    host?.show_toast (_("Decryption failed — wrong password?"));
                    set_btn_active (true);
                    return;
                }
                if (host?.current_note != null)
                    host.current_note.body = plaintext.strip ();
                host?.save_current_note ();
                host?.set_editor_locked (false);
                host?.set_editor_markup_silent (host.current_note?.body ?? "");
                host?.set_editor_editable (true);
                set_btn_active (false);
                host?.show_toast (_("Note decrypted"));
            });
        }

        // ── OpenSSL subprocess ───────────────────────────────────────────────

        private async string? run_openssl (bool decrypt, string input, string password)
        {
            string? result = null;
            SourceFunc resume = run_openssl.callback;

            new Thread<void> ("noteme-crypt", () => {
                result = run_openssl_sync (decrypt, input, password);
                Idle.add ((owned) resume);
            });

            yield;
            return result;
        }

        private string? run_openssl_sync (bool decrypt, string input, string password)
        {
            try {
                string[] argv;
                if (decrypt) {
                    argv = {
                        "openssl", "enc", "-d", "-aes-256-cbc",
                        "-pbkdf2", "-base64", "-A",
                        "-pass", "pass:" + password
                    };
                } else {
                    argv = {
                        "openssl", "enc", "-aes-256-cbc",
                        "-pbkdf2", "-base64", "-A",
                        "-pass", "pass:" + password
                    };
                }

                var proc = new GLib.Subprocess.newv (
                    argv,
                    GLib.SubprocessFlags.STDIN_PIPE |
                    GLib.SubprocessFlags.STDOUT_PIPE |
                    GLib.SubprocessFlags.STDERR_PIPE
                );

                string? stdout_str = null;
                string? stderr_str = null;
                // communicate_utf8 properly null-terminates the output strings
                proc.communicate_utf8 (input, null, out stdout_str, out stderr_str);

                if (!proc.get_successful ()) return null;
                return stdout_str;
            } catch (Error e) {
                warning ("openssl error: %s", e.message);
                return null;
            }
        }
    }
}
