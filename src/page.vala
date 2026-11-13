/* The base of every settings page. */

namespace PoloTweaks {

    public abstract class Page : Gtk.ScrolledWindow {
        public string page_id;
        public string page_title;
        public string page_icon;
        public string page_summary;
        public string nav_section;
        public GLib.GenericArray<Group> groups = new GLib.GenericArray<Group> ();

        /* The page's "On"/"Off" state shown in the sidebar, if it has one. */
        public signal void status_changed ();

        protected Gtk.Box content;
        protected Gtk.Box body;
        private Gtk.Box header;
        private GLib.GenericArray<KeyRef> extra_keys = new GLib.GenericArray<KeyRef> ();
        private Settings? master_settings = null;
        private string? master_key = null;

        protected Page (string id, string title, string icon, string summary, string section) {
            Object (hscrollbar_policy: Gtk.PolicyType.NEVER);
            page_id = id;
            page_title = title;
            page_icon = icon;
            page_summary = summary;
            nav_section = section;

            content = new Gtk.Box (Gtk.Orientation.VERTICAL, 22) {
                margin_top = 28, margin_bottom = 28, margin_start = 28, margin_end = 28
            };

            header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
            var titles = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) { hexpand = true, valign = Gtk.Align.CENTER };
            var heading = new Gtk.Label (title) { xalign = 0, halign = Gtk.Align.START };
            heading.get_style_context ().add_class ("page-title");
            titles.pack_start (heading, false, false, 0);
            var sub = new Gtk.Label (summary) {
                xalign = 0, wrap = true, max_width_chars = 64, halign = Gtk.Align.START
            };
            sub.get_style_context ().add_class ("row-subtitle");
            titles.pack_start (sub, false, false, 0);
            header.pack_start (titles, true, true, 0);
            content.pack_start (header, false, false, 0);

            body = new Gtk.Box (Gtk.Orientation.VERTICAL, 22);
            content.pack_start (body, false, false, 0);

            var clamp = new Clamp ();
            clamp.add (content);
            add (clamp);
        }

        /*
         * Give the page an on/off switch next to its title, as an effect
         * plugin has in Compiz: while it is off, everything else on the
         * page is greyed out.
         */
        protected void set_master (Settings settings, string key, string? label = null) {
            master_settings = settings;
            master_key = key;
            extra_keys.add (new KeyRef (settings, key));

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) { valign = Gtk.Align.CENTER };
            var text = new Gtk.Label (label ?? _("Enabled"));
            var sw = new Gtk.Switch ();
            settings.bind (key, sw, "active", SettingsBindFlags.DEFAULT);
            settings.bind (key, body, "sensitive", SettingsBindFlags.GET);
            box.pack_start (text, false, false, 0);
            box.pack_start (sw, false, false, 0);
            header.pack_start (box, false, false, 0);
            settings.changed[key].connect (() => status_changed ());
        }

        public virtual string? status_text () {
            if (master_settings == null) {
                return null;
            }
            return master_settings.get_boolean (master_key) ? _("On") : _("Off");
        }

        protected Group group (string? heading, string? description = null) {
            var g = new Group (heading, description);
            groups.add (g);
            body.pack_start (g, false, false, 0);
            return g;
        }

        /* A collapsed "Advanced" section; groups made in it are returned by advanced_group (). */
        protected Gtk.Box advanced_box (string? label = null) {
            var caption = new Gtk.Label (label ?? _("Advanced"));
            caption.get_style_context ().add_class ("section-title");
            var expander = new Gtk.Expander (null) { label_widget = caption };
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18) { margin_top = 12 };
            expander.add (box);
            body.pack_start (expander, false, false, 0);
            box.set_data<Gtk.Expander> ("expander", expander);
            return box;
        }

        protected Group advanced_group (Gtk.Box box, string? heading, string? description = null) {
            var g = new Group (heading, description, box.get_data<Gtk.Expander> ("expander"));
            groups.add (g);
            box.pack_start (g, false, false, 0);
            return g;
        }

        protected void note (string text, string icon = "dialog-information-symbolic") {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.pack_start (new Gtk.Image.from_icon_name (icon, Gtk.IconSize.BUTTON) { valign = Gtk.Align.START }, false, false, 0);
            var label = new Gtk.Label (text) { xalign = 0, wrap = true, max_width_chars = 76 };
            label.get_style_context ().add_class ("row-subtitle");
            box.pack_start (label, false, false, 0);
            body.pack_start (box, false, false, 0);
        }

        /* A "Restore defaults" button at the foot of the page. */
        protected void add_restore_button () {
            var button = new Gtk.Button.with_label (_("Restore Defaults")) { halign = Gtk.Align.END };
            button.clicked.connect (() => {
                var dialog = new Gtk.MessageDialog (get_toplevel () as Gtk.Window, Gtk.DialogFlags.MODAL,
                                                    Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE,
                                                    _("Restore the defaults for “%s”?"), page_title);
                dialog.format_secondary_text (_("Every setting on this page goes back to its original value."));
                dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
                dialog.add_button (_("_Restore"), Gtk.ResponseType.ACCEPT);
                if (dialog.run () == Gtk.ResponseType.ACCEPT) {
                    restore_defaults ();
                }
                dialog.destroy ();
            });
            content.pack_start (button, false, false, 0);
        }

        public void restore_defaults () {
            for (int i = 0; i < extra_keys.length; i++) {
                extra_keys[i].reset ();
            }
            for (int g = 0; g < groups.length; g++) {
                var rows = groups[g].rows;
                for (int r = 0; r < rows.length; r++) {
                    for (int k = 0; k < rows[r].refs.length; k++) {
                        rows[r].refs[k].reset ();
                    }
                }
            }
        }

        /* Scroll a row into view and highlight it, for search results. */
        public void reveal (Row row) {
            if (row.group != null && row.group.expander != null) {
                row.group.expander.expanded = true;
            }
            Idle.add (() => {
                int x;
                int y;
                if (row.translate_coordinates (content, 0, 0, out x, out y)) {
                    vadjustment.value = double.max (0, y - 90);
                }
                row.flash ();
                return false;
            });
        }
    }
}
