/* The desktop background, as MATE stores it in org.mate.background. */

namespace PoloTweaks {

    public class BackgroundPage : Page {
        public BackgroundPage () {
            base ("background", _("Background"), "preferences-desktop-wallpaper-symbolic",
                  _("The desktop background MATE applications and Polo share."),
                  _("Desktop"));

            var bg = Schemas.get (Schemas.BACKGROUND);

            var picture = group (_("Picture"));
            picture.image (bg, "picture-filename", _("Image"),
                           _("Leave empty to show only the colours below."),
                           _("Choose a background image"));
            picture.choice (bg, "picture-options", _("Fit"), null,
                            { "zoom", "scaled", "stretched", "centered", "wallpaper", "spanned" },
                            { _("Zoom (fill, cropping the edges)"), _("Scale (fit inside)"), _("Stretch"),
                              _("Centre"), _("Tile"), _("Span across all monitors") });

            var colours = group (_("Colours"), _("Shown where the image does not cover the screen, or instead of it."));
            colours.choice (bg, "color-shading-type", _("Fill"), null,
                            { "solid", "horizontal-gradient", "vertical-gradient" },
                            { _("Solid colour"), _("Horizontal gradient"), _("Vertical gradient") });
            colours.colour (bg, "primary-color", _("Colour"));
            string[] shading = { "color-shading-type" };
            colours.colour (bg, "secondary-color", _("Second colour"))
                   .depends (bg, shading, (s) => s.get_string ("color-shading-type") != "solid");

            var drawing = group (_("Who draws it"));
            drawing.toggle (bg, "draw-background", _("Let the desktop draw the background"),
                            _("When on, Caja draws the background behind its icons, and Polo draws it while no desktop is running. When off, Caja shows only its icons and Polo draws the background under them. That needs a Caja that knows Polo draws the background; an older Caja keeps drawing it."));

            add_restore_button ();
        }
    }
}
