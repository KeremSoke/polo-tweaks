/* Scale: windows spread out side by side, org.mate.polo.scale. */

namespace PoloTweaks {

    namespace ScaleModes {
        public const string[] IDS = { "workspace", "all-workspaces", "application", "application-all-workspaces" };
        public const string[] KEYS = { "scale", "scale-all-workspaces", "scale-application",
                                       "scale-application-all-workspaces" };

        public string title (int index) {
            switch (index) {
                case 1: return _("Windows of every workspace");
                case 2: return _("Windows of the focused application");
                case 3: return _("Windows of the focused application, every workspace");
                default: return _("Windows of this workspace");
            }
        }

        public string hint (int index) {
            switch (index) {
                case 1: return _("Also shows the windows on other workspaces; picking one goes to its workspace or brings it here.");
                case 2: return _("Only the windows of the application you are using, on this workspace.");
                case 3: return _("Only the windows of the application you are using, on every workspace.");
                default: return _("Every window on the workspace you are on.");
            }
        }
    }

    public class ScaleModeScreens : Gtk.ComboBoxText {
        private Settings settings;
        private string mode;
        private bool busy = false;

        public ScaleModeScreens (Settings settings, string mode) {
            this.settings = settings;
            this.mode = mode;
            append ("", _("As above"));
            append ("summoned", _("Only the screen it was opened on"));
            append ("each", _("Every screen, its own windows"));
            append ("mirrored", _("Every screen, every window"));
            changed.connect (store);
            settings.changed["mode-screens"].connect (refresh);
            refresh ();
        }

        private void store () {
            if (busy) {
                return;
            }
            var builder = new VariantBuilder (new VariantType ("a{ss}"));
            var iter = settings.get_value ("mode-screens").iterator ();
            string name, value;
            while (iter.next ("{ss}", out name, out value)) {
                if (name != mode) {
                    builder.add ("{ss}", name, value);
                }
            }
            if (active_id != null && active_id != "") {
                builder.add ("{ss}", mode, active_id);
            }
            settings.set_value ("mode-screens", builder.end ());
        }

        private void refresh () {
            busy = true;
            string? value = null;
            if (!settings.get_value ("mode-screens").lookup (mode, "s", out value) ||
                !(value in new string[] { "summoned", "each", "mirrored" })) {
                value = "";
            }
            active_id = value;
            busy = false;
        }
    }

    public class ScalePage : Page {
        public ScalePage () {
            base ("scale", _("Scale"), "view-app-grid-symbolic",
                  _("Spread out windows side by side, scaled down so none overlap, to pick one."),
                  _("Effects"));

            var scale = Schemas.get (Schemas.SCALE);
            var keys = Schemas.get (Schemas.KEYBINDINGS);
            set_master (scale, "enabled");

            var open = group (_("Shortcuts"),
                              _("Each kind of Scale has its own shortcut. Hot corners can open any of them too."));
            for (int i = 0; i < ScaleModes.KEYS.length; i++) {
                if (keys != null && keys.settings_schema.has_key (ScaleModes.KEYS[i])) {
                    open.shortcut (keys, ScaleModes.KEYS[i], ScaleModes.title (i), ScaleModes.hint (i));
                }
            }
            open.toggle (scale, "hold", _("Hold the shortcut's modifier"),
                         _("Scale stays open while you hold the modifier, and letting go picks the selected window, as Alt+Tab does."));

            var screens = group (_("Screens"));
            screens.choice (scale, "screens", _("Where Scale shows"),
                            _("“Only the screen it was opened on” uses the screen under the pointer, or the hot corner's screen."),
                            { "summoned", "each", "mirrored" },
                            { _("Only the screen it was opened on"), _("Every screen, its own windows"),
                              _("Every screen, every window") });
            screens.choice (scale, "summoned-windows", _("Windows on that screen"), null,
                            { "this-screen", "every-screen" },
                            { _("Only its own windows"), _("The windows of every screen") })
                   .depends (scale, new string[] { "screens" }, (s) => s.get_string ("screens") == "summoned");
            for (int i = 0; i < ScaleModes.IDS.length; i++) {
                screens.add_row (new Row (ScaleModes.title (i), _("Where this kind of Scale shows."),
                                          new ScaleModeScreens (scale, ScaleModes.IDS[i]))
                                 .track (scale, "mode-screens"));
            }

            var layout = group (_("Layout"));
            layout.choice (scale, "layout", _("Arrange windows"),
                           _("“Near where they are” pushes windows apart only as far as needed."),
                           { "natural", "grid" }, { _("Near where they are"), _("In rows") });
            layout.choice (scale, "all-workspaces-layout", _("Windows of every workspace"), null,
                           { "grouped", "mixed" }, { _("A band per workspace, with its name"), _("All together") });
            layout.number (scale, "spacing", _("Space between windows"), null, 0, 200, 1, 0, _("px"));
            layout.number (scale, "duration-ms", _("Animation"), null, 1, 5000, 10, 0, _("ms"));
            layout.toggle (scale, "window-titles", _("Show window titles"), null);
            layout.choice (scale, "minimized", _("Minimized windows"), null,
                           { "show", "dimmed", "hide" }, { _("Show"), _("Show faded"), _("Leave out") });

            var clicks = group (_("Picking"));
            clicks.choice (scale, "other-workspace", _("A window on another workspace"), null,
                           { "switch", "bring" }, { _("Go to its workspace"), _("Bring it here") });
            clicks.choice (scale, "empty-click", _("Clicking between windows"), null,
                           { "close", "show-desktop" }, { _("Closes Scale"), _("Shows the desktop") });
            clicks.choice (scale, "middle-click", _("Middle click on a window"), null,
                           { "close-window", "none" }, { _("Closes the window"), _("Does nothing") });

            var backdrop = group (_("Background"));
            backdrop.choice (scale, "background", _("Behind the windows"), null,
                             { "solid", "wallpaper", "blurred-wallpaper" },
                             { _("Dark grey"), _("Desktop background"), _("Blurred desktop background") });
            backdrop.number (scale, "background-blur", _("Blur"), null, 1, 100, 1, 0, _("px"))
                    .depends (scale, new string[] { "background" },
                              (s) => s.get_string ("background") == "blurred-wallpaper");
            backdrop.slider (scale, "background-dim", _("Dimming"),
                             _("How much darker the background is drawn: 0 as it is, 1 black."), 0.0, 1.0, 0.05)
                    .depends (scale, new string[] { "background" }, (s) => s.get_string ("background") != "solid");

            add_restore_button ();
        }
    }
}
