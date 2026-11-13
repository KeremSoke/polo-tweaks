/* Expo: every workspace side by side. */

namespace PoloTweaks {

    public class ExpoPage : Page {
        public ExpoPage () {
            base ("expo", _("Expo"), "view-grid-symbolic",
                  _("See every workspace side by side, to pick one or drag windows between them."),
                  _("Effects"));

            var fx = Schemas.get (Schemas.EFFECTS);
            var keys = Schemas.get (Schemas.KEYBINDINGS);
            set_master (fx, "expo");

            var open = group (_("Shortcut"));
            open.shortcut (keys, "expo", _("Show Expo"),
                           _("Also available under Keyboard Shortcuts."));

            var layout = group (_("Layout"));
            layout.choice (fx, "expo-layout", _("Arrange workspaces"),
                           _("“Like the workspace switcher” keeps the rows and columns you set in MATE's workspace settings."),
                           { "workspaces", "row", "grid" },
                           { _("Like the workspace switcher"), _("In a single row"), _("In a square grid") });
            layout.toggle (fx, "expo-workspace-names", _("Show workspace names"),
                           _("Writes each workspace's name under it."));
            layout.slider (fx, "expo-label-opacity", _("Name box opacity"),
                           _("0 shows only the text; 1 is a solid box."), 0.0, 1.0, 0.05)
                  .depends (fx, new string[] { "expo-workspace-names" }, (s) => s.get_boolean ("expo-workspace-names"));
            layout.number (fx, "expo-label-radius", _("Name box corner radius"),
                           _("0 gives square corners."), 0, 32, 1, 0, _("px"))
                  .depends (fx, new string[] { "expo-workspace-names" }, (s) => s.get_boolean ("expo-workspace-names"));

            var backdrop = group (_("Background"));
            backdrop.choice (fx, "expo-background", _("Behind the workspaces"), null,
                             { "solid", "wallpaper", "blurred-wallpaper" },
                             { _("Dark grey"), _("Desktop background"), _("Blurred desktop background") });
            backdrop.number (fx, "expo-background-blur", _("Blur"),
                             _("How far the desktop background is blurred. The desktop cube uses the same blur."),
                             1, 100, 1, 0, _("px"))
                    .depends (fx, new string[] { "expo-background" }, (s) => s.get_string ("expo-background") == "blurred-wallpaper");
            backdrop.slider (fx, "expo-background-dim", _("Dimming"),
                             _("How much darker the background is drawn: 0 as it is, 1 black."), 0.0, 1.0, 0.05)
                    .depends (fx, new string[] { "expo-background" }, (s) => s.get_string ("expo-background") != "solid");

            add_restore_button ();
        }
    }
}
