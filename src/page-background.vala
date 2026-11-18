/* The desktop background: who draws it, the shared one, and one per monitor or per workspace. */

namespace PoloTweaks {

    public class BackgroundPage : Page {
        private const string MONITOR_SCHEMA = "org.mate.background.monitor";
        private const string MONITOR_PATH = "/org/mate/desktop/background/monitors/";
        private const string WORKSPACE_SCHEMA = "org.mate.polo.background.workspace";
        private const string WORKSPACE_PATH = "/org/mate/polo/background/workspaces/";
        private const string MARCO_GENERAL = "org.mate.Marco.general";
        private const string MARCO_NAMES = "org.mate.Marco.workspace-names";
        private const string[] PICTURE_KEYS = {
            "picture-filename", "picture-options", "color-shading-type", "primary-color", "secondary-color"
        };

        private Settings bg;
        private Settings? marco = null;
        private Settings? names = null;
        private GLib.GenericArray<Settings> monitor_settings = new GLib.GenericArray<Settings> ();
        private Section monitors;
        private Section workspaces;
        private uint rebuild_idle = 0;

        private class Section : Gtk.Box {
            public Group? group = null;
            private Gtk.Box notice;
            private Gtk.Label notice_text;

            public Section () {
                Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
                notice = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) { no_show_all = true };
                var icon = new Gtk.Image.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.BUTTON) {
                    valign = Gtk.Align.START
                };
                notice.pack_start (icon, false, false, 0);
                notice_text = new Gtk.Label (null) { xalign = 0, wrap = true, max_width_chars = 76 };
                notice_text.get_style_context ().add_class ("row-subtitle");
                notice.pack_start (notice_text, false, false, 0);
                pack_end (notice, false, false, 0);
            }

            public Group replace (string heading, string description) {
                if (group != null) {
                    remove (group);
                    group.destroy ();
                }
                group = new Group (heading, description);
                pack_start (group, false, false, 0);
                return group;
            }

            public void explain (bool usable, string? why) {
                group.list.sensitive = usable;
                notice_text.label = why ?? "";
                notice.foreach ((child) => child.visible = why != null);
                notice.visible = why != null;
            }
        }

        public BackgroundPage () {
            base ("background", _("Background"), "preferences-desktop-wallpaper-symbolic",
                  _("The desktop background, for all monitors and workspaces or for each on its own."),
                  _("Desktop"));

            bg = Schemas.get (Schemas.BACKGROUND);
            if (Schemas.installed (MARCO_GENERAL)) {
                marco = new Settings (MARCO_GENERAL);
                marco.changed["num-workspaces"].connect (queue_rebuild);
            }
            if (Schemas.installed (MARCO_NAMES)) {
                names = new Settings (MARCO_NAMES);
                names.changed.connect (queue_rebuild);
            }

            var drawing = group (null);
            drawing.toggle (bg, "draw-background", _("Let Polo draw the background"),
                            _("Polo draws the background under the desktop icons, so each monitor and each workspace can have its own, and the cube and Expo show them. When off, Caja draws one background behind its icons, and Polo draws it only while Caja is not running."),
                            true);
            bg.changed["draw-background"].connect (() => {
                foreach (var monitor in monitor_settings) {
                    copy_drawing (monitor);
                }
                refresh_sections ();
                status_changed ();
            });

            var shared = group (_("Background"),
                                _("Shown on every monitor and workspace that has no background of its own."));
            add_picture_rows (shared, bg, false);

            monitors = new Section ();
            body.pack_start (monitors, false, false, 0);
            workspaces = new Section ();
            body.pack_start (workspaces, false, false, 0);

            var display = Gdk.Display.get_default ();
            if (display != null) {
                display.monitor_added.connect (queue_rebuild);
                display.monitor_removed.connect (queue_rebuild);
            }
            rebuild ();
            add_restore_button ();
        }

        public override string? status_text () {
            return polo_draws () ? _("Polo") : _("Caja");
        }

        private bool polo_draws () {
            return !bg.get_boolean ("draw-background");
        }

        /* ---- Rows ------------------------------------------------------------------- */

        private void add_picture_rows (Group group, Settings s, bool own) {
            var rows = new GLib.GenericArray<Row> ();
            rows.add (group.image (s, "picture-filename", _("Image"),
                                   _("Leave empty to show only the colours."), _("Choose a background image")));
            rows.add (group.choice (s, "picture-options", _("Fit"), null,
                                    { "zoom", "scaled", "stretched", "centered", "wallpaper", "spanned" },
                                    { _("Zoom (fill, cropping the edges)"), _("Scale (fit inside)"), _("Stretch"),
                                      _("Centre"), _("Tile"), _("Span across monitors") }));
            rows.add (group.choice (s, "color-shading-type", _("Colours"),
                                    _("Shown where the image does not cover the screen, or instead of it."),
                                    { "solid", "horizontal-gradient", "vertical-gradient" },
                                    { _("Solid colour"), _("Horizontal gradient"), _("Vertical gradient") }));
            rows.add (group.colour (s, "primary-color", _("Colour")));
            var second = group.colour (s, "secondary-color", _("Second colour"));

            if (!own) {
                second.depends (s, { "color-shading-type" }, (x) => x.get_string ("color-shading-type") != "solid");
                return;
            }
            foreach (var row in rows) {
                row.indent ().depends (s, { "use-shared" }, (x) => !x.get_boolean ("use-shared"));
            }
            second.indent ().depends (s, { "use-shared", "color-shading-type" },
                                      (x) => !x.get_boolean ("use-shared") &&
                                             x.get_string ("color-shading-type") != "solid");
        }

        private void add_own (Group group, Settings s, string title, string hint) {
            group.toggle (s, "use-shared", title, hint, true);
            s.changed["use-shared"].connect (() => {
                if (!s.get_boolean ("use-shared")) {
                    seed (s);
                }
            });
            add_picture_rows (group, s, true);
        }

        private void seed (Settings s) {
            foreach (string key in PICTURE_KEYS) {
                if (!new KeyRef (s, key).is_default ()) {
                    return;
                }
            }
            foreach (string key in PICTURE_KEYS) {
                s.set_value (key, bg.get_value (key));
            }
            if (s.settings_schema.has_key ("draw-background")) {
                copy_drawing (s);
            }
        }

        private void copy_drawing (Settings monitor) {
            bool draw = bg.get_boolean ("draw-background");
            if (monitor.get_boolean ("draw-background") != draw) {
                monitor.set_boolean ("draw-background", draw);
            }
        }

        private static Settings? relocatable (string schema_id, string path) {
            var source = SettingsSchemaSource.get_default ();
            var schema = source != null ? source.lookup (schema_id, true) : null;
            return schema != null ? new Settings.full (schema, null, path) : null;
        }

        /* ---- Sections --------------------------------------------------------------- */

        private void queue_rebuild () {
            if (rebuild_idle == 0) {
                rebuild_idle = Idle.add (() => {
                    rebuild_idle = 0;
                    rebuild ();
                    return Source.REMOVE;
                });
            }
        }

        private Group replace_group (Section section, string heading, string description) {
            if (section.group != null) {
                groups.remove (section.group);
            }
            var group = section.replace (heading, description);
            groups.add (group);
            return group;
        }

        private void rebuild () {
            build_monitors ();
            build_workspaces ();
            monitors.show_all ();
            workspaces.show_all ();
            refresh_sections ();
        }

        private void refresh_sections () {
            string? off = polo_draws () ? null
                        : _("Turn on “Let Polo draw the background” to use these: Caja draws one background for every monitor and workspace.");
            bool monitors_installed = Schemas.installed (MONITOR_SCHEMA);
            bool workspaces_installed = Schemas.installed (WORKSPACE_SCHEMA);
            monitors.explain (monitors_installed && off == null,
                              monitors_installed ? null
                              : _("Needs a mate-desktop with per-monitor backgrounds (the org.mate.background.monitor settings)."));
            workspaces.explain (workspaces_installed && off == null,
                                workspaces_installed ? off
                                : _("Needs a Polo with per-workspace backgrounds (the org.mate.polo.background.workspace settings)."));
        }

        /* ---- Monitors --------------------------------------------------------------- */

        private class Screen {
            public Gdk.Monitor monitor;
            public string id;
            public string name;
        }

        private static string sanitize (string? text) {
            var id = new StringBuilder ();
            if (text != null) {
                for (int i = 0; i < text.length; i++) {
                    char c = text[i];
                    id.append_c (c.isalnum () || c == '_' || c == '.' || c == '-' ? c : '_');
                }
            }
            return id.str;
        }

        private static string monitor_id (Gdk.Monitor monitor) {
            string make = sanitize (monitor.manufacturer);
            string model = sanitize (monitor.model);
            string id = make != "" && model != "" ? "%s-%s".printf (make, model) : make + model;
            return id != "" ? id : "monitor";
        }

        private void build_monitors () {
            var group = replace_group (monitors, _("Per monitor"),
                                       _("A monitor with its own background keeps it on every workspace."));
            monitor_settings.remove_range (0, monitor_settings.length);
            var display = Gdk.Display.get_default ();
            if (display == null || !Schemas.installed (MONITOR_SCHEMA)) {
                return;
            }
            var screens = new GLib.GenericArray<Screen> ();
            for (int i = 0; i < display.get_n_monitors (); i++) {
                var monitor = display.get_monitor (i);
                string label = "%s %s".printf (monitor.manufacturer ?? "", monitor.model ?? "").strip ();
                screens.add (new Screen () {
                    monitor = monitor, id = monitor_id (monitor), name = label != "" ? label : _("Monitor")
                });
            }
            screens.sort ((a, b) => {
                var ga = a.monitor.geometry;
                var gb = b.monitor.geometry;
                return ga.x != gb.x ? ga.x - gb.x : ga.y - gb.y;
            });
            foreach (var screen in screens) {
                bool twin = false;
                foreach (var other in screens) {
                    twin = twin || (other != screen && other.id == screen.id);
                }
                var geometry = screen.monitor.geometry;
                int scale = screen.monitor.scale_factor;
                string size = "%d × %d".printf (geometry.width * scale, geometry.height * scale);
                if (twin) {
                    var row = group.add_row (new Row (screen.name,
                        _("%s · The same model as another monitor. Polo tells them apart by serial number, which Polo Tweaks cannot see.").printf (size)));
                    row.sensitive = false;
                    continue;
                }
                var s = relocatable (MONITOR_SCHEMA, MONITOR_PATH + screen.id + "/");
                if (s != null) {
                    monitor_settings.add (s);
                    add_own (group, s, screen.name, _("%s · Give this monitor its own background").printf (size));
                }
            }
        }

        /* ---- Workspaces ------------------------------------------------------------- */

        private string workspace_name (int index) {
            string key = "name-%d".printf (index + 1);
            if (names != null && names.settings_schema.has_key (key)) {
                string name = names.get_string (key).strip ();
                if (name != "") {
                    return name;
                }
            }
            return _("Workspace %d").printf (index + 1);
        }

        private void build_workspaces () {
            var group = replace_group (workspaces, _("Per workspace"),
                                       _("Shown while the workspace is the current one, on every monitor without a background of its own."));
            if (!Schemas.installed (WORKSPACE_SCHEMA)) {
                return;
            }
            int count = marco != null ? marco.get_int ("num-workspaces").clamp (1, 36) : 4;
            for (int i = 0; i < count; i++) {
                var s = relocatable (WORKSPACE_SCHEMA, "%s%d/".printf (WORKSPACE_PATH, i + 1));
                if (s != null) {
                    add_own (group, s, workspace_name (i), _("Give this workspace its own background"));
                }
            }
        }
    }
}
