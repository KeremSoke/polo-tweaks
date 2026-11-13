/* Controls that GTK does not offer ready-made. */

namespace PoloTweaks {

    public delegate double PresetValue (Settings settings);

    /* Centres its child and never makes it wider than maximum_width, so every page has the same readable column. */
    public class Clamp : Gtk.Bin {
        public int maximum_width { get; set; default = 740; }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void get_preferred_width (out int minimum, out int natural) {
            minimum = 0;
            natural = 0;
            var child = get_child ();
            if (child != null && child.visible) {
                child.get_preferred_width (out minimum, out natural);
            }
            natural = int.max (minimum, maximum_width);
        }

        public override void get_preferred_height (out int minimum, out int natural) {
            get_preferred_height_for_width (maximum_width, out minimum, out natural);
        }

        public override void get_preferred_height_for_width (int width, out int minimum, out int natural) {
            minimum = 0;
            natural = 0;
            var child = get_child ();
            if (child != null && child.visible) {
                child.get_preferred_height_for_width (int.min (width, maximum_width), out minimum, out natural);
            }
        }

        public override void size_allocate (Gtk.Allocation allocation) {
            set_allocation (allocation);
            var child = get_child ();
            if (child != null && child.visible) {
                int width = int.min (allocation.width, maximum_width);
                Gtk.Allocation inner = {
                    allocation.x + (allocation.width - width) / 2, allocation.y, width, allocation.height
                };
                child.size_allocate (inner);
            }
        }
    }

    /* A text field that saves when Enter is pressed or focus leaves, not on every keystroke. */
    public class CommitEntry : Gtk.Entry {
        private Settings settings;
        private string key;

        public CommitEntry (Settings settings, string key, string? placeholder = null) {
            Object (width_chars: 30, placeholder_text: placeholder);
            this.settings = settings;
            this.key = key;
            text = settings.get_string (key);
            activate.connect (commit);
            focus_out_event.connect (() => {
                commit ();
                return false;
            });
            settings.changed[key].connect (() => {
                if (!has_focus) {
                    text = settings.get_string (key);
                }
            });
        }

        private void commit () {
            if (text != settings.get_string (key)) {
                settings.set_string (key, text);
            }
        }
    }

    /* An editable list of strings, for the "as" keys. */
    public class StringListEditor : Gtk.Box {
        private Settings settings;
        private string key;
        private Gtk.ListStore store;
        private Gtk.TreeView view;
        private bool busy = false;

        public StringListEditor (Settings settings, string key) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.settings = settings;
            this.key = key;

            store = new Gtk.ListStore (1, typeof (string));
            view = new Gtk.TreeView.with_model (store) { headers_visible = false, enable_search = false };
            var cell = new Gtk.CellRendererText () { editable = true, ellipsize = Pango.EllipsizeMode.MIDDLE };
            cell.edited.connect (on_edited);
            cell.editing_canceled.connect (() => {
                prune_empty ();
            });
            view.insert_column_with_attributes (-1, null, cell, "text", 0);

            var scrolled = new Gtk.ScrolledWindow (null, null) {
                shadow_type = Gtk.ShadowType.IN,
                min_content_height = 110,
                max_content_height = 180,
                propagate_natural_height = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            scrolled.add (view);
            pack_start (scrolled, false, false, 0);

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Add")
            };
            var remove_button = new Gtk.Button.from_icon_name ("list-remove-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Remove the selected entry"), sensitive = false
            };
            add_button.clicked.connect (add_entry);
            remove_button.clicked.connect (remove_selected);
            view.get_selection ().changed.connect (() => {
                remove_button.sensitive = view.get_selection ().count_selected_rows () > 0;
            });
            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { halign = Gtk.Align.START };
            buttons.get_style_context ().add_class ("linked");
            buttons.pack_start (add_button, false, false, 0);
            buttons.pack_start (remove_button, false, false, 0);
            pack_start (buttons, false, false, 0);

            reload ();
            settings.changed[key].connect (() => {
                if (!busy) {
                    reload ();
                }
            });
        }

        private void reload () {
            store.clear ();
            foreach (string item in settings.get_strv (key)) {
                Gtk.TreeIter iter;
                store.append (out iter);
                store.set (iter, 0, item);
            }
        }

        private void commit () {
            string[] items = {};
            store.foreach ((model, path, iter) => {
                string item;
                model.get (iter, 0, out item);
                if (item != null && item.strip () != "") {
                    items += item.strip ();
                }
                return false;
            });
            busy = true;
            settings.set_strv (key, items);
            busy = false;
        }

        private void prune_empty () {
            Gtk.TreeIter iter;
            if (!store.get_iter_first (out iter)) {
                return;
            }
            bool more = true;
            while (more) {
                string item;
                store.get (iter, 0, out item);
                if (item == null || item.strip () == "") {
                    more = store.remove (ref iter);
                } else {
                    more = store.iter_next (ref iter);
                }
            }
        }

        private void on_edited (string path, string new_text) {
            Gtk.TreeIter iter;
            if (store.get_iter_from_string (out iter, path)) {
                store.set (iter, 0, new_text.strip ());
            }
            prune_empty ();
            commit ();
        }

        private void add_entry () {
            Gtk.TreeIter iter;
            store.append (out iter);
            store.set (iter, 0, "");
            view.set_cursor (store.get_path (iter), view.get_column (0), true);
        }

        private void remove_selected () {
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            if (view.get_selection ().get_selected (out model, out iter)) {
                store.remove (ref iter);
                commit ();
            }
        }
    }

    /* Picks an image file, showing a small preview of the current one. */
    public class ImageChooser : Gtk.Box {
        private Settings settings;
        private string key;
        private string chooser_title;
        private Gtk.Image thumbnail;
        private Gtk.Button pick;
        private Gtk.Button clear;
        private Gtk.FileChooserNative? native = null;

        public ImageChooser (Settings settings, string key, string chooser_title) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 8);
            this.settings = settings;
            this.key = key;
            this.chooser_title = chooser_title;

            thumbnail = new Gtk.Image () { width_request = 64, height_request = 36 };
            var frame = new Gtk.Frame (null);
            frame.add (thumbnail);
            pack_start (frame, false, false, 0);

            pick = new Gtk.Button.with_label (_("Choose image…")) { width_request = 150 };
            pick.clicked.connect (choose);
            pack_start (pick, false, false, 0);

            clear = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Use no image")
            };
            clear.clicked.connect (() => settings.set_string (key, ""));
            pack_start (clear, false, false, 0);

            refresh ();
            settings.changed[key].connect (refresh);
        }

        private void refresh () {
            string path = settings.get_string (key);
            clear.sensitive = path != "";
            if (path == "") {
                pick.label = _("Choose image…");
                pick.tooltip_text = null;
                thumbnail.clear ();
                return;
            }
            pick.label = Path.get_basename (path);
            pick.tooltip_text = path;
            try {
                thumbnail.pixbuf = new Gdk.Pixbuf.from_file_at_scale (path, 64, 36, true);
            } catch (Error e) {
                thumbnail.icon_name = "image-missing";
                pick.tooltip_text = _("%s\n\nThis file cannot be read; Polo falls back to a plain background.").printf (path);
            }
        }

        private void choose () {
            native = new Gtk.FileChooserNative (chooser_title, get_toplevel () as Gtk.Window,
                                                Gtk.FileChooserAction.OPEN, _("_Select"), _("_Cancel"));
            var filter = new Gtk.FileFilter ();
            filter.set_name (_("Images"));
            filter.add_pixbuf_formats ();
            native.add_filter (filter);
            string current = settings.get_string (key);
            if (current != "" && FileUtils.test (current, FileTest.EXISTS)) {
                native.set_filename (current);
            }
            native.response.connect ((response) => {
                if (response == Gtk.ResponseType.ACCEPT) {
                    string? chosen = native.get_filename ();
                    if (chosen != null) {
                        settings.set_string (key, chosen);
                    }
                }
                native = null;
            });
            native.show ();
        }
    }

    /*
     * A number that is either taken from the selected preset or set by the
     * user: unchecked, the spin button shows the preset's value; checked, it
     * edits the key. Polo stores "follow the preset" as -1.
     */
    public class OverrideSpin : Gtk.Box {
        private Settings settings;
        private string key;
        private PresetValue preset_value;
        private Gtk.CheckButton custom;
        private Gtk.SpinButton spin;
        private bool busy = false;

        public OverrideSpin (Settings settings, string key, double min, double max, double step, uint digits,
                             owned PresetValue preset_value) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 8);
            this.settings = settings;
            this.key = key;
            this.preset_value = (owned) preset_value;

            custom = new Gtk.CheckButton.with_label (_("Custom"));
            spin = new Gtk.SpinButton.with_range (min, max, step) { digits = digits, width_chars = 7 };
            pack_start (custom, false, false, 0);
            pack_start (spin, false, false, 0);

            custom.toggled.connect (() => {
                if (busy) {
                    return;
                }
                settings.set_double (key, custom.active ? spin.value : -1.0);
            });
            spin.value_changed.connect (() => {
                if (!busy && custom.active) {
                    settings.set_double (key, spin.value);
                }
            });
            refresh ();
            settings.changed.connect (() => refresh ());
        }

        private void refresh () {
            busy = true;
            double value = settings.get_double (key);
            bool is_custom = value >= 0.0;
            custom.active = is_custom;
            spin.sensitive = is_custom;
            spin.value = is_custom ? value : preset_value (settings);
            busy = false;
        }
    }
}
