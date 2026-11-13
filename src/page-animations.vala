/* Window animations: opening, closing and minimising. */

namespace PoloTweaks {

    public class AnimationsPage : Page {
        public AnimationsPage () {
            base ("animations", _("Window Animations"), "media-playback-start-symbolic",
                  _("How windows appear, disappear and go into the taskbar."),
                  _("Effects"));

            var fx = Schemas.get (Schemas.EFFECTS);

            string[] open_ids = { "none", "fade", "zoom", "zap", "spin" };
            string[] open_names = { _("None"), _("Fade"), _("Zoom"), _("Zap"), _("Spin") };

            var kinds = group (_("Animation"));
            kinds.choice (fx, "open-animation", _("When a window opens"),
                          _("Fade, Zoom (grows from a third of its size), Zap (fades in, then stretches across and down) or Spin (turns in from a point)."),
                          open_ids, open_names);
            kinds.choice (fx, "close-animation", _("When a window closes"),
                          _("The opening animations, played backwards."),
                          open_ids, open_names);
            kinds.choice (fx, "minimize-animation", _("When a window is minimised or restored"),
                          _("Squeezimize and Magic Lamp need the GL renderer; without it they fade instead."),
                          { "none", "fade", "zoom", "squeezimize", "magic-lamp" },
                          { _("None"), _("Fade"), _("Zoom"), _("Squeezimize"), _("Magic Lamp") });

            /* Timing rows appear only for the animations in use. */
            var timing = group (_("Timing"));
            string[] all = { "open-animation", "close-animation", "minimize-animation" };

            timing.number (fx, "animation-duration-ms", _("Fade and zoom"), null, 50, 5000, 10, 0, _("ms"))
                  .depends (fx, all, (s) => {
                      foreach (string key in new string[] { "open-animation", "close-animation", "minimize-animation" }) {
                          string v = s.get_string (key);
                          if (v == "fade" || v == "zoom") {
                              return true;
                          }
                      }
                      return false;
                  });
            timing.number (fx, "zap-duration-ms", _("Zap"), null, 50, 5000, 10, 0, _("ms"))
                  .depends (fx, all, (s) => s.get_string ("open-animation") == "zap" ||
                                            s.get_string ("close-animation") == "zap");
            timing.number (fx, "spin-duration-ms", _("Spin"), null, 50, 5000, 10, 0, _("ms"))
                  .depends (fx, all, (s) => s.get_string ("open-animation") == "spin" ||
                                            s.get_string ("close-animation") == "spin");
            timing.number (fx, "spin-rotations", _("Spin turns"),
                           _("How many full turns the window makes; a negative number turns the other way."),
                           -10, 10, 1, 0)
                  .depends (fx, all, (s) => s.get_string ("open-animation") == "spin" ||
                                            s.get_string ("close-animation") == "spin");
            timing.number (fx, "squeezimize-duration-ms", _("Squeezimize"), null, 50, 5000, 10, 0, _("ms"))
                  .depends (fx, all, (s) => s.get_string ("minimize-animation") == "squeezimize");
            timing.number (fx, "magic-lamp-duration-ms", _("Magic Lamp"), null, 50, 5000, 10, 0, _("ms"))
                  .depends (fx, new string[] { "minimize-animation", "magic-lamp" },
                            (s) => s.get_string ("minimize-animation") == "magic-lamp" ||
                                   (s.get_string ("minimize-animation") == "none" && s.get_boolean ("magic-lamp")));

            var hint_row = new Row (_("Nothing to time"), _("All three animations are set to None."));
            timing.add_row (hint_row).depends (fx, all, (s) => {
                foreach (string key in new string[] { "open-animation", "close-animation", "minimize-animation" }) {
                    if (s.get_string (key) != "none") {
                        return false;
                    }
                }
                return !s.get_boolean ("magic-lamp");
            });

            var adv = advanced_box (_("Advanced: older settings"));
            var legacy = advanced_group (adv, null);
            legacy.toggle (fx, "magic-lamp", _("Minimise with Magic Lamp"),
                           _("A switch from before the minimise animation could be chosen. It only has an effect while the minimise animation is None."));

            add_restore_button ();
        }
    }
}
