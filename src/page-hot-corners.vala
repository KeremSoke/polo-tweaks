/* Hot corners and edges: org.mate.polo.hot-corners, and each screen's own corners. */

namespace PoloTweaks {

    namespace HotActions {
        public const string[] IDS = { "none", "expo", "cube", "scale", "scale-all-workspaces", "scale-application",
                                      "scale-application-all-workspaces", "show-desktop", "window-switcher",
                                      "lock-screen", "run-dialog", "command" };

        public string label (string id) {
            switch (id) {
                case "expo": return _("Expo");
                case "cube": return _("Desktop cube");
                case "scale": return _("Scale: this workspace");
                case "scale-all-workspaces": return _("Scale: every workspace");
                case "scale-application": return _("Scale: this application");
                case "scale-application-all-workspaces": return _("Scale: this application, every workspace");
                case "show-desktop": return _("Show the desktop");
                case "window-switcher": return _("Window switcher");
                case "lock-screen": return _("Lock the screen");
                case "run-dialog": return _("Run application dialog");
                case "command": return _("Run a command");
                default: return _("Nothing");
            }
        }

        public string kind (string action) {
            string value = action.strip ();
            if (value.has_prefix ("command:")) {
                return "command";
            }
            return value == "" || !(value in IDS) ? "none" : value;
        }

        public string describe (string action) {
            string k = kind (action);
            if (k == "command") {
                string command = action.strip ().substring ("command:".length).strip ();
                return command == "" ? _("Run a command") : command;
            }
            return label (k);
        }

        public string strip_field_codes (string commandline) {
            var result = new StringBuilder ();
            string[] parts = commandline.split (" ");
            foreach (string part in parts) {
                if (part.length == 2 && part[0] == '%' && part[1] != '%') {
                    continue;
                }
                if (part == "") {
                    continue;
                }
                if (result.len > 0) {
                    result.append_c (' ');
                }
                result.append (part.replace ("%%", "%"));
            }
            return result.str;
        }

        public string? command_problem (string command) {
            string text = command.strip ();
            if (text == "") {
                return _("Type a command, or choose an application.");
            }
            string[] argv;
            try {
                Shell.parse_argv (text, out argv);
            } catch (ShellError e) {
                return _("The command cannot be read: %s").printf (e.message);
            }
            string program = argv[0];
            if (program.contains ("/")) {
                if (!FileUtils.test (program, FileTest.IS_EXECUTABLE) || FileUtils.test (program, FileTest.IS_DIR)) {
                    return _("“%s” is not a program.").printf (program);
                }
                return null;
            }
            if (Environment.find_program_in_path (program) == null) {
                return _("“%s” is not installed.").printf (program);
            }
            return null;
        }
    }

    public class HotCornerAction : Gtk.Box {
        private const string COMMAND = "command:";

        private Settings settings;
        private string key;
        private ulong changed_id = 0;
        private Gtk.ComboBoxText combo;
        private Gtk.Entry entry;
        private Gtk.Button choose;
        private bool busy = false;

        public HotCornerAction (Settings settings, string key) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            entry = new Gtk.Entry () { width_chars = 22, placeholder_text = _("Command") };
            choose = new Gtk.Button.from_icon_name ("view-app-grid-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Choose an application")
            };
            combo = new Gtk.ComboBoxText ();
            foreach (string id in HotActions.IDS) {
                combo.append (id, HotActions.label (id));
            }
            pack_start (entry, false, false, 0);
            pack_start (choose, false, false, 0);
            pack_start (combo, false, false, 0);

            combo.changed.connect (on_combo_changed);
            entry.activate.connect (store_command);
            entry.changed.connect (check_command);
            entry.focus_out_event.connect (() => {
                store_command ();
                return false;
            });
            choose.clicked.connect (choose_application);
            retarget (settings, key);
        }

        public Gtk.ComboBoxText get_combo () {
            return combo;
        }

        public Gtk.Entry get_entry () {
            return entry;
        }

        public void retarget (Settings settings, string key) {
            if (changed_id != 0) {
                this.settings.disconnect (changed_id);
            }
            this.settings = settings;
            this.key = key;
            changed_id = settings.changed[key].connect (refresh);
            refresh ();
        }

        public void edit_command () {
            combo.active_id = "command";
            entry.grab_focus ();
        }

        private void on_combo_changed () {
            if (busy || combo.active_id == null) {
                return;
            }
            if (combo.active_id == "command") {
                show_command (true);
                entry.grab_focus ();
                store_command ();
            } else {
                settings.set_string (key, combo.active_id);
            }
        }

        private void show_command (bool shown) {
            entry.no_show_all = !shown;
            choose.no_show_all = !shown;
            entry.visible = shown;
            choose.visible = shown;
        }

        private void check_command () {
            string? problem = HotActions.command_problem (entry.text);
            entry.secondary_icon_name = problem != null ? "dialog-warning-symbolic" : null;
            entry.secondary_icon_tooltip_text = problem;
        }

        private void store_command () {
            if (combo.active_id != "command") {
                return;
            }
            string value = COMMAND + entry.text.strip ();
            if (value != settings.get_string (key)) {
                settings.set_string (key, value);
            }
        }

        private void choose_application () {
            var dialog = new Gtk.AppChooserDialog.for_content_type (get_toplevel () as Gtk.Window,
                                                                   Gtk.DialogFlags.MODAL, "application/x-executable");
            dialog.heading = _("Choose the application this corner opens");
            var widget = dialog.get_widget () as Gtk.AppChooserWidget;
            if (widget != null) {
                widget.show_all = true;
                widget.show_default = false;
                widget.show_recommended = false;
                widget.show_fallback = false;
                widget.show_other = false;
            }
            if (dialog.run () == Gtk.ResponseType.OK) {
                var app = dialog.get_app_info ();
                if (app != null) {
                    string commandline = app.get_commandline () ?? app.get_executable ();
                    entry.text = HotActions.strip_field_codes (commandline);
                    store_command ();
                }
            }
            dialog.destroy ();
        }

        private void refresh () {
            busy = true;
            string value = settings.get_string (key).strip ();
            string kind = HotActions.kind (value);
            combo.active_id = kind;
            if (kind == "command") {
                if (!entry.has_focus) {
                    entry.text = value.substring (COMMAND.length).strip ();
                }
                show_command (true);
            } else {
                show_command (false);
            }
            check_command ();
            busy = false;
        }
    }

    public class HotCornerDelay : Gtk.Box {
        private Settings settings;
        private string spot;
        private Gtk.CheckButton own;
        private Gtk.SpinButton spin;
        private bool busy = false;

        public HotCornerDelay (Settings settings, string spot) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 8);
            this.settings = settings;
            this.spot = spot;
            own = new Gtk.CheckButton.with_label (_("Own delay"));
            spin = new Gtk.SpinButton.with_range (0, 10000, 50) { width_chars = 7 };
            var unit = new Gtk.Label (_("ms"));
            unit.get_style_context ().add_class ("row-subtitle");
            pack_start (own, false, false, 0);
            pack_start (spin, false, false, 0);
            pack_start (unit, false, false, 0);
            own.toggled.connect (store);
            spin.value_changed.connect (() => {
                if (own.active) {
                    store ();
                }
            });
            settings.changed["corner-delays"].connect (refresh);
            settings.changed["hover-delay"].connect (refresh);
            refresh ();
        }

        private void store () {
            if (busy) {
                return;
            }
            var builder = new VariantBuilder (new VariantType ("a{su}"));
            var iter = settings.get_value ("corner-delays").iterator ();
            string name;
            uint32 delay;
            while (iter.next ("{su}", out name, out delay)) {
                if (name != spot) {
                    builder.add ("{su}", name, delay);
                }
            }
            if (own.active) {
                builder.add ("{su}", spot, (uint32) spin.value);
            }
            settings.set_value ("corner-delays", builder.end ());
        }

        private void refresh () {
            busy = true;
            uint32 delay;
            bool is_own = settings.get_value ("corner-delays").lookup (spot, "u", out delay);
            own.active = is_own;
            spin.sensitive = is_own;
            spin.value = is_own ? delay : settings.get_uint ("hover-delay");
            busy = false;
        }
    }

    public delegate string HotActionLookup (int screen, int spot);
    public delegate bool HotOwnLookup (int screen);

    public class ScreenLayout : Gtk.DrawingArea {
        private const int MARGIN = 18;
        private const int GAP = 4;
        private const double MARKER = 8.0;
        private const double INSET = 14.0;

        public GenericArray<ScreenInfo> screens = new GenericArray<ScreenInfo> ();
        public int selected { get; private set; default = 0; }

        public signal void screen_selected (int index);
        public signal void spot_clicked (int index, int spot, Gdk.EventButton event);

        private Settings hot;
        private HotActionLookup action_for;
        private HotOwnLookup uses_own;
        private GenericArray<HotScreenSpots> spots = new GenericArray<HotScreenSpots> ();
        private int hover_screen = -1;
        private int hover_spot = -1;

        public ScreenLayout (Settings hot, owned HotActionLookup action_for, owned HotOwnLookup uses_own) {
            this.hot = hot;
            this.action_for = (owned) action_for;
            this.uses_own = (owned) uses_own;
            height_request = 230;
            hexpand = true;
            has_tooltip = true;
            add_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.POINTER_MOTION_MASK |
                        Gdk.EventMask.LEAVE_NOTIFY_MASK);
            get_accessible ().set_name (_("Screen arrangement"));
        }

        public void set_screens (GenericArray<ScreenInfo> screens) {
            this.screens = screens;
            if (selected >= screens.length) {
                selected = 0;
            }
            update ();
        }

        public void select (int index) {
            if (index < 0 || index >= screens.length) {
                return;
            }
            selected = index;
            queue_draw ();
            screen_selected (index);
        }

        public void update () {
            var rects = new Gdk.Rectangle[screens.length];
            var allowed = new bool[screens.length];
            for (int i = 0; i < screens.length; i++) {
                rects[i] = screens[i].geometry;
                allowed[i] = HotGeometry.screen_allowed (hot, screens[i]);
            }
            spots = HotGeometry.compute (rects, allowed, hot.get_string ("layout"));
            queue_draw ();
        }

        public bool spot_fires (int screen, int spot) {
            if (screen < 0 || screen >= spots.length || !hot.get_boolean ("enabled")) {
                return false;
            }
            var s = spots[screen];
            bool exists = spot < 4 ? s.corner[spot] : s.edges[spot - 4].length > 0;
            return exists && HotActions.kind (action_for (screen, spot)) != "none";
        }

        private void transform (out double scale, out double ox, out double oy) {
            int left = int.MAX, top = int.MAX, right = int.MIN, bottom = int.MIN;
            foreach (var screen in screens) {
                var g = screen.geometry;
                left = int.min (left, g.x);
                top = int.min (top, g.y);
                right = int.max (right, g.x + g.width);
                bottom = int.max (bottom, g.y + g.height);
            }
            double width = get_allocated_width () - 2 * MARGIN;
            double height = get_allocated_height () - 2 * MARGIN;
            double bw = double.max (1, right - left);
            double bh = double.max (1, bottom - top);
            scale = double.min (width / bw, height / bh);
            ox = MARGIN + (width - bw * scale) / 2 - left * scale;
            oy = MARGIN + (height - bh * scale) / 2 - top * scale;
        }

        private void screen_box (int index, double scale, double ox, double oy,
                                 out double x, out double y, out double w, out double h) {
            var g = screens[index].geometry;
            x = ox + g.x * scale + GAP / 2.0;
            y = oy + g.y * scale + GAP / 2.0;
            w = g.width * scale - GAP;
            h = g.height * scale - GAP;
        }

        private void marker (int spot, double x, double y, double w, double h, out double mx, out double my) {
            int dx = HotGeometry.dir_x (spot);
            int dy = HotGeometry.dir_y (spot);
            mx = dx < 0 ? x + INSET : (dx > 0 ? x + w - INSET : x + w / 2);
            my = dy < 0 ? y + INSET : (dy > 0 ? y + h - INSET : y + h / 2);
        }

        private bool hit (double px, double py, out int screen, out int spot) {
            screen = -1;
            spot = -1;
            if (screens.length == 0) {
                return false;
            }
            double scale, ox, oy;
            transform (out scale, out ox, out oy);
            for (int i = 0; i < screens.length; i++) {
                double x, y, w, h;
                screen_box (i, scale, ox, oy, out x, out y, out w, out h);
                if (px < x || px > x + w || py < y || py > y + h) {
                    continue;
                }
                screen = i;
                for (int s = 0; s < 8; s++) {
                    double mx, my;
                    marker (s, x, y, w, h, out mx, out my);
                    if ((px - mx) * (px - mx) + (py - my) * (py - my) <= (MARKER + 5) * (MARKER + 5)) {
                        spot = s;
                        return true;
                    }
                }
                return true;
            }
            return false;
        }

        public override bool button_press_event (Gdk.EventButton event) {
            int screen, spot;
            if (event.button != 1 && event.button != 3) {
                return false;
            }
            if (!hit (event.x, event.y, out screen, out spot)) {
                return false;
            }
            select (screen);
            if (spot >= 0) {
                spot_clicked (screen, spot, event);
            }
            return true;
        }

        public override bool motion_notify_event (Gdk.EventMotion event) {
            int screen, spot;
            hit (event.x, event.y, out screen, out spot);
            if (screen != hover_screen || spot != hover_spot) {
                hover_screen = screen;
                hover_spot = spot;
                var window = get_window ();
                if (window != null) {
                    window.cursor = screen >= 0 ? new Gdk.Cursor.from_name (get_display (), "pointer") : null;
                }
                queue_draw ();
            }
            return false;
        }

        public override bool leave_notify_event (Gdk.EventCrossing event) {
            hover_screen = -1;
            hover_spot = -1;
            queue_draw ();
            return false;
        }

        public override bool query_tooltip (int px, int py, bool keyboard, Gtk.Tooltip tooltip) {
            int screen, spot;
            if (!hit (px, py, out screen, out spot)) {
                return false;
            }
            if (spot < 0) {
                tooltip.set_text (_("%s — click to set up its corners").printf (screens[screen].name));
                return true;
            }
            string place = HotCornersPage.spot_title (spot);
            string what = HotActions.describe (action_for (screen, spot));
            if (!spot_fires (screen, spot) && HotActions.kind (action_for (screen, spot)) != "none") {
                tooltip.set_text (_("%s: %s (does not fire here)").printf (place, what));
            } else {
                tooltip.set_text ("%s: %s".printf (place, what));
            }
            return true;
        }

        private static Gdk.RGBA colour (Gtk.StyleContext style, string name, Gdk.RGBA fallback) {
            Gdk.RGBA c;
            return style.lookup_color (name, out c) ? c : fallback;
        }

        private static void rounded (Cairo.Context cr, double x, double y, double w, double h, double r) {
            cr.new_sub_path ();
            cr.arc (x + w - r, y + r, r, -Math.PI / 2, 0);
            cr.arc (x + w - r, y + h - r, r, 0, Math.PI / 2);
            cr.arc (x + r, y + h - r, r, Math.PI / 2, Math.PI);
            cr.arc (x + r, y + r, r, Math.PI, 3 * Math.PI / 2);
            cr.close_path ();
        }

        public override bool draw (Cairo.Context cr) {
            var style = get_style_context ();
            var fg = style.get_color (get_state_flags ());
            Gdk.RGBA accent_default = { 0.21, 0.52, 0.89, 1.0 };
            var accent = colour (style, "theme_selected_bg_color", accent_default);
            if (screens.length == 0) {
                var layout = create_pango_layout (_("No screens found"));
                int tw, th;
                layout.get_pixel_size (out tw, out th);
                cr.move_to ((get_allocated_width () - tw) / 2.0, (get_allocated_height () - th) / 2.0);
                Gdk.cairo_set_source_rgba (cr, fg);
                Pango.cairo_show_layout (cr, layout);
                return true;
            }
            double scale, ox, oy;
            transform (out scale, out ox, out oy);
            for (int i = 0; i < screens.length; i++) {
                double x, y, w, h;
                screen_box (i, scale, ox, oy, out x, out y, out w, out h);
                bool chosen = i == selected;
                bool on = i < spots.length && spots[i].allowed && hot.get_boolean ("enabled");
                rounded (cr, x, y, w, h, 6);
                cr.set_source_rgba (fg.red, fg.green, fg.blue, chosen ? 0.16 : (i == hover_screen ? 0.10 : 0.06));
                cr.fill_preserve ();
                if (chosen) {
                    cr.set_source_rgba (accent.red, accent.green, accent.blue, 1.0);
                    cr.set_line_width (2.5);
                } else {
                    cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.45);
                    cr.set_line_width (1.0);
                }
                cr.stroke ();

                for (int e = 0; e < 4 && i < spots.length; e++) {
                    int spot = 4 + e;
                    if (!spot_fires (i, spot)) {
                        continue;
                    }
                    bool horizontal = HotGeometry.dir_y (spot) != 0;
                    cr.set_source_rgba (accent.red, accent.green, accent.blue, 1.0);
                    foreach (var run in spots[i].edges[e]) {
                        double along = run.start * scale;
                        double length = run.length * scale;
                        if (horizontal) {
                            double ey = HotGeometry.dir_y (spot) < 0 ? y + 3 : y + h - 8;
                            cr.rectangle (x + along + 2 * INSET, ey, double.max (0, length - 4 * INSET - GAP), 5);
                        } else {
                            double ex = HotGeometry.dir_x (spot) < 0 ? x + 3 : x + w - 8;
                            cr.rectangle (ex, y + along + 2 * INSET, 5, double.max (0, length - 4 * INSET - GAP));
                        }
                    }
                    cr.fill ();
                }

                for (int s = 0; s < 8; s++) {
                    double mx, my;
                    marker (s, x, y, w, h, out mx, out my);
                    bool hovered = i == hover_screen && s == hover_spot;
                    bool fires = spot_fires (i, s);
                    bool set = HotActions.kind (action_for (i, s)) != "none";
                    if (s >= 4 && !hovered && !(chosen && set)) {
                        continue;
                    }
                    double r = s < 4 ? MARKER : MARKER - 2;
                    cr.arc (mx, my, r, 0, 2 * Math.PI);
                    if (fires) {
                        cr.set_source_rgba (accent.red, accent.green, accent.blue, 1.0);
                        cr.fill ();
                    } else {
                        cr.set_source_rgba (fg.red, fg.green, fg.blue, set ? 0.35 : (hovered ? 0.6 : 0.3));
                        cr.set_line_width (1.5);
                        if (set) {
                            cr.fill ();
                        } else {
                            cr.stroke ();
                        }
                    }
                    if (hovered) {
                        cr.arc (mx, my, r + 3, 0, 2 * Math.PI);
                        cr.set_source_rgba (accent.red, accent.green, accent.blue, 0.9);
                        cr.set_line_width (1.5);
                        cr.stroke ();
                    }
                }

                string status;
                if (!on) {
                    status = _("No hot corners");
                } else {
                    status = uses_own (i) ? _("Own corners") : _("Shared corners");
                }
                string title = screens[i].name + (screens[i].primary && screens.length > 1 ? " ★" : "");
                var layout = create_pango_layout (null);
                layout.set_markup ("<b>%s</b>\n<small>%s</small>".printf (Markup.escape_text (title),
                                                                         Markup.escape_text (status)), -1);
                double text_width = double.max (10, w - 4 * INSET - 2 * MARKER);
                layout.set_alignment (Pango.Alignment.CENTER);
                layout.set_width ((int) (text_width * Pango.SCALE));
                layout.set_ellipsize (Pango.EllipsizeMode.END);
                int tw, th;
                layout.get_pixel_size (out tw, out th);
                cr.move_to (x + (w - text_width) / 2.0, y + (h - th) / 2.0);
                cr.set_source_rgba (fg.red, fg.green, fg.blue, on ? 0.95 : 0.5);
                Pango.cairo_show_layout (cr, layout);
            }
            return true;
        }
    }

    public class HotCornersPage : Page {
        private Settings hot;
        private GenericArray<ScreenInfo> screens = new GenericArray<ScreenInfo> ();
        private HashTable<string, Settings> screen_settings = new HashTable<string, Settings> (str_hash, str_equal);
        private ScreenLayout layout;
        private Gtk.ComboBoxText screen_combo;
        private Gtk.Switch screen_on;
        private Gtk.Switch screen_own;
        private Group screen_group;
        private Row editing_row;
        private Gtk.Label editing_label;
        private HotCornerAction[] actions = {};
        private Row[] action_rows = {};
        private Row[] delay_rows = {};
        private Row screen_own_row;
        private Row layout_row;
        private Row screens_row;
        private bool busy = false;

        public static string spot_title (int spot) {
            string[] titles = { _("Top left"), _("Top right"), _("Bottom left"), _("Bottom right"),
                                _("Top edge"), _("Bottom edge"), _("Left edge"), _("Right edge") };
            return titles[spot];
        }

        private Settings? own_settings (string id) {
            var own = screen_settings.lookup (id);
            if (own == null) {
                own = Screens.settings_for (id);
                if (own != null) {
                    screen_settings.insert (id, own);
                    own.changed.connect (() => {
                        layout.update ();
                        sync_selection ();
                    });
                }
            }
            return own;
        }

        private bool uses_own (int screen) {
            if (screen < 0 || screen >= screens.length) {
                return false;
            }
            var own = own_settings (screens[screen].id);
            return own != null && !own.get_boolean ("use-shared");
        }

        public HotCornersPage () {
            base ("hot-corners", _("Hot Corners"), "input-mouse-symbolic",
                  _("Push the pointer into a screen corner or against an edge to open Expo, show the desktop, lock the screen or run a command."),
                  _("Desktop"));

            hot = Schemas.get (Schemas.HOT_CORNERS);
            set_master (hot, "enabled");
            animation_switch = add_header_switch (hot, "animation", _("Animation"),
                                                  _("Circles grow out of a corner when it fires, as when you locate the pointer with Ctrl: a quarter circle in a corner, a half circle on an edge."));

            layout = new ScreenLayout (hot, (screen, spot) => action_at (screen, spot), (screen) => uses_own (screen));
            var frame = new Gtk.Frame (null);
            frame.add (layout);
            body.pack_start (frame, false, false, 0);
            var legend = new Gtk.Label (_("Click a screen to set up its corners, or a corner to choose what it does. Filled corners fire; hollow ones do nothing.")) {
                xalign = 0, wrap = true, max_width_chars = 76
            };
            legend.get_style_context ().add_class ("row-subtitle");
            body.pack_start (legend, false, false, 0);

            screen_group = group (_("Screen"));
            screen_combo = new Gtk.ComboBoxText ();
            screen_group.add_row (new Row (_("Set up"), null, screen_combo));
            screen_on = new Gtk.Switch ();
            screen_group.add_row (new Row (_("Hot corners on this screen"),
                                           _("Off leaves this screen's corners and edges quiet."), screen_on));
            screen_own = new Gtk.Switch ();
            screen_own_row = screen_group.add_row (new Row (_("Own corners for this screen"),
                                           _("Off uses the shared corners, which every screen follows unless it has its own."),
                                           screen_own));

            var start = group (_("Start from"),
                               _("Fills in the shared settings with a ready-made combination, with the top left corner opening Expo. You can change any of them afterwards."));
            start.add_row (new Row (_("Ready-made setup"), null, presets ()));

            var corners = group (_("Corners and edges"));
            editing_label = new Gtk.Label ("");
            editing_label.get_style_context ().add_class ("row-subtitle");
            editing_row = corners.add_row (new Row (_("Editing"), null, editing_label));
            for (int i = 0; i < HOT_SPOTS.length; i++) {
                var action = new HotCornerAction (hot, HOT_SPOTS[i]);
                actions += action;
                action_rows += corners.add_row (new Row (spot_title (i),
                                                         i >= 4 ? _("Only where no other screen lies beyond it.") : null,
                                                         action).track (hot, HOT_SPOTS[i]));
            }

            var trigger = group (_("How a corner fires"));
            trigger.choice (hot, "trigger", _("Fire by"),
                            _("Pushing fires when the pointer is pushed against the screen edge, so a pointer only passing by never fires it. Resting fires after the pointer stays there for the resting delay. Corners between two screens, drawing tablets and virtual machines always use resting."),
                            { "pressure", "hover" }, { _("Pushing against the edge"), _("Resting in the corner") });
            trigger.add_row (new Row (_("Push needed"), _("How hard to push before a corner fires."),
                                      marked_scale ("pressure-threshold", 20, 600, 10,
                                                    { 50, 100, 250, 500 },
                                                    { _("Light"), _("Normal"), _("Firm"), _("Very firm") }, _("px")))
                             .track (hot, "pressure-threshold"))
                   .depends (hot, new string[] { "trigger" }, (s) => s.get_string ("trigger") == "pressure", false);
            trigger.add_row (new Row (_("Resting delay"), _("How long the pointer must rest in a corner."),
                                      marked_scale ("hover-delay", 0, 2000, 50,
                                                    { 0, 150, 700, 1500 },
                                                    { _("At once"), _("Quick"), _("Relaxed"), _("Slow") }, _("ms")))
                             .track (hot, "hover-delay"));
            trigger.toggle (hot, "click", _("Fire on click too"),
                            _("A left click on the corner fires it. The click does not reach the window or panel under it."));
            trigger.toggle (hot, "fullscreen", _("Fire over fullscreen windows"),
                            _("Off keeps corners quiet while a game or video covers them."));

            var arrangement = group (_("Several screens"));
            layout_row = arrangement.choice (hot, "layout", _("Which corners"),
                                _("“Outer corners” leaves out the corners where two screens meet, so moving to the next screen never fires anything."),
                                { "outer", "every-screen", "whole-area" },
                                { _("Outer corners only"), _("Every corner of every screen"),
                                  _("Four corners of all screens together") });
            screens_row = arrangement.choice (hot, "screens", _("Screens with hot corners"),
                                _("With the primary or chosen screens only, a projector or another monitor plugged in later gets no hot corners."),
                                { "all", "primary", "selected" },
                                { _("Every screen"), _("The primary screen"), _("Chosen screens") });

            var adv = advanced_box ();
            var timing = advanced_group (adv, _("Timing"));
            timing.number (hot, "pressure-time", _("Push within"),
                           _("The push must add up within this time."), 50, 10000, 50, 0, _("ms"))
                  .depends (hot, new string[] { "trigger" }, (s) => s.get_string ("trigger") == "pressure", false);
            timing.number (hot, "cooldown", _("Cooldown"),
                           _("The least time before the same corner can fire again."), 0, 10000, 50, 0, _("ms"));
            var delays = advanced_group (adv, _("Resting delay per corner"),
                                         _("A corner or edge with its own delay ignores the resting delay."));
            for (int i = 0; i < HOT_SPOTS.length; i++) {
                delay_rows += delays.add_row (new Row (spot_title (i), null, new HotCornerDelay (hot, HOT_SPOTS[i]))
                                              .track (hot, "corner-delays"));
            }
            var ids = advanced_group (adv, _("Chosen screens by id"),
                                      _("Every screen chosen, also those not connected now. Ids are the ones mate-monitor-info shows."));
            ids.string_list (hot, "selected-screens", _("Screens"), null)
               .depends (hot, new string[] { "screens" }, (s) => s.get_string ("screens") == "selected", false);

            add_restore_button ();

            screen_combo.changed.connect (() => {
                if (!busy && screen_combo.active >= 0) {
                    layout.select (screen_combo.active);
                }
            });
            screen_on.notify["active"].connect (() => {
                if (!busy && layout.selected < screens.length) {
                    HotGeometry.set_screen_allowed (hot, screens, screens[layout.selected], screen_on.active);
                }
            });
            screen_own.notify["active"].connect (() => {
                if (busy || layout.selected >= screens.length) {
                    return;
                }
                var own = own_settings (screens[layout.selected].id);
                if (own != null) {
                    own.set_boolean ("use-shared", !screen_own.active);
                }
            });
            layout.screen_selected.connect ((index) => sync_selection ());
            layout.spot_clicked.connect (show_spot_menu);
            hot.changed.connect (() => {
                layout.update ();
                sync_selection ();
                show_preset ();
            });
            ScreenWatcher.get_default ().changed.connect (reload_screens);
            reload_screens ();
            show_preset ();
        }

        private static void show_section (Gtk.Widget widget, bool shown) {
            widget.no_show_all = !shown;
            if (shown) {
                widget.show_all ();
            } else {
                widget.hide ();
            }
        }

        public bool screen_section_shown () {
            return screen_combo.get_mapped () && screen_on.get_mapped () && screen_own.get_mapped ();
        }

        public void reload_screens_for_test (GenericArray<ScreenInfo> fake) {
            screens = fake;
            layout.set_screens (screens);
            busy = true;
            screen_combo.remove_all ();
            foreach (var screen in screens) {
                screen_combo.append_text (screen.name);
            }
            busy = false;
            show_section (screen_group, screens.length > 1);
            sync_selection ();
        }

        private bool spot_used (int spot) {
            if (HotActions.kind (hot.get_string (HOT_SPOTS[spot])) != "none") {
                return true;
            }
            foreach (var screen in screens) {
                var own = own_settings (screen.id);
                if (own != null && !own.get_boolean ("use-shared") &&
                    HotActions.kind (own.get_string (HOT_SPOTS[spot])) != "none") {
                    return true;
                }
            }
            return false;
        }

        public Row get_action_row (int spot) {
            return action_rows[spot];
        }

        public Row get_delay_row (int spot) {
            return delay_rows[spot];
        }

        public Row get_screen_own_row () {
            return screen_own_row;
        }

        public Row get_layout_row () {
            return layout_row;
        }

        public Gtk.Switch get_screen_on () {
            return screen_on;
        }

        private Settings target_settings (int screen) {
            if (screen >= 0 && screen < screens.length) {
                var own = own_settings (screens[screen].id);
                if (own != null && !own.get_boolean ("use-shared")) {
                    return own;
                }
            }
            return hot;
        }

        private string action_at (int screen, int spot) {
            return target_settings (screen).get_string (HOT_SPOTS[spot]);
        }

        private void reload_screens () {
            screens = Screens.connected ();
            layout.set_screens (screens);
            busy = true;
            screen_combo.remove_all ();
            foreach (var screen in screens) {
                screen_combo.append_text (screen.primary && screens.length > 1
                                          ? _("%s (primary)").printf (screen.name) : screen.name);
            }
            busy = false;
            show_section (screen_group, screens.length > 1);
            sync_selection ();
        }

        private void sync_selection () {
            busy = true;
            int index = layout.selected;
            bool has_screen = index < screens.length;
            screen_combo.active = has_screen ? index : -1;
            if (has_screen) {
                var screen = screens[index];
                screen_on.active = HotGeometry.screen_allowed (hot, screen);
                var own = own_settings (screen.id);
                screen_own_row.sensitive = own != null && screen_on.active;
                screen_own.active = own != null && !own.get_boolean ("use-shared");
            }
            var target = target_settings (index);
            bool quiet = target != hot && has_screen && !screen_on.active;
            for (int i = 0; i < actions.length; i++) {
                actions[i].retarget (target, HOT_SPOTS[i]);
                action_rows[i].sensitive = !quiet;
            }
            for (int i = 0; i < delay_rows.length; i++) {
                delay_rows[i].sensitive = spot_used (i);
            }
            layout_row.sensitive = screens.length > 1;
            screens_row.sensitive = screens.length > 1;
            if (target == hot) {
                editing_label.label = screens.length > 1 ? _("The shared corners, for every screen") : _("This screen's corners");
            } else {
                editing_label.label = _("%s only").printf (screens[index].name);
            }
            show_section (editing_row, screens.length > 1);
            busy = false;
        }

        private void show_spot_menu (int screen, int spot, Gdk.EventButton event) {
            var target = target_settings (screen);
            string current = HotActions.kind (target.get_string (HOT_SPOTS[spot]));
            var menu = new Gtk.Menu ();
            var heading = new Gtk.MenuItem.with_label (spot_title (spot)) { sensitive = false };
            menu.append (heading);
            menu.append (new Gtk.SeparatorMenuItem ());
            foreach (string id in HotActions.IDS) {
                var item = new Gtk.CheckMenuItem.with_label (id == "command" ? _("Run a command…") : HotActions.label (id)) {
                    draw_as_radio = true, active = id == current
                };
                string chosen = id;
                item.activate.connect (() => {
                    if (chosen == "command") {
                        actions[spot].edit_command ();
                    } else {
                        target.set_string (HOT_SPOTS[spot], chosen);
                    }
                });
                menu.append (item);
            }
            menu.show_all ();
            menu.attach_to_widget (layout, null);
            menu.popup_at_pointer (event);
        }

        private Gtk.Widget marked_scale (string key, double min, double max, double step, double[] marks,
                                         string[] labels, string unit) {
            var scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step) {
                draw_value = true, digits = 0, value_pos = Gtk.PositionType.RIGHT, width_request = 300
            };
            for (int i = 0; i < marks.length; i++) {
                scale.add_mark (marks[i], Gtk.PositionType.BOTTOM, labels[i]);
            }
            scale.format_value.connect ((value) => "%.0f %s".printf (value, unit));
            hot.bind (key, scale.adjustment, "value", SettingsBindFlags.DEFAULT);
            return scale;
        }

        private const string[] PRESETS = { "push-outer", "rest-every", "primary-only", "whole-desk" };
        private const string[] PRESET_RESET = { "top-right", "bottom-left", "bottom-right", "top", "bottom", "left",
                                                "right", "corner-delays", "click", "fullscreen", "selected-screens",
                                                "pressure-threshold", "pressure-time", "cooldown", "hover-delay" };
        private Gtk.ComboBoxText preset_combo;
        private Gtk.Switch animation_switch;

        public Gtk.Switch get_animation_switch () {
            return animation_switch;
        }

        private HashTable<string, Variant> preset_values (string id) {
            var values = new HashTable<string, Variant> (str_hash, str_equal);
            foreach (string key in PRESET_RESET) {
                values.insert (key, hot.get_default_value (key));
            }
            values.insert ("top-left", new Variant.string ("expo"));
            switch (id) {
                case "push-outer":
                    values.insert ("trigger", new Variant.string ("pressure"));
                    values.insert ("layout", new Variant.string ("outer"));
                    values.insert ("screens", new Variant.string ("all"));
                    break;
                case "rest-every":
                    values.insert ("trigger", new Variant.string ("hover"));
                    values.insert ("hover-delay", new Variant.uint32 (75));
                    values.insert ("layout", new Variant.string ("every-screen"));
                    values.insert ("screens", new Variant.string ("all"));
                    break;
                case "primary-only":
                    values.insert ("trigger", new Variant.string ("hover"));
                    values.insert ("hover-delay", new Variant.uint32 (0));
                    values.insert ("click", new Variant.boolean (true));
                    values.insert ("layout", new Variant.string ("outer"));
                    values.insert ("screens", new Variant.string ("primary"));
                    break;
                default:
                    values.insert ("trigger", new Variant.string ("hover"));
                    values.insert ("layout", new Variant.string ("whole-area"));
                    values.insert ("screens", new Variant.string ("all"));
                    break;
            }
            return values;
        }

        public string current_preset () {
            foreach (string id in PRESETS) {
                bool same = true;
                preset_values (id).foreach ((key, value) => {
                    if (!hot.get_value (key).equal (value)) {
                        same = false;
                    }
                });
                if (same) {
                    return id;
                }
            }
            return "custom";
        }

        private void show_preset () {
            busy = true;
            preset_combo.active_id = current_preset ();
            busy = false;
        }

        private Gtk.Widget presets () {
            preset_combo = new Gtk.ComboBoxText ();
            preset_combo.append ("custom", _("Custom"));
            preset_combo.append ("push-outer", _("Push into an outer corner"));
            preset_combo.append ("rest-every", _("Rest in any corner of any screen"));
            preset_combo.append ("primary-only", _("Rest or click, primary screen only"));
            preset_combo.append ("whole-desk", _("Rest in the four corners of all screens together"));
            preset_combo.changed.connect (() => {
                string? id = preset_combo.active_id;
                if (busy || id == null || id == "custom") {
                    return;
                }
                apply_preset (id);
            });
            return preset_combo;
        }

        public void apply_preset (string id) {
            hot.delay ();
            preset_values (id).foreach ((key, value) => hot.set_value (key, value));
            hot.set_boolean ("enabled", true);
            hot.apply ();
        }

        public Gtk.ComboBoxText get_preset_combo () {
            return preset_combo;
        }

        public override void restore_defaults () {
            base.restore_defaults ();
            foreach (var screen in screens) {
                var own = own_settings (screen.id);
                if (own != null) {
                    Schemas.reset_schema (own);
                }
            }
        }

        public ScreenLayout get_layout () {
            return layout;
        }

        public void select_screen (int index) {
            layout.select (index);
        }

        public HotCornerAction get_action (int spot) {
            return actions[spot];
        }
    }
}
