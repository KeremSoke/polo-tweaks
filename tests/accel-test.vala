using PoloTweaks;

void test_defaults () {
    foreach (string text in new string[] { "<Mod4>e", "<Mod4>p", "<Mod4>c", "<Mod4><Alt>8", "<Mod4><Alt>equal", "<Mod4><Alt>minus" }) {
        var a = Accel.parse (text);
        assert (a != null);
        assert (!a.disabled);
        assert (a.mods == Gdk.ModifierType.SUPER_MASK || a.mods == (Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.MOD1_MASK));
        /* Round trip. */
        assert (Accel.parse (a.to_string ()).equals (a));
    }
}

void test_normalisation () {
    /* Marco treats Super, Mod4 and Hyper as one modifier, Meta as Alt. */
    assert (Accel.parse ("<Super>E").equals (Accel.parse ("<Mod4>e")));
    assert (Accel.parse ("<Hyper>e").equals (Accel.parse ("<Mod4>e")));
    assert (Accel.parse ("<Meta>x").equals (Accel.parse ("<Alt>x")));
    assert (Accel.parse ("<Ctrl><Shift>a").equals (Accel.parse ("<Shift><Control>a")));
    assert (Accel.parse ("<Control><Alt>Left").to_string () == "<Control><Alt>Left");
}

void test_disabled_and_invalid () {
    assert (Accel.parse ("disabled").disabled);
    assert (Accel.parse ("").disabled);
    assert (Accel.parse (null).disabled);
    assert (Accel.parse ("<Bogus>x") == null);
    assert (Accel.parse ("<Control>nosuchkeyname") == null);
    assert (Accel.parse ("<Control") == null);
    assert (Accel.parse ("disabled").to_string () == "disabled");
}

void test_needs_modifier () {
    assert (Accel.parse ("a").needs_modifier ());
    assert (Accel.parse ("<Shift>a").needs_modifier ());
    assert (Accel.parse ("space").needs_modifier ());
    assert (!Accel.parse ("<Control>a").needs_modifier ());
    assert (!Accel.parse ("F11").needs_modifier ());
    assert (!Accel.parse ("Print").needs_modifier ());
    assert (!Accel.parse ("XF86Display").needs_modifier ());
}

void test_mouse () {
    var m = MouseAccel.parse ("<Control><Alt>Button1");
    assert (m != null && !m.disabled);
    assert (m.button == 1);
    assert (m.mods == (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK));
    assert (m.to_string () == "<Control><Alt>Button1");
    assert (MouseAccel.parse ("disabled").disabled);
    assert (MouseAccel.parse ("<Control>Button4") == null);
    assert (MouseAccel.parse ("<Control>a") == null);
    assert (MouseAccel.parse ("<Mod4>button9").button == 9);
}

void main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/accel/defaults", test_defaults);
    Test.add_func ("/accel/normalisation", test_normalisation);
    Test.add_func ("/accel/disabled-and-invalid", test_disabled_and_invalid);
    Test.add_func ("/accel/needs-modifier", test_needs_modifier);
    Test.add_func ("/accel/mouse", test_mouse);
    Test.run ();
}
