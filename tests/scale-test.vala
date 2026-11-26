/* The Scale page: its rows, the per-kind screen choices and the hot corner actions. */

using PoloTweaks;

Settings scale;

string? override_of (string mode) {
    string? value = null;
    if (!scale.get_value ("mode-screens").lookup (mode, "s", out value)) {
        return null;
    }
    return value;
}

void test_mode_screens () {
    Schemas.reset_schema (scale);
    var all = new ScaleModeScreens (scale, "all-workspaces");
    var app = new ScaleModeScreens (scale, "application");
    assert (all.active_id == "" && app.active_id == "");

    all.active_id = "summoned";
    assert (override_of ("all-workspaces") == "summoned");
    assert (override_of ("application") == null);
    app.active_id = "mirrored";
    assert (override_of ("all-workspaces") == "summoned" && override_of ("application") == "mirrored");
    all.active_id = "";
    assert (override_of ("all-workspaces") == null && override_of ("application") == "mirrored");

    var builder = new VariantBuilder (new VariantType ("a{ss}"));
    builder.add ("{ss}", "all-workspaces", "each");
    builder.add ("{ss}", "application", "bogus");
    scale.set_value ("mode-screens", builder.end ());
    assert (all.active_id == "each");
    assert (app.active_id == "");
    Schemas.reset_schema (scale);
    assert (all.active_id == "" && app.active_id == "");
}

void collect (Gtk.Widget widget, GenericArray<Gtk.Widget> found) {
    found.add (widget);
    var container = widget as Gtk.Container;
    if (container != null) {
        container.forall ((child) => collect (child, found));
    }
}

void test_page () {
    Schemas.reset_schema (scale);
    var page = new ScalePage ();
    assert (page.page_id == "scale");
    var found = new GenericArray<Gtk.Widget> ();
    collect (page, found);
    int mode_rows = 0, shortcuts = 0;
    foreach (var w in found) {
        if (w is ScaleModeScreens) {
            mode_rows++;
        }
        if (w is ShortcutEditor) {
            shortcuts++;
        }
    }
    assert (mode_rows == ScaleModes.IDS.length);
    assert (shortcuts == ScaleModes.KEYS.length);

    scale.set_boolean ("enabled", false);
    assert (page.status_text () != null);
    scale.set_boolean ("enabled", true);
}

void test_actions () {
    foreach (var id in new string[] { "scale", "scale-all-workspaces", "scale-application",
                                      "scale-application-all-workspaces" }) {
        assert (id in HotActions.IDS);
        assert (HotActions.kind (id) == id);
        assert (HotActions.label (id) != HotActions.label ("none"));
    }
    var labels = new GenericSet<string> (str_hash, str_equal);
    foreach (var id in HotActions.IDS) {
        assert (!labels.contains (HotActions.label (id)));
        labels.add (HotActions.label (id));
    }
}

int main (string[] args) {
    if (!Gtk.init_check (ref args)) {
        return 77;
    }
    scale = Schemas.get (Schemas.SCALE);
    assert (scale != null);
    GLib.Test.init (ref args);
    GLib.Test.add_func ("/scale/mode-screens", test_mode_screens);
    GLib.Test.add_func ("/scale/page", test_page);
    GLib.Test.add_func ("/scale/actions", test_actions);
    return GLib.Test.run ();
}
