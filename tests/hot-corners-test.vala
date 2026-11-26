/* The hot corners page: its widgets, the screen diagram's rules, per-screen corners and the presets. */

using PoloTweaks;

Settings hot;

uint32 delay_of (string spot, out bool present) {
    uint32 delay = 0;
    present = hot.get_value ("corner-delays").lookup (spot, "u", out delay);
    return delay;
}

ScreenInfo screen (string id, int x, int y, int width, int height, bool primary = false) {
    var s = new ScreenInfo ();
    s.id = id;
    s.name = id;
    s.geometry = Gdk.Rectangle () { x = x, y = y, width = width, height = height };
    s.primary = primary;
    return s;
}

void test_action () {
    Schemas.reset_schema (hot);
    var action = new HotCornerAction (hot, "top-left");
    var combo = action.get_combo ();
    var entry = action.get_entry ();
    assert (combo.active_id == "none");
    assert (!entry.visible);

    hot.set_string ("top-left", "expo");
    assert (combo.active_id == "expo");
    foreach (var id in new string[] { "cube", "show-desktop", "window-switcher", "lock-screen", "run-dialog", "none" }) {
        combo.active_id = id;
        assert (hot.get_string ("top-left") == id);
    }

    combo.active_id = "command";
    assert (entry.visible);
    entry.text = "xterm -e top";
    entry.activate ();
    assert (hot.get_string ("top-left") == "command:xterm -e top");

    hot.set_string ("top-left", "command:foo bar");
    assert (combo.active_id == "command" && entry.text == "foo bar");
    hot.set_string ("top-left", "lock-screen");
    assert (combo.active_id == "lock-screen" && !entry.visible);
    hot.set_string ("top-left", "no-such-action");
    assert (combo.active_id == "none");
    hot.set_string ("top-left", "");
    assert (combo.active_id == "none");

    hot.set_string ("top-left", "command:sh -c true");
    assert (entry.secondary_icon_name == null);
    hot.set_string ("top-left", "command:polo-no-such-program");
    assert (entry.secondary_icon_name == "dialog-warning-symbolic");

    hot.set_string ("top-right", "expo");
    action.retarget (hot, "top-right");
    assert (combo.active_id == "expo");
    combo.active_id = "cube";
    assert (hot.get_string ("top-right") == "cube");
    assert (hot.get_string ("top-left") == "command:polo-no-such-program");
}

void test_commands () {
    assert (HotActions.strip_field_codes ("firefox %u") == "firefox");
    assert (HotActions.strip_field_codes ("gimp-2.10 %U --new") == "gimp-2.10 --new");
    assert (HotActions.strip_field_codes ("printf 100%% %f") == "printf 100%");
    assert (HotActions.command_problem ("") != null);
    assert (HotActions.command_problem ("sh -c 'echo hi'") == null);
    assert (HotActions.command_problem ("/bin/sh") == null);
    assert (HotActions.command_problem ("/etc") != null);
    assert (HotActions.command_problem ("polo-no-such-program --x") != null);
    assert (HotActions.command_problem ("sh -c 'unclosed") != null);
    assert (HotActions.kind ("command:ls") == "command" && HotActions.kind (" expo ") == "expo");
    assert (HotActions.kind ("weird") == "none");
    assert (HotActions.describe ("command:ls -l") == "ls -l");
    assert (HotActions.describe ("expo") == HotActions.label ("expo"));
}

void test_delay () {
    Schemas.reset_schema (hot);
    var right = new HotCornerDelay (hot, "top-right");
    var top = new HotCornerDelay (hot, "top");
    var own = (Gtk.CheckButton) right.get_children ().nth_data (0);
    var spin = (Gtk.SpinButton) right.get_children ().nth_data (1);
    var top_own = (Gtk.CheckButton) top.get_children ().nth_data (0);
    bool present;

    assert (!own.active && !spin.sensitive);
    assert ((uint) spin.value == hot.get_uint ("hover-delay"));
    hot.set_uint ("hover-delay", 400);
    assert ((uint) spin.value == 400);

    own.active = true;
    assert (delay_of ("top-right", out present) == 400 && present);
    spin.value = 0;
    assert (delay_of ("top-right", out present) == 0 && present);
    top_own.active = true;
    delay_of ("top", out present);
    assert (present);
    own.active = false;
    delay_of ("top-right", out present);
    assert (!present);
    delay_of ("top", out present);
    assert (present);

    hot.set_value ("corner-delays", new Variant.parsed ("{'top-right': uint32 250}"));
    assert (own.active && (uint) spin.value == 250 && spin.sensitive);
}

void test_geometry () {
    Gdk.Rectangle[] two = { Gdk.Rectangle () { x = 0, y = 0, width = 1000, height = 800 },
                            Gdk.Rectangle () { x = 1000, y = 0, width = 1000, height = 800 } };
    bool[] both = { true, true };
    var outer = HotGeometry.compute (two, both, "outer");
    assert (outer[0].corner[0] && !outer[0].corner[1] && outer[0].corner[2] && !outer[0].corner[3]);
    assert (!outer[1].corner[0] && outer[1].corner[1] && !outer[1].corner[2] && outer[1].corner[3]);
    assert (outer[0].edges[0].length == 1 && outer[0].edges[3].length == 0 && outer[1].edges[2].length == 0);
    var every = HotGeometry.compute (two, both, "every-screen");
    for (int c = 0; c < 4; c++) {
        assert (every[0].corner[c] && every[1].corner[c]);
    }
    var whole = HotGeometry.compute (two, both, "whole-area");
    assert (whole[0].corner[0] && whole[1].corner[1] && !whole[0].corner[1] && !whole[1].corner[0]);
    bool[] first = { true, false };
    var partly = HotGeometry.compute (two, first, "outer");
    assert (partly[0].allowed && !partly[1].allowed && !partly[1].corner[1]);

    Gdk.Rectangle[] step = { Gdk.Rectangle () { x = 0, y = 0, width = 1920, height = 1200 },
                             Gdk.Rectangle () { x = 1920, y = 0, width = 1920, height = 1080 } };
    var uneven = HotGeometry.compute (step, both, "outer");
    assert (uneven[0].corner[3] && !uneven[1].corner[2]);
    assert (uneven[0].edges[3].length == 1 && uneven[0].edges[3][0].start == 1080 &&
            uneven[0].edges[3][0].length == 120);
    var uneven_whole = HotGeometry.compute (step, both, "whole-area");
    assert (uneven_whole[1].corner[3] && !uneven_whole[0].corner[3]);
}

void test_screen_choice () {
    Schemas.reset_schema (hot);
    var screens = new GenericArray<ScreenInfo> ();
    screens.add (screen ("BOE-laptop", 0, 0, 1920, 1200, true));
    screens.add (screen ("DEL-dell", 1920, 0, 1920, 1080));
    screens.add (screen ("EPS-projector", 3840, 0, 1024, 768));
    foreach (var s in screens) {
        assert (HotGeometry.screen_allowed (hot, s));
    }
    HotGeometry.set_screen_allowed (hot, screens, screens[2], false);
    assert (hot.get_string ("screens") == "selected");
    var chosen = hot.get_strv ("selected-screens");
    assert (chosen.length == 2 && "BOE-laptop" in chosen && "DEL-dell" in chosen);
    assert (!HotGeometry.screen_allowed (hot, screens[2]));
    HotGeometry.set_screen_allowed (hot, screens, screens[2], true);
    assert (hot.get_strv ("selected-screens").length == 3);
    assert (HotGeometry.screen_allowed (hot, screens[2]));

    Schemas.reset_schema (hot);
    hot.set_string ("screens", "primary");
    assert (HotGeometry.screen_allowed (hot, screens[0]) && !HotGeometry.screen_allowed (hot, screens[1]));
    HotGeometry.set_screen_allowed (hot, screens, screens[1], true);
    chosen = hot.get_strv ("selected-screens");
    assert (hot.get_string ("screens") == "selected" && chosen.length == 2 && !("EPS-projector" in chosen));
    HotGeometry.set_screen_allowed (hot, screens, screens[0], false);
    chosen = hot.get_strv ("selected-screens");
    assert (chosen.length == 1 && chosen[0] == "DEL-dell");

    Schemas.reset_schema (hot);
    HotGeometry.set_screen_allowed (hot, screens, screens[1], false);
    HotGeometry.set_screen_allowed (hot, screens, screens[1], true);
    assert (hot.get_strv ("selected-screens").length == 3);
    assert (Screens.base_id ("BOE", "0x0A34") == "BOE-0x0A34");
    assert (Screens.base_id ("Dell Inc.", "DELL SE2722H") == "Dell_Inc.-DELL_SE2722H");
    assert (Screens.base_id (null, "") == "monitor" && Screens.base_id ("", "X") == "X");
}

void test_page () {
    Schemas.reset_schema (hot);
    var page = new HotCornersPage ();
    var window = new Gtk.OffscreenWindow ();
    window.add (page);
    window.set_size_request (900, 1400);
    window.show_all ();
    while (Gtk.events_pending ()) {
        Gtk.main_iteration ();
    }
    var layout = page.get_layout ();
    assert (layout.screens.length >= 1);

    var animation = page.get_animation_switch ();
    assert (!animation.active && !animation.get_parent ().sensitive);
    hot.set_boolean ("enabled", true);
    assert (animation.get_parent ().sensitive);
    animation.active = true;
    assert (hot.get_boolean ("animation"));
    hot.set_boolean ("animation", false);
    assert (!animation.active);
    hot.set_boolean ("enabled", false);

    hot.set_boolean ("enabled", true);
    hot.set_string ("top-left", "expo");
    assert (layout.spot_fires (0, 0));
    assert (!layout.spot_fires (0, 1));
    hot.set_boolean ("enabled", false);
    assert (!layout.spot_fires (0, 0));
    hot.set_boolean ("enabled", true);

    var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, layout.get_allocated_width (),
                                          layout.get_allocated_height ());
    var cr = new Cairo.Context (surface);
    layout.draw (cr);
    assert (surface.status () == Cairo.Status.SUCCESS);

    var own = Screens.settings_for (layout.screens[0].id);
    assert (own != null);
    Schemas.reset_schema (own);
    page.select_screen (0);
    var action = page.get_action (0);
    assert (action.get_combo ().active_id == "expo");
    own.set_string ("top-left", "lock-screen");
    own.set_boolean ("use-shared", false);
    assert (action.get_combo ().active_id == "lock-screen");
    action.get_combo ().active_id = "show-desktop";
    assert (own.get_string ("top-left") == "show-desktop" && hot.get_string ("top-left") == "expo");
    assert (layout.spot_fires (0, 0));
    own.set_string ("top-left", "none");
    assert (!layout.spot_fires (0, 0));
    own.set_boolean ("use-shared", true);
    assert (action.get_combo ().active_id == "expo" && layout.spot_fires (0, 0));

    own.set_boolean ("use-shared", false);
    page.restore_defaults ();
    assert (own.get_boolean ("use-shared") && own.get_string ("top-left") == "none");
    assert (hot.get_string ("top-left") == "none");
    window.destroy ();
}

void pump () {
    while (Gtk.events_pending ()) {
        Gtk.main_iteration ();
    }
}

void test_every_widget () {
    Schemas.reset_schema (hot);
    var page = new HotCornersPage ();
    var window = new Gtk.OffscreenWindow ();
    window.add (page);
    window.set_size_request (900, 1400);
    window.show_all ();
    pump ();
    hot.set_boolean ("enabled", true);

    for (int round = 0; round < 3; round++) {
        for (int spot = 0; spot < HOT_SPOTS.length; spot++) {
            var combo = page.get_action (spot).get_combo ();
            foreach (string id in HotActions.IDS) {
                if (id == "command") {
                    continue;
                }
                combo.active_id = id;
                pump ();
                assert (hot.get_string (HOT_SPOTS[spot]) == id);
                assert (combo.active_id == id);
            }
            hot.set_string (HOT_SPOTS[spot], "expo");
            assert (combo.active_id == "expo");
            hot.set_string (HOT_SPOTS[spot], "command:true");
            assert (combo.active_id == "command" && page.get_action (spot).get_entry ().text == "true");
            combo.active_id = "none";
            assert (hot.get_string (HOT_SPOTS[spot]) == "none");
        }
    }

    var presets = page.get_preset_combo ();
    string[] order = { "push-outer", "whole-desk", "rest-every", "primary-only", "rest-every", "push-outer",
                       "primary-only", "whole-desk" };
    foreach (string id in order) {
        presets.active_id = id;
        pump ();
        assert (presets.active_id == id && page.current_preset () == id);
        hot.set_uint ("cooldown", 900);
        assert (presets.active_id == "custom");
        presets.active_id = id;
        assert (presets.active_id == id && hot.get_uint ("cooldown") == 350);
    }

    var animation = page.get_animation_switch ();
    for (int i = 0; i < 4; i++) {
        animation.active = !animation.active;
        assert (hot.get_boolean ("animation") == animation.active);
    }

    var one = new GenericArray<ScreenInfo> ();
    one.add (screen ("A", 0, 0, 1920, 1080, true));
    page.reload_screens_for_test (one);
    pump ();
    assert (!page.screen_section_shown ());
    var two = new GenericArray<ScreenInfo> ();
    two.add (screen ("A", 0, 0, 1920, 1080, true));
    two.add (screen ("B", 1920, 0, 1920, 1080));
    page.reload_screens_for_test (two);
    pump ();
    assert (page.screen_section_shown ());
    page.reload_screens_for_test (one);
    pump ();
    assert (!page.screen_section_shown ());
    window.destroy ();
}

Row? find_row (Page page, string title) {
    foreach (var group in page.groups) {
        foreach (var row in group.rows) {
            if (row.title == title) {
                return row;
            }
        }
    }
    return null;
}

void test_greying () {
    Schemas.reset_schema (hot);
    var page = new HotCornersPage ();
    var window = new Gtk.OffscreenWindow ();
    window.add (page);
    window.set_size_request (900, 1400);
    window.show_all ();
    pump ();
    hot.set_boolean ("enabled", true);

    var push = find_row (page, "Push needed");
    var within = find_row (page, "Push within");
    assert (push != null && within != null && push.visible);
    assert (push.sensitive && within.sensitive);
    hot.set_string ("trigger", "hover");
    assert (!push.sensitive && !within.sensitive && push.visible);
    hot.set_string ("trigger", "pressure");
    assert (push.sensitive && within.sensitive);

    var ids = find_row (page, "Screens");
    assert (ids != null && !ids.sensitive);
    hot.set_string ("screens", "selected");
    assert (ids.sensitive);
    hot.set_string ("screens", "all");
    assert (!ids.sensitive);

    var one = new GenericArray<ScreenInfo> ();
    one.add (screen ("grey-A", 0, 0, 1920, 1080, true));
    page.reload_screens_for_test (one);
    assert (!page.get_layout_row ().sensitive);
    var two = new GenericArray<ScreenInfo> ();
    two.add (screen ("grey-A", 0, 0, 1920, 1080, true));
    two.add (screen ("grey-B", 1920, 0, 1920, 1080));
    page.reload_screens_for_test (two);
    assert (page.get_layout_row ().sensitive);

    assert (!page.get_delay_row (0).sensitive && !page.get_delay_row (1).sensitive);
    hot.set_string ("top-left", "expo");
    assert (page.get_delay_row (0).sensitive && !page.get_delay_row (1).sensitive);
    var own_b = Screens.settings_for ("grey-B");
    Schemas.reset_schema (own_b);
    own_b.set_string ("top-right", "lock-screen");
    assert (!page.get_delay_row (1).sensitive);
    own_b.set_boolean ("use-shared", false);
    assert (page.get_delay_row (1).sensitive);

    page.select_screen (1);
    pump ();
    assert (page.get_screen_own_row ().sensitive);
    for (int i = 0; i < HOT_SPOTS.length; i++) {
        assert (page.get_action_row (i).sensitive);
    }
    page.get_screen_on ().active = false;
    pump ();
    assert (hot.get_string ("screens") == "selected" && !("grey-B" in hot.get_strv ("selected-screens")));
    assert (!page.get_screen_own_row ().sensitive);
    for (int i = 0; i < HOT_SPOTS.length; i++) {
        assert (!page.get_action_row (i).sensitive);
    }
    own_b.set_boolean ("use-shared", true);
    for (int i = 0; i < HOT_SPOTS.length; i++) {
        assert (page.get_action_row (i).sensitive);
    }
    page.get_screen_on ().active = true;
    assert (page.get_screen_own_row ().sensitive);
    Schemas.reset_schema (own_b);
    window.destroy ();
}

void test_presets () {
    Schemas.reset_schema (hot);
    var page = new HotCornersPage ();
    hot.set_string ("top-right", "lock-screen");
    hot.set_boolean ("fullscreen", true);

    hot.set_boolean ("animation", true);
    page.apply_preset ("rest-every");
    assert (hot.get_boolean ("animation"));
    assert (hot.get_boolean ("enabled"));
    assert (hot.get_string ("top-left") == "expo" && hot.get_string ("top-right") == "none");
    assert (!hot.get_boolean ("fullscreen"));
    assert (hot.get_string ("trigger") == "hover" && hot.get_uint ("hover-delay") == 75);
    assert (hot.get_string ("layout") == "every-screen" && hot.get_string ("screens") == "all");

    page.apply_preset ("primary-only");
    assert (hot.get_string ("trigger") == "hover" && hot.get_uint ("hover-delay") == 0);
    assert (hot.get_boolean ("click"));
    assert (hot.get_string ("layout") == "outer" && hot.get_string ("screens") == "primary");

    page.apply_preset ("whole-desk");
    assert (hot.get_string ("layout") == "whole-area" && hot.get_string ("trigger") == "hover");
    assert (!hot.get_boolean ("click") && hot.get_string ("screens") == "all");

    page.apply_preset ("push-outer");
    assert (hot.get_string ("trigger") == "pressure" && hot.get_string ("layout") == "outer");
    assert (hot.get_uint ("hover-delay") == 150 && hot.get_string ("top-left") == "expo");
    assert (page.current_preset () == "push-outer");

    var combo = page.get_preset_combo ();
    assert (combo.active_id == "push-outer");
    hot.set_uint ("pressure-threshold", 300);
    assert (page.current_preset () == "custom" && combo.active_id == "custom");
    combo.active_id = "rest-every";
    assert (hot.get_string ("layout") == "every-screen" && hot.get_uint ("pressure-threshold") == 100);
    assert (combo.active_id == "rest-every");
    combo.active_id = "whole-desk";
    assert (hot.get_string ("layout") == "whole-area" && hot.get_uint ("hover-delay") == 150);
    assert (combo.active_id == "whole-desk");
    combo.active_id = "primary-only";
    assert (hot.get_string ("screens") == "primary" && hot.get_boolean ("click"));
    assert (combo.active_id == "primary-only");
    combo.active_id = "custom";
    assert (hot.get_string ("screens") == "primary" && combo.active_id == "custom");
    hot.set_boolean ("enabled", false);
    hot.set_string ("layout", "outer");
    hot.set_string ("layout", "whole-area");
    hot.set_string ("screens", "all");
    hot.set_boolean ("click", false);
    hot.reset ("hover-delay");
    assert (combo.active_id == "whole-desk");
    hot.set_string ("top-left", "lock-screen");
    assert (combo.active_id == "custom");
}

int main (string[] args) {
    if (!Gtk.init_check (ref args)) {
        return 77;
    }
    hot = Schemas.get (Schemas.HOT_CORNERS);
    assert (hot != null);
    GLib.Test.init (ref args);
    GLib.Test.add_func ("/hot-corners/action", test_action);
    GLib.Test.add_func ("/hot-corners/commands", test_commands);
    GLib.Test.add_func ("/hot-corners/delay", test_delay);
    GLib.Test.add_func ("/hot-corners/geometry", test_geometry);
    GLib.Test.add_func ("/hot-corners/screen-choice", test_screen_choice);
    GLib.Test.add_func ("/hot-corners/page", test_page);
    GLib.Test.add_func ("/hot-corners/presets", test_presets);
    GLib.Test.add_func ("/hot-corners/every-widget", test_every_widget);
    GLib.Test.add_func ("/hot-corners/greying", test_greying);
    return GLib.Test.run ();
}
