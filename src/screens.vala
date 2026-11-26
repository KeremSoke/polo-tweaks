/* The connected screens, named and identified as MATE and Polo identify them. */

namespace PoloTweaks {

    public class ScreenInfo : Object {
        public string id;
        public string name;
        public Gdk.Rectangle geometry;
        public bool primary;
        public bool internal_panel;
    }

    public class ScreenWatcher : Object {
        private static ScreenWatcher? instance = null;

        public signal void changed ();

        public static ScreenWatcher get_default () {
            if (instance == null) {
                instance = new ScreenWatcher ();
                var display = Gdk.Display.get_default ();
                if (display != null) {
                    display.monitor_added.connect (() => instance.changed ());
                    display.monitor_removed.connect (() => instance.changed ());
#if HAVE_MATE_MONITOR_INFO
                    Mate.MonitorInfo.get_for_display (display).changed.connect (() => instance.changed ());
#endif
                }
            }
            return instance;
        }
    }

    namespace Screens {
        public string sanitize (string text) {
            var id = new StringBuilder ();
            for (int i = 0; i < text.length; i++) {
                char c = text[i];
                id.append_c (c.isalnum () || c == '_' || c == '.' || c == '-' ? c : '_');
            }
            return id.str;
        }

        public string base_id (string? make, string? model) {
            string m = make ?? "";
            string n = model ?? "";
            var id = new StringBuilder (sanitize (m));
            if (m != "" && n != "") {
                id.append_c ('-');
            }
            id.append (sanitize (n));
            return id.len == 0 ? "monitor" : id.str;
        }

        public GenericArray<ScreenInfo> connected () {
            var display = Gdk.Display.get_default ();
            var screens = new GenericArray<ScreenInfo> ();
            if (display == null) {
                return screens;
            }
#if !HAVE_MATE_MONITOR_INFO
            var seen = new HashTable<string, int> (str_hash, str_equal);
#endif
            int n = display.get_n_monitors ();
            for (int i = 0; i < n; i++) {
                var monitor = display.get_monitor (i);
                if (monitor == null) {
                    continue;
                }
                var screen = new ScreenInfo ();
                screen.geometry = monitor.geometry;
#if HAVE_MATE_MONITOR_INFO
                var info = Mate.MonitorInfo.get_for_display (display);
                screen.id = info.get_id (monitor);
                screen.name = info.get_display_name (monitor) ?? "";
                screen.primary = info.is_primary (monitor);
                screen.internal_panel = info.is_internal (monitor);
#else
                string base_name = base_id (monitor.manufacturer, monitor.model);
                int copies = seen.contains (base_name) ? seen.lookup (base_name) : 0;
                seen.insert (base_name, copies + 1);
                screen.id = copies == 0 ? base_name : "%s+%d".printf (base_name, copies);
                screen.name = monitor.model ?? monitor.manufacturer ?? "";
                screen.primary = monitor.is_primary ();
                screen.internal_panel = false;
#endif
                if (screen.name.strip () == "") {
                    screen.name = _("Screen %d").printf (i + 1);
                }
                screens.add (screen);
            }
            if (screens.length > 0) {
                bool any_primary = false;
                foreach (var screen in screens) {
                    any_primary = any_primary || screen.primary;
                }
                if (!any_primary) {
                    screens[0].primary = true;
                }
            }
            return screens;
        }

        public Settings? settings_for (string id) {
            var source = SettingsSchemaSource.get_default ();
            var schema = source != null ? source.lookup ("org.mate.polo.hot-corners.screen", true) : null;
            if (schema == null) {
                return null;
            }
            return new Settings.full (schema, null, "/org/mate/polo/hot-corners/screens/" + id + "/");
        }
    }
}
