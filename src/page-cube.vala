/* The desktop cube. */

namespace PoloTweaks {

    public class CubePage : Page {
        public CubePage () {
            base ("cube", _("Desktop Cube"), "view-fullscreen-symbolic",
                  _("Switch workspaces by turning a 3D cube."),
                  _("Effects"));

            var fx = Schemas.get (Schemas.EFFECTS);
            var keys = Schemas.get (Schemas.KEYBINDINGS);
            set_master (fx, "cube");

            note (_("The cube needs Polo's GL renderer. Without it, workspaces switch as if the cube were off."),
                  "dialog-warning-symbolic");

            var shortcuts = group (_("Shortcuts"),
                                   _("These are the same shortcuts you find under Keyboard Shortcuts."));
            shortcuts.shortcut (keys, "cube", _("Show the cube"),
                                _("Opens the cube zoomed out, so you can turn it by hand and pick the workspace in front."));
            shortcuts.shortcut (keys, "cube-rotate-left", _("Turn left"),
                                _("Turns the cube one workspace to the left. The window manager's “switch to workspace left” shortcut also turns the cube."));
            shortcuts.shortcut (keys, "cube-rotate-right", _("Turn right"),
                                _("Turns the cube one workspace to the right."));
            shortcuts.pointer_shortcut (keys, "cube-drag", _("Turn with the mouse"),
                                        _("Hold the modifier keys and drag. Letting go lands on the workspace in front. Applications do not receive that click."));

            var looks = group (_("Appearance"));
            looks.choice (fx, "cube-deform", _("Shape of the sides"),
                          _("Bends the sides while you turn the cube by hand."),
                          { "none", "cylinder", "star" },
                          { _("Flat"), _("Cylinder"), _("Star (corners pulled out)") });
            looks.toggle (fx, "cube-light", _("Shade the sides"),
                          _("Darkens each side by how it faces the light in front of the screen."));

            var backdrop = group (_("Background"));
            backdrop.choice (fx, "cube-background", _("Behind the cube"), null,
                             { "solid", "wallpaper", "blurred-wallpaper", "skydome", "cubemap" },
                             { _("Solid colour"), _("Desktop background"), _("Blurred desktop background"),
                               _("Skydome (panorama image)"), _("Cubemap (box image)") });
            string[] bg = { "cube-background" };
            backdrop.colour (fx, "cube-background-color", _("Colour"))
                    .depends (fx, bg, (s) => s.get_string ("cube-background") == "solid");
            backdrop.image (fx, "cube-skydome-image", _("Panorama image"),
                            _("A wide image wrapped around the cube on a sphere. If it cannot be read, the solid colour is used."),
                            _("Choose a panorama image"))
                    .depends (fx, bg, (s) => s.get_string ("cube-background") == "skydome");
            backdrop.toggle (fx, "cube-skydome-mirror", _("Mirror the image"),
                             _("Shows the image twice around the sphere, the second time flipped, so its ends meet without a seam."))
                    .depends (fx, bg, (s) => s.get_string ("cube-background") == "skydome");
            backdrop.image (fx, "cube-cubemap-image", _("Cubemap image"),
                            _("An image shown on all six faces of a box around the cube. If it cannot be read, the solid colour is used."),
                            _("Choose a cubemap image"))
                    .depends (fx, bg, (s) => s.get_string ("cube-background") == "cubemap");
            backdrop.number (fx, "expo-background-blur", _("Blur"),
                             _("How far the desktop background is blurred. Expo uses the same blur."),
                             1, 100, 1, 0, _("px"))
                    .depends (fx, bg, (s) => s.get_string ("cube-background") == "blurred-wallpaper");

            var feel = group (_("Behaviour"));
            feel.number (fx, "cube-duration-ms", _("Turn duration"),
                         _("How long one turn of the cube takes, and zooming it in and out."), 50, 5000, 10, 0, _("ms"));
            feel.toggle (fx, "cube-natural-drag", _("Natural turning"),
                         _("The cube follows the pointer like a surface being pushed, instead of the view moving with it."));

            var adv = advanced_box (_("Advanced: fine tuning"));
            var tune = advanced_group (adv, null);
            tune.slider (fx, "cube-zoom", _("Zoom out while turning"),
                         _("How far the camera moves back while you turn the cube by hand; 0 does not zoom out."), 0.0, 5.0, 0.05);
            tune.slider (fx, "cube-speed-zoom", _("Scroll zoom step"),
                         _("How much one step of the scroll wheel zooms the cube."), 0.0, 1.0, 0.01);
            tune.slider (fx, "cube-speed-spin-horizontal", _("Horizontal turning speed"),
                         _("Radians the cube turns for each pixel the pointer moves across."), 0.0, 1.0, 0.005, 3);
            tune.slider (fx, "cube-speed-spin-vertical", _("Vertical tilting speed"),
                         _("How far the cube tilts for each pixel the pointer moves up or down."), 0.0, 1.0, 0.005, 3);
            tune.number (fx, "cube-mesh-spacing", _("Mesh spacing"),
                         _("Pixels between the points at which the sides are computed; smaller is smoother and slower. Bent sides use at least 30 points across."),
                         8, 256, 1, 0, _("px"));

            add_restore_button ();
        }
    }
}
