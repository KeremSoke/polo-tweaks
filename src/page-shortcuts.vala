/* Keyboard shortcuts: every key of org.mate.polo.keybindings in one place. */

namespace PoloTweaks {

    public class ShortcutsPage : Page {
        public ShortcutsPage () {
            base ("shortcuts", _("Keyboard Shortcuts"), "input-keyboard-symbolic",
                  _("Click a shortcut, then press the keys you want. Backspace turns it off, Esc cancels."),
                  _("Input"));

            var keys = Schemas.get (Schemas.KEYBINDINGS);
            var fx = Schemas.get (Schemas.EFFECTS);

            var effects = group (_("Effects"));
            effects.shortcut (keys, "expo", _("Show Expo"),
                              _("Shows every workspace side by side."))
                   .depends (fx, new string[] { "expo" }, (s) => s.get_boolean ("expo"), false);
            effects.shortcut (keys, "cube", _("Show the desktop cube"),
                              _("Opens the cube zoomed out, to turn it by hand."))
                   .depends (fx, new string[] { "cube" }, (s) => s.get_boolean ("cube"), false);
            effects.shortcut (keys, "cube-rotate-left", _("Turn the cube left"),
                              _("Turns the cube one workspace to the left."))
                   .depends (fx, new string[] { "cube" }, (s) => s.get_boolean ("cube"), false);
            effects.shortcut (keys, "cube-rotate-right", _("Turn the cube right"),
                              _("Turns the cube one workspace to the right."))
                   .depends (fx, new string[] { "cube" }, (s) => s.get_boolean ("cube"), false);
            effects.pointer_shortcut (keys, "cube-drag", _("Turn the cube with the mouse"),
                                      _("Hold the modifier keys and drag with the chosen mouse button."))
                   .depends (fx, new string[] { "cube" }, (s) => s.get_boolean ("cube"), false);
            var scale = Schemas.get (Schemas.SCALE);
            for (int i = 0; i < ScaleModes.KEYS.length; i++) {
                if (scale == null || !keys.settings_schema.has_key (ScaleModes.KEYS[i])) {
                    continue;
                }
                effects.shortcut (keys, ScaleModes.KEYS[i], ScaleModes.title (i), ScaleModes.hint (i))
                       .depends (scale, new string[] { "enabled" }, (s) => s.get_boolean ("enabled"), false);
            }
            note (_("Shortcuts that are greyed out belong to an effect that is turned off. Turn it on under Effects."));

            var display = group (_("Screens"));
            display.shortcut (keys, "display-mode", _("Choose how the screens are used"),
                              _("Opens the display popup when two or more screens are connected. Press it again while holding the modifier to move on; let go to apply. The laptop's display key does the same."));

            var access = group (_("Accessibility"));
            access.shortcut (keys, "magnifier", _("Turn the magnifier on or off"),
                             _("Magnifies every screen, following the pointer and the focused window."));
            access.shortcut (keys, "magnifier-zoom-in", _("Magnify more"),
                             _("Raises the magnification by one step, turning the magnifier on if it is off."));
            access.shortcut (keys, "magnifier-zoom-out", _("Magnify less"),
                             _("Lowers the magnification by one step, down to 1×."));

            add_restore_button ();
        }
    }
}
