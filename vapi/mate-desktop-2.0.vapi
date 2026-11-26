/* libmate-desktop's MateMonitorInfo (unstable API). */

[CCode (cheader_filename = "libmate-desktop/mate-monitor-info.h")]
namespace Mate {
    [CCode (type_id = "mate_monitor_info_get_type ()")]
    public class MonitorInfo : GLib.Object {
        public static unowned MonitorInfo get_default ();
        public static unowned MonitorInfo get_for_display (Gdk.Display display);
        public bool has_protocol ();
        public string get_id (Gdk.Monitor monitor);
        public string? get_display_name (Gdk.Monitor monitor);
        public bool is_internal (Gdk.Monitor monitor);
        public bool is_primary (Gdk.Monitor monitor);
        public string? get_mirror_of (Gdk.Monitor monitor);
        public signal void changed (Gdk.Monitor? monitor);
    }
}
