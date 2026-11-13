/* General: what Polo does for the rest of the session. */

namespace PoloTweaks {

    public class GeneralPage : Page {
        public GeneralPage () {
            base ("general", _("General"), "preferences-system-symbolic",
                  _("How Polo looks after your session, and how it fits in with other applications."),
                  _("Desktop"));

            var general = Schemas.get (Schemas.GENERAL);
            var session = Schemas.get (Schemas.SESSION);

            var compat = group (_("Applications"));
            compat.toggle (general, "mirror-gtk-settings", _("Keep GTK applications in step with MATE"),
                           _("Copies your MATE theme, font, mouse and sound settings to the settings that GTK and desktop portals read on Wayland. The copy is written to your dconf database, so GNOME sessions see it too."));

            var start = group (_("Session"));
            start.toggle (session, "restore-window-state", _("Restore windows at login"),
                          _("Remembers each window's workspace, position, size and maximised, minimised, sticky or always-on-top state when you log out, and gives it back to the first window with the same application and title next time."));
            start.text (session, "locker-command", _("Screen locker"),
                        _("The program Polo starts to lock the screen when MATE Screensaver is not running. It must support ext-session-lock-v1. Leave empty to use none. Press Enter to apply."),
                        "swaylock -f");
            start.number (session, "phase-timeout", _("Startup phase timeout"),
                          _("How long Polo waits for the applications of one startup phase before it starts the next."),
                          1, 300, 1, 0, _("seconds"));

            var adv = advanced_box (_("Advanced: session components"));
            var trust = advanced_group (adv, _("Trust"),
                                        _("Programs that may use Polo's privileged protocols, such as screen capture, panels and input methods. Change these only if you know a program needs them."));
            trust.string_list (session, "trusted-components", _("Trusted components"),
                               _("Desktop IDs or program names, in addition to the components Polo requires."));
            trust.string_list (session, "trusted-executables", _("Trusted executables"),
                               _("Full paths of programs that D-Bus, not Polo, starts, such as the portal backend and the notification daemon. A program counts only while its file is owned by root and writable by nobody else."));
            var x11 = advanced_group (adv, _("Compatibility"));
            x11.string_list (session, "x11-components", _("Components that run on X"),
                             _("Desktop IDs or program names that are started with GDK_BACKEND=x11 because they call X directly."));

            add_restore_button ();
        }
    }
}
