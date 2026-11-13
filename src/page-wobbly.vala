/* Wobbly Windows. */

namespace PoloTweaks {

    public class WobblyPage : Page {
        /* The preset table of Polo's wobbly effect (lib/fx/wobbly-presets.c). */
        private const double[] PRESET_STIFFNESS = { 0.15, 0.10, 0.06, 0.03, 0.01 };
        private const double[] PRESET_DRAG = { 0.80, 0.85, 0.90, 0.92, 0.97 };
        private const double[] PRESET_MOVE = { 0.10, 0.10, 0.10, 0.20, 0.25 };

        private static int level_of (Settings s) {
            return int.max (0, int.min (4, s.get_int ("wobbly-level")));
        }

        public WobblyPage () {
            base ("wobbly", _("Wobbly Windows"), "applications-graphics-symbolic",
                  _("Windows behave like jelly while you move or resize them."),
                  _("Effects"));

            var fx = Schemas.get (Schemas.EFFECTS);
            set_master (fx, "wobbly-windows");

            var when = group (_("When to wobble"));
            when.toggle (fx, "wobbly-move", _("While moving a window"));
            when.toggle (fx, "wobbly-resize", _("While resizing a window"));

            var feel = group (_("Feel"));
            feel.preset (fx, "wobbly-level", _("Style"),
                         _("From a firm, quick spring to very loose jelly."),
                         { _("Default"), _("Subtle"), _("Gentle"), _("Bouncy"), _("Jelly") });

            var adv = advanced_box (_("Advanced: tune the spring"));
            var spring = advanced_group (adv, _("Spring"),
                                         _("Untick “Custom” to follow the style chosen above."));
            spring.override_number (fx, "wobbly-stiffness", _("Stiffness"),
                                    _("Higher is a firmer spring that snaps back faster."),
                                    0.001, 1.0, 0.005, 3, (s) => PRESET_STIFFNESS[level_of (s)]);
            spring.override_number (fx, "wobbly-drag", _("Drag"),
                                    _("Higher keeps the window moving for longer."),
                                    0.0, 0.999, 0.005, 3, (s) => PRESET_DRAG[level_of (s)]);
            spring.override_number (fx, "wobbly-move-factor", _("Movement factor"),
                                    _("How strongly the window follows the pointer."),
                                    0.0, 1.0, 0.01, 2, (s) => PRESET_MOVE[level_of (s)]);
            spring.number (fx, "wobbly-mesh-spacing", _("Mesh spacing"),
                           _("Pixels between the points of the deformation grid; smaller is smoother and slower."),
                           1, 500, 1, 0, _("px"));

            var limits = advanced_group (adv, _("Limits"),
                                         _("Where the simulation reacts and where it settles."));
            limits.number (fx, "wobbly-min-velocity", _("Minimum velocity"), null, 0, 100000, 1, 1);
            limits.number (fx, "wobbly-max-velocity", _("Maximum velocity"), null, 0, 100000, 10, 1);
            limits.number (fx, "wobbly-stop-velocity", _("Stop velocity"),
                           _("Below this velocity the window can settle."), 0, 100000, 0.1, 2);
            limits.number (fx, "wobbly-min-acceleration", _("Minimum acceleration"), null, 0, 100000, 1, 1);
            limits.number (fx, "wobbly-max-acceleration", _("Maximum acceleration"), null, 0, 100000, 10, 1);
            limits.number (fx, "wobbly-stop-acceleration", _("Stop acceleration"),
                           _("Below this acceleration the window can settle."), 0, 100000, 0.1, 2);

            add_restore_button ();
        }
    }
}
