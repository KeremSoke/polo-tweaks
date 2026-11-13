/*
 * Finding who else uses an accelerator: Polo's own keys and Marco's global
 * and window keybindings, so a new shortcut cannot silently shadow another.
 */

namespace PoloTweaks {

    public class Conflict : Object {
        public string title;
        public Settings settings;
        public string key;

        public Conflict (string title, Settings settings, string key) {
            this.title = title;
            this.settings = settings;
            this.key = key;
        }

        public void disable () {
            settings.set_string (key, "disabled");
        }
    }

    namespace Conflicts {
        private const string MARCO_GLOBAL = "org.mate.Marco.global-keybindings";
        private const string MARCO_WINDOW = "org.mate.Marco.window-keybindings";

        /* Compiled schemas carry no summaries, so name Polo's keys here and make Marco's readable. */
        private string title_for (string schema_id, string key) {
            if (schema_id == Schemas.KEYBINDINGS) {
                switch (key) {
                    case "expo": return _("Show Expo");
                    case "display-mode": return _("Choose how the screens are used");
                    case "cube": return _("Show the desktop cube");
                    case "cube-rotate-left": return _("Turn the cube left");
                    case "cube-rotate-right": return _("Turn the cube right");
                    case "cube-drag": return _("Turn the cube with the mouse");
                    case "magnifier": return _("Turn the magnifier on or off");
                    case "magnifier-zoom-in": return _("Magnify more");
                    case "magnifier-zoom-out": return _("Magnify less");
                }
            }
            string readable = key.replace ("-", " ").replace ("_", " ");
            if (readable.length > 0) {
                readable = readable.substring (0, 1).up () + readable.substring (1);
            }
            return schema_id == Schemas.KEYBINDINGS ? readable : _("%s (window manager)").printf (readable);
        }

        public Conflict? find (Settings own, string own_key, Accel accel) {
            if (accel.disabled) {
                return null;
            }
            string[] schemas = { Schemas.KEYBINDINGS, MARCO_GLOBAL, MARCO_WINDOW };
            foreach (string id in schemas) {
                var source = SettingsSchemaSource.get_default ();
                var schema = source != null ? source.lookup (id, true) : null;
                if (schema == null) {
                    continue;
                }
                var settings = id == own.schema_id ? own : new Settings (id);
                foreach (string key in schema.list_keys ()) {
                    var info = schema.get_key (key);
                    if (!info.get_value_type ().equal (VariantType.STRING)) {
                        continue;
                    }
                    if (id == own.schema_id && key == own_key) {
                        continue;
                    }
                    var other = Accel.parse (settings.get_string (key));
                    if (other == null || other.disabled || !other.equals (accel)) {
                        continue;
                    }
                    string title = title_for (id, key);
                    return new Conflict (title, settings, key);
                }
            }
            return null;
        }
    }
}
