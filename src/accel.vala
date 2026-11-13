/*
 * Marco accelerator strings: "<Mod4>e", "<Control><Alt>Left", "disabled",
 * and for pointer bindings "<Control><Alt>Button1".
 *
 * Polo reads these with Marco's parser, so this follows the same rules:
 * Super, Mod4 and Hyper are one modifier, Meta is Alt, key names are
 * lowercased, and "disabled" (or an empty string) means no binding.
 */

namespace PoloTweaks {

    public const Gdk.ModifierType ACCEL_MASK =
        Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK |
        Gdk.ModifierType.MOD1_MASK | Gdk.ModifierType.SUPER_MASK;

    /* Parses a run of "<Modifier>" tokens; returns the offset after them, or -1 if one is unknown. */
    private int parse_modifiers (string text, out Gdk.ModifierType mods) {
        mods = 0;
        int pos = 0;
        while (pos < text.length && text[pos] == '<') {
            int end = text.index_of_char ('>', pos);
            if (end < 0) {
                return -1;
            }
            switch (text.substring (pos + 1, end - pos - 1).down ()) {
                case "shift":
                    mods |= Gdk.ModifierType.SHIFT_MASK;
                    break;
                case "control":
                case "ctrl":
                case "ctl":
                    mods |= Gdk.ModifierType.CONTROL_MASK;
                    break;
                case "alt":
                case "mod1":
                case "meta":
                    mods |= Gdk.ModifierType.MOD1_MASK;
                    break;
                case "super":
                case "mod4":
                case "hyper":
                    mods |= Gdk.ModifierType.SUPER_MASK;
                    break;
                case "mod2":
                    /* Num Lock: Marco ignores it. */
                    break;
                default:
                    return -1;
            }
            pos = end + 1;
        }
        return pos;
    }

    private string modifier_prefix (Gdk.ModifierType mods) {
        var sb = new StringBuilder ();
        if ((mods & Gdk.ModifierType.SHIFT_MASK) != 0) {
            sb.append ("<Shift>");
        }
        if ((mods & Gdk.ModifierType.CONTROL_MASK) != 0) {
            sb.append ("<Control>");
        }
        if ((mods & Gdk.ModifierType.MOD1_MASK) != 0) {
            sb.append ("<Alt>");
        }
        if ((mods & Gdk.ModifierType.SUPER_MASK) != 0) {
            sb.append ("<Mod4>");
        }
        return sb.str;
    }

    private string modifier_label (Gdk.ModifierType mods) {
        var sb = new StringBuilder ();
        if ((mods & Gdk.ModifierType.SUPER_MASK) != 0) {
            sb.append ("Super+");
        }
        if ((mods & Gdk.ModifierType.CONTROL_MASK) != 0) {
            sb.append ("Ctrl+");
        }
        if ((mods & Gdk.ModifierType.MOD1_MASK) != 0) {
            sb.append ("Alt+");
        }
        if ((mods & Gdk.ModifierType.SHIFT_MASK) != 0) {
            sb.append ("Shift+");
        }
        return sb.str;
    }

    public bool is_modifier_keyval (uint keyval) {
        switch (keyval) {
            case Gdk.Key.Shift_L:
            case Gdk.Key.Shift_R:
            case Gdk.Key.Control_L:
            case Gdk.Key.Control_R:
            case Gdk.Key.Alt_L:
            case Gdk.Key.Alt_R:
            case Gdk.Key.Meta_L:
            case Gdk.Key.Meta_R:
            case Gdk.Key.Super_L:
            case Gdk.Key.Super_R:
            case Gdk.Key.Hyper_L:
            case Gdk.Key.Hyper_R:
            case Gdk.Key.ISO_Level3_Shift:
            case Gdk.Key.ISO_Level5_Shift:
            case Gdk.Key.Mode_switch:
            case Gdk.Key.Caps_Lock:
            case Gdk.Key.Num_Lock:
            case Gdk.Key.Scroll_Lock:
                return true;
            default:
                return false;
        }
    }

    /* A keyboard binding. */
    public class Accel : Object {
        public uint keyval = 0;
        public Gdk.ModifierType mods = 0;
        public bool disabled = false;
        /* "0x.." keycode accelerators are kept as written. */
        public string? keycode = null;

        public static Accel disabled_accel () {
            var a = new Accel ();
            a.disabled = true;
            return a;
        }

        public static Accel? parse (string? text) {
            var a = new Accel ();
            string s = (text ?? "").strip ();
            if (s == "" || s.down () == "disabled") {
                a.disabled = true;
                return a;
            }
            int pos = parse_modifiers (s, out a.mods);
            if (pos < 0) {
                return null;
            }
            string rest = s.substring (pos);
            if (rest.has_prefix ("0x")) {
                uint64 code;
                if (!uint64.try_parse (rest, out code, null, 16)) {
                    return null;
                }
                a.keycode = rest;
                return a;
            }
            uint keyval = Gdk.keyval_from_name (rest);
            if (keyval == 0 || keyval == Gdk.Key.VoidSymbol) {
                return null;
            }
            a.keyval = Gdk.keyval_to_lower (keyval);
            return a;
        }

        /*
         * The accelerator for a key press: the key without its modifiers
         * applied (Shift+1 is "<Shift>1", not "exclam") plus the modifiers
         * held. Null for a bare modifier key.
         */
        public static Accel? from_event (Gdk.EventKey event) {
            if (is_modifier_keyval (event.keyval)) {
                return null;
            }
            var keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
            uint keyval;
            int effective_group;
            int level;
            Gdk.ModifierType consumed;
            keymap.translate_keyboard_state (event.hardware_keycode, 0, event.group,
                                             out keyval, out effective_group, out level, out consumed);
            if (Gdk.keyval_to_unicode (keyval) > 127 && event.group != 0) {
                /* A non-Latin layout: bind the key by its Latin meaning, as shortcuts usually are. */
                uint latin;
                keymap.translate_keyboard_state (event.hardware_keycode, 0, 0,
                                                 out latin, out effective_group, out level, out consumed);
                if (latin != 0) {
                    keyval = latin;
                }
            }
            if (keyval == 0) {
                return null;
            }
            var a = new Accel ();
            a.keyval = Gdk.keyval_to_lower (keyval);
            a.mods = event.state & ACCEL_MASK;
            if ((event.state & Gdk.ModifierType.MOD4_MASK) != 0) {
                a.mods |= Gdk.ModifierType.SUPER_MASK;
            }
            return a;
        }

        /* A printable key alone (or with Shift) would stop that key from typing. */
        public bool needs_modifier () {
            if (disabled || keycode != null) {
                return false;
            }
            return (mods & ~Gdk.ModifierType.SHIFT_MASK) == 0 && Gdk.keyval_to_unicode (keyval) != 0;
        }

        public string to_string () {
            if (disabled) {
                return "disabled";
            }
            return modifier_prefix (mods) + (keycode ?? Gdk.keyval_name (keyval));
        }

        public string label () {
            if (disabled) {
                return _("Disabled");
            }
            if (keycode != null) {
                return modifier_label (mods) + _("Key %s").printf (keycode);
            }
            string name = Gdk.keyval_name (keyval) ?? "?";
            uint unicode = Gdk.keyval_to_unicode (keyval);
            if (unicode != 0 && unicode > 32) {
                name = ((unichar) unicode).to_string ().up ();
            } else {
                name = name.replace ("_", " ");
                if (name.has_prefix ("KP ")) {
                    name = _("Keypad %s").printf (name.substring (3));
                } else if (name.length > 0 && name[0].islower ()) {
                    name = name.substring (0, 1).up () + name.substring (1);
                }
            }
            return modifier_label (mods) + name;
        }

        public bool equals (Accel other) {
            return to_string () == other.to_string ();
        }
    }

    /* A modifier-plus-pointer-button binding, such as the desktop cube drag. */
    public class MouseAccel : Object {
        public uint button = 0;
        public Gdk.ModifierType mods = 0;
        public bool disabled = false;

        /* Buttons Polo understands: left, middle, right, back, forward. */
        public static bool supported_button (uint button) {
            return button == 1 || button == 2 || button == 3 || button == 8 || button == 9;
        }

        public static MouseAccel? parse (string? text) {
            var a = new MouseAccel ();
            string s = (text ?? "").strip ();
            if (s == "" || s.down () == "disabled") {
                a.disabled = true;
                return a;
            }
            int pos = parse_modifiers (s, out a.mods);
            if (pos < 0) {
                return null;
            }
            string rest = s.substring (pos).down ();
            if (!rest.has_prefix ("button")) {
                return null;
            }
            int number;
            if (!int.try_parse (rest.substring (6), out number) || !supported_button (number)) {
                return null;
            }
            a.button = number;
            return a;
        }

        public static string button_name (uint button) {
            switch (button) {
                case 1:
                    return _("Left button");
                case 2:
                    return _("Middle button");
                case 3:
                    return _("Right button");
                case 8:
                    return _("Back button");
                case 9:
                    return _("Forward button");
                default:
                    return _("Button %u").printf (button);
            }
        }

        public string to_string () {
            return disabled ? "disabled" : "%sButton%u".printf (modifier_prefix (mods), button);
        }

        public string label () {
            if (disabled) {
                return _("Disabled");
            }
            return modifier_label (mods) + button_name (button);
        }
    }
}
