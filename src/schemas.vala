/* Access to the GSettings schemas Polo installs. */

namespace PoloTweaks {

    namespace Schemas {
        public const string GENERAL = "org.mate.polo.general";
        public const string SESSION = "org.mate.polo.session";
        public const string EFFECTS = "org.mate.polo.effects";
        public const string KEYBINDINGS = "org.mate.polo.keybindings";
        public const string BACKGROUND = "org.mate.background";
        public const string HOT_CORNERS = "org.mate.polo.hot-corners";
        public const string SCALE = "org.mate.polo.scale";

        public const string[] ALL = { GENERAL, SESSION, EFFECTS, KEYBINDINGS };

        private HashTable<string, Settings>? cache = null;

        public bool installed (string schema_id) {
            var source = SettingsSchemaSource.get_default ();
            return source != null && source.lookup (schema_id, true) != null;
        }

        /* One shared Settings per schema, so every widget sees the same changes. */
        public Settings? get (string schema_id) {
            if (cache == null) {
                cache = new HashTable<string, Settings> (str_hash, str_equal);
            }
            var settings = cache.lookup (schema_id);
            if (settings == null && installed (schema_id)) {
                settings = new Settings (schema_id);
                cache.insert (schema_id, settings);
            }
            return settings;
        }

        public string[] missing () {
            string[] result = {};
            foreach (string id in ALL) {
                if (!installed (id)) {
                    result += id;
                }
            }
            return result;
        }

        public void reset_schema (Settings settings) {
            foreach (string key in settings.settings_schema.list_keys ()) {
                settings.reset (key);
            }
        }
    }
}
