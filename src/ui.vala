/* The building blocks every page is made of: rows, and groups of rows. */

namespace PoloTweaks {

    public delegate bool Condition (Settings settings);

    /* A setting a row edits, so it can show whether it is changed and be reset. */
    public class KeyRef : Object {
        public Settings settings;
        public string key;

        public KeyRef (Settings settings, string key) {
            this.settings = settings;
            this.key = key;
        }

        public bool is_default () {
            return settings.get_value (key).equal (settings.get_default_value (key));
        }

        public void reset () {
            settings.reset (key);
        }
    }

    /*
     * One setting: a title and a short explanation on the left, the control
     * on the right, and a reset arrow that only appears once the value has
     * been changed from the default.
     */
    public class Row : Gtk.ListBoxRow {
        public string title;
        public string? subtitle;
        public Group? group = null;
        public Gtk.Widget? activator = null;
        public GLib.GenericArray<KeyRef> refs = new GLib.GenericArray<KeyRef> ();

        private Gtk.Button reset_button;
        private Gtk.Box outer;

        public Row (string title, string? subtitle = null, Gtk.Widget? control = null, Gtk.Widget? wide = null) {
            this.title = title;
            this.subtitle = subtitle;
            activatable = false;
            selectable = false;

            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                valign = Gtk.Align.CENTER,
                hexpand = true
            };
            var title_label = new Gtk.Label (title) {
                xalign = 0, wrap = true, max_width_chars = 52, halign = Gtk.Align.START
            };
            text.pack_start (title_label, false, false, 0);
            if (subtitle != null && subtitle != "") {
                var sub = new Gtk.Label (subtitle) {
                    xalign = 0, wrap = true, max_width_chars = 62, halign = Gtk.Align.START
                };
                sub.get_style_context ().add_class ("row-subtitle");
                text.pack_start (sub, false, false, 0);
            }

            reset_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.BUTTON) {
                relief = Gtk.ReliefStyle.NONE,
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Reset to default"),
                sensitive = false,
                opacity = 0.0,
                can_focus = false
            };
            reset_button.clicked.connect (() => {
                for (int i = 0; i < refs.length; i++) {
                    refs[i].reset ();
                }
            });

            var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            line.pack_start (text, true, true, 0);
            if (control != null) {
                control.valign = Gtk.Align.CENTER;
                line.pack_start (control, false, false, 0);
            }
            line.pack_start (reset_button, false, false, 0);

            outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                margin_top = 10, margin_bottom = 10, margin_start = 14, margin_end = 10
            };
            outer.pack_start (line, false, false, 0);
            if (wide != null) {
                outer.pack_start (wide, false, false, 0);
            }
            add (outer);
        }

        /* Set the row in under the one before it, as one of its options. */
        public Row indent () {
            outer.margin_start = 38;
            return this;
        }

        /* Mark this row as editing a key. */
        public Row track (Settings settings, string key) {
            refs.add (new KeyRef (settings, key));
            settings.changed[key].connect (update_reset);
            update_reset ();
            return this;
        }

        private void update_reset () {
            bool modified = false;
            for (int i = 0; i < refs.length; i++) {
                if (!refs[i].is_default ()) {
                    modified = true;
                }
            }
            reset_button.sensitive = modified;
            reset_button.opacity = modified ? 1.0 : 0.0;
        }

        /*
         * Show this row only while condition holds (or, with hide false,
         * keep it visible but greyed out), re-checking whenever one of keys
         * changes. This is what keeps pages short: a background's own
         * options appear only when that background is chosen.
         */
        public Row depends (Settings settings, string[] keys, owned Condition condition, bool hide = true) {
            apply_condition (settings, condition, hide);
            foreach (string key in keys) {
                settings.changed[key].connect (() => apply_condition (settings, condition, hide));
            }
            return this;
        }

        private void apply_condition (Settings settings, Condition condition, bool hide) {
            bool ok = condition (settings);
            if (hide) {
                visible = ok;
                no_show_all = !ok;
            } else {
                sensitive = ok;
            }
        }

        public bool matches (string needle) {
            string hay = "%s %s %s".printf (title, subtitle ?? "", group != null ? group.heading ?? "" : "").down ();
            return hay.contains (needle);
        }

        /* Briefly highlight the row, to show where a search result is. */
        public void flash () {
            var ctx = get_style_context ();
            ctx.add_class ("search-hit");
            Timeout.add (1800, () => {
                ctx.remove_class ("search-hit");
                return false;
            });
        }
    }

    /* A titled box of rows, optionally inside an "Advanced" expander. */
    public class Group : Gtk.Box {
        public string? heading;
        public Gtk.Expander? expander;
        public Gtk.ListBox list;
        public GLib.GenericArray<Row> rows = new GLib.GenericArray<Row> ();

        public Group (string? heading, string? description = null, Gtk.Expander? expander = null) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.heading = heading;
            this.expander = expander;

            if (heading != null) {
                var h = new Gtk.Label (heading) { xalign = 0, halign = Gtk.Align.START };
                h.get_style_context ().add_class ("section-title");
                pack_start (h, false, false, 0);
            }
            if (description != null) {
                var d = new Gtk.Label (description) {
                    xalign = 0, wrap = true, max_width_chars = 80, halign = Gtk.Align.START
                };
                d.get_style_context ().add_class ("row-subtitle");
                pack_start (d, false, false, 0);
            }

            list = new Gtk.ListBox () { selection_mode = Gtk.SelectionMode.NONE };
            list.set_header_func ((row, before) => {
                if (before != null && row.get_header () == null) {
                    row.set_header (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
                }
            });
            list.row_activated.connect ((row) => {
                var r = row as Row;
                if (r != null && r.activator != null && r.activator.sensitive) {
                    r.activator.activate ();
                }
            });
            var frame = new Gtk.Frame (null);
            frame.add (list);
            pack_start (frame, false, false, 0);
        }

        public Row add_row (Row row) {
            list.add (row);
            rows.add (row);
            row.group = this;
            row.show_all ();
            return row;
        }

        /* ---- Controls --------------------------------------------------------------- */

        public Row toggle (Settings s, string key, string title, string? hint = null, bool invert = false) {
            var sw = new Gtk.Switch ();
            s.bind (key, sw, "active", invert ? SettingsBindFlags.INVERT_BOOLEAN : SettingsBindFlags.DEFAULT);
            var row = new Row (title, hint, sw);
            row.activator = sw;
            row.activatable = true;
            return add_row (row.track (s, key));
        }

        /* A choice between named strings. */
        public Row choice (Settings s, string key, string title, string? hint, string[] ids, string[] labels) {
            var combo = new Gtk.ComboBoxText ();
            for (int i = 0; i < ids.length; i++) {
                combo.append (ids[i], labels[i]);
            }
            s.bind (key, combo, "active-id", SettingsBindFlags.DEFAULT);
            return add_row (new Row (title, hint, combo).track (s, key));
        }

        /* A choice between numbered presets (an integer key). */
        public Row preset (Settings s, string key, string title, string? hint, string[] labels) {
            var combo = new Gtk.ComboBoxText ();
            foreach (string label in labels) {
                combo.append_text (label);
            }
            combo.active = s.get_int (key);
            bool busy = false;
            combo.changed.connect (() => {
                if (!busy && combo.active >= 0) {
                    s.set_int (key, combo.active);
                }
            });
            s.changed[key].connect (() => {
                busy = true;
                combo.active = s.get_int (key);
                busy = false;
            });
            return add_row (new Row (title, hint, combo).track (s, key));
        }

        public Row number (Settings s, string key, string title, string? hint,
                           double min, double max, double step, uint digits = 0, string? unit = null) {
            var spin = new Gtk.SpinButton.with_range (min, max, step) { digits = digits, width_chars = 7 };
            s.bind (key, spin, "value", SettingsBindFlags.DEFAULT);
            Gtk.Widget control = spin;
            if (unit != null) {
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                box.pack_start (spin, false, false, 0);
                var u = new Gtk.Label (unit);
                u.get_style_context ().add_class ("row-subtitle");
                box.pack_start (u, false, false, 0);
                control = box;
            }
            return add_row (new Row (title, hint, control).track (s, key));
        }

        public Row slider (Settings s, string key, string title, string? hint,
                           double min, double max, double step, uint digits = 2) {
            var scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step) {
                draw_value = true, digits = (int) digits, value_pos = Gtk.PositionType.RIGHT, width_request = 240
            };
            s.bind (key, scale.adjustment, "value", SettingsBindFlags.DEFAULT);
            return add_row (new Row (title, hint, scale).track (s, key));
        }

        public Row colour (Settings s, string key, string title, string? hint = null) {
            var button = new Gtk.ColorButton ();
            Gdk.RGBA current = Gdk.RGBA ();
            if (current.parse (s.get_string (key))) {
                button.rgba = current;
            }
            button.color_set.connect (() => {
                var c = button.rgba;
                s.set_string (key, "#%02x%02x%02x".printf ((int) Math.round (c.red * 255),
                                                           (int) Math.round (c.green * 255),
                                                           (int) Math.round (c.blue * 255)));
            });
            s.changed[key].connect (() => {
                Gdk.RGBA c = Gdk.RGBA ();
                if (c.parse (s.get_string (key))) {
                    button.rgba = c;
                }
            });
            return add_row (new Row (title, hint, button).track (s, key));
        }

        public Row image (Settings s, string key, string title, string? hint, string chooser_title) {
            return add_row (new Row (title, hint, new ImageChooser (s, key, chooser_title)).track (s, key));
        }

        public Row text (Settings s, string key, string title, string? hint, string? placeholder = null) {
            return add_row (new Row (title, hint, new CommitEntry (s, key, placeholder)).track (s, key));
        }

        public Row string_list (Settings s, string key, string title, string? hint) {
            return add_row (new Row (title, hint, null, new StringListEditor (s, key)).track (s, key));
        }

        /* A value that follows a preset until the user chooses their own. */
        public Row override_number (Settings s, string key, string title, string? hint,
                                    double min, double max, double step, uint digits, owned PresetValue preset_value) {
            return add_row (new Row (title, hint, new OverrideSpin (s, key, min, max, step, digits, (owned) preset_value))
                             .track (s, key));
        }

        public Row shortcut (Settings s, string key, string title, string? hint = null) {
            return add_row (new Row (title, hint, new ShortcutEditor (s, key, title)).track (s, key));
        }

        public Row pointer_shortcut (Settings s, string key, string title, string? hint = null) {
            return add_row (new Row (title, hint, new PointerShortcutEditor (s, key, title)).track (s, key));
        }
    }
}
