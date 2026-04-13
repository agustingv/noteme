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
            host.addToolbarWidget (lock_btn);

            lock_btn.toggled.connect (onBtnToggled);

            note_selected_id = host.note_selected.connect ((note) => {
                // loadNote() runs after this signal, so defer state update
                GLib.Idle.add (() => {
                    applyLockState ();
                    return GLib.Source.REMOVE;
                });
            });

            applyLockState ();
        }

        public void deactivate ()
        {
            if (host != null && note_selected_id != 0) {
                host.disconnect (note_selected_id);
                note_selected_id = 0;
            }
            if (lock_btn != null) {
                host?.removeToolbarWidget (lock_btn);
                lock_btn = null;
            }
            host?.setEditorLocked (false);
            host?.setEditorEditable (true);
            host = null;
        }

        // ── Helpers ──────────────────────────────────────────────────────────

        private bool noteIsEncrypted ()
        {
            if (host == null || host.current_note == null) return false;
            return host.current_note.body.has_prefix (ENCRYPTED_PREFIX);
        }

        private void applyLockState ()
        {
            bool encrypted = noteIsEncrypted ();
            setBtnActive (encrypted);
            host?.setEditorLocked (encrypted);
            host?.setEditorEditable (!encrypted);
        }

        private void setBtnActive (bool active)
        {
            updating_btn = true;
            if (lock_btn != null) lock_btn.active = active;
            updating_btn = false;
        }

        // ── Button toggled ───────────────────────────────────────────────────

        private void onBtnToggled ()
        {
            if (updating_btn || host == null) return;

            if (lock_btn != null && lock_btn.active) {
                // User wants to encrypt
                askEncryptPassword ();
            } else {
                // User wants to decrypt — button was active (encrypted), now off
                askDecryptPassword ();
            }
        }

        // ── Encrypt flow ─────────────────────────────────────────────────────

        private void askEncryptPassword ()
        {
            if (host == null || host.current_note == null) {
                setBtnActive (false);
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
                    setBtnActive (false);
                    return;
                }
                string pass    = pass_entry.text;
                string confirm = confirm_entry.text;
                if (pass.length == 0) {
                    host?.showToast (_("Password cannot be empty"));
                    setBtnActive (false);
                    return;
                }
                if (pass != confirm) {
                    host?.showToast (_("Passwords do not match"));
                    setBtnActive (false);
                    return;
                }
                doEncrypt (pass);
            });
        }

        private void doEncrypt (string password)
        {
            if (host == null || host.current_note == null) return;

            string plaintext = host.getNoteMarkup ();
            runOpenssl.begin (false, plaintext, password, (obj, res) => {
                string? ciphertext = runOpenssl.end (res);
                if (ciphertext == null || ciphertext.length == 0) {
                    host?.showToast (_("Encryption failed"));
                    setBtnActive (false);
                    return;
                }
                // Strip trailing newline from openssl -A output
                ciphertext = ciphertext.strip ();
                string new_body = ENCRYPTED_PREFIX + ciphertext;
                if (host?.current_note != null)
                    host.current_note.body = new_body;
                host?.saveCurrentNote ();
                host?.setEditorLocked (true);
                host?.setEditorEditable (false);
                setBtnActive (true);
                host?.showToast (_("Note encrypted"));
            });
        }

        // ── Decrypt flow ─────────────────────────────────────────────────────

        private void askDecryptPassword ()
        {
            if (host == null || host.current_note == null) {
                setBtnActive (false);
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
                    setBtnActive (true);   // stay locked
                    return;
                }
                string pass = pass_entry.text;
                if (pass.length == 0) {
                    host?.showToast (_("Password cannot be empty"));
                    setBtnActive (true);
                    return;
                }
                doDecrypt (pass);
            });
        }

        private void doDecrypt (string password)
        {
            if (host == null || host.current_note == null) return;

            string body = host.current_note.body;
            if (!body.has_prefix (ENCRYPTED_PREFIX)) return;

            string ciphertext = body.substring (ENCRYPTED_PREFIX.length);
            runOpenssl.begin (true, ciphertext, password, (obj, res) => {
                string? plaintext = runOpenssl.end (res);
                if (plaintext == null || plaintext.length == 0) {
                    host?.showToast (_("Decryption failed — wrong password?"));
                    setBtnActive (true);
                    return;
                }
                if (host?.current_note != null)
                    host.current_note.body = plaintext.strip ();
                host?.saveCurrentNote ();
                host?.setEditorLocked (false);
                host?.setEditorMarkupSilent (host.current_note?.body ?? "");
                host?.setEditorEditable (true);
                setBtnActive (false);
                host?.showToast (_("Note decrypted"));
            });
        }

        // ── OpenSSL subprocess ───────────────────────────────────────────────

        private async string? runOpenssl (bool decrypt, string input, string password)
        {
            string? result = null;
            SourceFunc resume = runOpenssl.callback;

            new Thread<void> ("noteme-crypt", () => {
                result = runOpensslSync (decrypt, input, password);
                Idle.add ((owned) resume);
            });

            yield;
            return result;
        }

        private string? runOpensslSync (bool decrypt, string input, string password)
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
