/*
 * Shortcut editing in the manner of MATE's keyboard shortcuts panel: click
 * the shortcut, press the new keys, Backspace clears it, Esc cancels. Every
 * editor for a key listens to that key's GSettings changes, so the cube
 * shortcut shown on the Desktop Cube page and on the Keyboard Shortcuts page
 * are always the same value.
 */

namespace PoloTweaks {

    private Gtk.Window? window_of (Gtk.Widget widget) {
        return widget.get_toplevel () as Gtk.Window;
    }

    /* Asks whether to take a shortcut away from whatever uses it now. Returns true to go ahead. */
    private bool confirm_reassign (Gtk.Window? parent, Accel accel, Conflict conflict) {
        var dialog = new Gtk.MessageDialog (parent, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                                            Gtk.ButtonsType.NONE,
                                            _("“%s” is already in use"), accel.label ());
        dialog.format_secondary_text (_("It is currently assigned to “%s”. If you continue, that shortcut will be turned off."),
                                      conflict.title);
        dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
        dialog.add_button (_("_Reassign"), Gtk.ResponseType.ACCEPT);
        dialog.set_default_response (Gtk.ResponseType.CANCEL);
        int response = dialog.run ();
        dialog.destroy ();
        return response == Gtk.ResponseType.ACCEPT;
    }

    /* The button showing a shortcut; clicking it listens for a new one. */
    public class ShortcutButton : Gtk.Button {
        private Settings settings;
        private string key;
        private Gtk.Label caption;
        private bool capturing = false;
        private bool grabbed = false;
        private uint hint_timeout = 0;
        private uint focus_timeout = 0;

        public ShortcutButton (Settings settings, string key) {
            Object (width_request: 190, tooltip_text: _("Click, then press the new shortcut"));
            this.settings = settings;
            this.key = key;
            caption = new Gtk.Label ("");
            add (caption);
            show_all ();
            refresh ();

            clicked.connect (() => {
                if (capturing) {
                    stop_capture ("clicked again");
                } else {
                    start_capture ();
                }
            });
            key_press_event.connect (on_key_press);
            /*
             * Taking the keyboard grab can make the compositor send a short
             * focus leave and re-enter, so losing focus only ends the capture
             * if it has not come back a moment later.
             */
            focus_out_event.connect (() => {
                if (capturing && focus_timeout == 0) {
                    focus_timeout = Timeout.add (300, () => {
                        focus_timeout = 0;
                        if (capturing && !has_focus) {
                            stop_capture ("focus lost");
                        }
                        return false;
                    });
                }
                return false;
            });
            unmap.connect (() => stop_capture ("unmapped"));
            settings.changed[key].connect (refresh);
        }

        private void refresh () {
            if (capturing) {
                return;
            }
            var accel = Accel.parse (settings.get_string (key));
            if (accel == null) {
                caption.label = settings.get_string (key);
                return;
            }
            caption.label = accel.label ();
            var ctx = caption.get_style_context ();
            if (accel.disabled) {
                ctx.add_class ("dim-label");
            } else {
                ctx.remove_class ("dim-label");
            }
        }

        private void show_hint (string text) {
            caption.label = text;
            if (hint_timeout != 0) {
                Source.remove (hint_timeout);
            }
            hint_timeout = Timeout.add (1800, () => {
                hint_timeout = 0;
                if (capturing) {
                    caption.label = _("Type a shortcut…");
                }
                return false;
            });
        }

        private void start_capture () {
            capturing = true;
            get_style_context ().add_class ("capturing");
            caption.get_style_context ().remove_class ("dim-label");
            caption.label = _("Type a shortcut…");
            /* A tooltip is another surface; keep it from popping up while we listen. */
            has_tooltip = false;
            grab_focus ();
            var window = get_window ();
            if (window != null) {
                var seat = Gdk.Display.get_default ().get_default_seat ();
                grabbed = seat.grab (window, Gdk.SeatCapabilities.KEYBOARD, false, null, Gtk.get_current_event (), null)
                          == Gdk.GrabStatus.SUCCESS;
            }
        }

        private void stop_capture (string reason) {
            if (!capturing) {
                return;
            }
            debug ("shortcut capture for %s ended: %s", key, reason);
            capturing = false;
            if (focus_timeout != 0) {
                Source.remove (focus_timeout);
                focus_timeout = 0;
            }
            if (hint_timeout != 0) {
                Source.remove (hint_timeout);
                hint_timeout = 0;
            }
            if (grabbed) {
                Gdk.Display.get_default ().get_default_seat ().ungrab ();
                grabbed = false;
            }
            get_style_context ().remove_class ("capturing");
            has_tooltip = true;
            refresh ();
        }

        private bool on_key_press (Gdk.EventKey event) {
            if (!capturing) {
                return false;
            }
            var accel = Accel.from_event (event);
            if (accel == null) {
                /* Only a modifier so far; wait for the rest of the combination. */
                return true;
            }
            if (accel.mods == 0) {
                if (accel.keyval == Gdk.Key.Escape) {
                    stop_capture ("cancelled with Esc");
                    return true;
                }
                if (accel.keyval == Gdk.Key.BackSpace || accel.keyval == Gdk.Key.Delete) {
                    stop_capture ("turned off");
                    settings.set_string (key, "disabled");
                    return true;
                }
            }
            if (accel.needs_modifier ()) {
                show_hint (_("Add Ctrl, Alt or Super"));
                return true;
            }
            stop_capture ("assigned");
            assign (accel);
            return true;
        }

        private void assign (Accel accel) {
            var conflict = Conflicts.find (settings, key, accel);
            if (conflict != null) {
                if (!confirm_reassign (window_of (this), accel, conflict)) {
                    return;
                }
                conflict.disable ();
            }
            settings.set_string (key, accel.to_string ());
        }
    }

    /* A shortcut button with a button to turn the shortcut off. */
    public class ShortcutEditor : Gtk.Box {
        public ShortcutEditor (Settings settings, string key, string title) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            pack_start (new ShortcutButton (settings, key), false, false, 0);
            var off = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.BUTTON) {
                relief = Gtk.ReliefStyle.NONE,
                tooltip_text = _("Turn this shortcut off")
            };
            off.clicked.connect (() => settings.set_string (key, "disabled"));
            settings.changed[key].connect (() => {
                off.sensitive = settings.get_string (key) != "disabled";
            });
            off.sensitive = settings.get_string (key) != "disabled";
            pack_start (off, false, false, 0);
        }
    }

    /* A modifiers-plus-click binding, set in a small dialog that listens for the click. */
    public class PointerShortcutEditor : Gtk.Box {
        private Settings settings;
        private string key;
        private string title;
        private Gtk.Button button;
        private Gtk.Label caption;

        public PointerShortcutEditor (Settings settings, string key, string title) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            this.settings = settings;
            this.key = key;
            this.title = title;

            caption = new Gtk.Label ("");
            button = new Gtk.Button () {
                width_request = 190,
                tooltip_text = _("Click, then hold the modifier keys and click with the mouse button")
            };
            button.add (caption);
            button.clicked.connect (open_dialog);
            pack_start (button, false, false, 0);

            var off = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.BUTTON) {
                relief = Gtk.ReliefStyle.NONE,
                tooltip_text = _("Turn this shortcut off")
            };
            off.clicked.connect (() => settings.set_string (key, "disabled"));
            pack_start (off, false, false, 0);

            settings.changed[key].connect (() => {
                refresh ();
                off.sensitive = settings.get_string (key) != "disabled";
            });
            refresh ();
            off.sensitive = settings.get_string (key) != "disabled";
        }

        private void refresh () {
            var accel = MouseAccel.parse (settings.get_string (key));
            caption.label = accel != null ? accel.label () : settings.get_string (key);
            if (accel != null && accel.disabled) {
                caption.get_style_context ().add_class ("dim-label");
            } else {
                caption.get_style_context ().remove_class ("dim-label");
            }
        }

        private void open_dialog () {
            var dialog = new Gtk.Dialog () {
                title = _("Set Pointer Shortcut"),
                transient_for = window_of (this),
                modal = true,
                resizable = false
            };
            dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
            dialog.add_button (_("_Turn Off"), Gtk.ResponseType.REJECT);

            var area = (Gtk.Box) dialog.get_content_area ();
            area.spacing = 12;
            area.margin = 18;
            var intro = new Gtk.Label (_("Hold down the modifier keys (Ctrl, Alt, Super or Shift) and click with the mouse button you want to use for “%s”.").printf (title)) {
                wrap = true, max_width_chars = 44, xalign = 0
            };
            area.pack_start (intro, false, false, 0);

            var pad = new Gtk.EventBox () { width_request = 340, height_request = 110 };
            pad.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
            var pad_label = new Gtk.Label (_("Click here while holding the modifier keys"));
            pad_label.get_style_context ().add_class ("dim-label");
            pad.add (pad_label);
            var frame = new Gtk.Frame (null);
            frame.add (pad);
            area.pack_start (frame, false, false, 0);

            var problem = new Gtk.Label ("") { xalign = 0, wrap = true };
            problem.get_style_context ().add_class ("error");
            area.pack_start (problem, false, false, 0);

            pad.button_press_event.connect ((event) => {
                var mods = event.state & ACCEL_MASK;
                if ((event.state & Gdk.ModifierType.MOD4_MASK) != 0) {
                    mods |= Gdk.ModifierType.SUPER_MASK;
                }
                if (mods == 0) {
                    problem.label = _("Hold at least one modifier key while you click.");
                    return true;
                }
                if (!MouseAccel.supported_button (event.button)) {
                    problem.label = _("Use the left, middle, right, back or forward button.");
                    return true;
                }
                var accel = new MouseAccel ();
                accel.mods = mods;
                accel.button = event.button;
                settings.set_string (key, accel.to_string ());
                dialog.response (Gtk.ResponseType.ACCEPT);
                return true;
            });
            dialog.response.connect ((response) => {
                if (response == Gtk.ResponseType.REJECT) {
                    settings.set_string (key, "disabled");
                }
                dialog.destroy ();
            });
            dialog.show_all ();
        }
    }
}
