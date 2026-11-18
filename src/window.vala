/* The main window: a sidebar of pages, search, and the page itself. */

namespace PoloTweaks {

    private const string STYLE = """
        .page-title { font-size: 150%; font-weight: bold; }
        .section-title { font-weight: bold; }
        .row-subtitle { font-size: 90%; opacity: 0.7; }
        .nav-heading { font-size: 85%; font-weight: bold; opacity: 0.6; padding: 14px 14px 4px 14px; }
        .nav-status { font-size: 85%; opacity: 0.6; }
        .search-hit { background-color: alpha(@theme_selected_bg_color, 0.28); }
        button.capturing { background-image: none; background-color: @theme_selected_bg_color; color: @theme_selected_fg_color; }
        button.capturing label { color: @theme_selected_fg_color; opacity: 1; }
        .hit-page { font-size: 85%; opacity: 0.65; }
    """;

    private class NavRow : Gtk.ListBoxRow {
        public Page page;
        private Gtk.Label status;

        public NavRow (Page page) {
            this.page = page;
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
                margin_top = 9, margin_bottom = 9, margin_start = 14, margin_end = 14
            };
            box.pack_start (new Gtk.Image.from_icon_name (page.page_icon, Gtk.IconSize.BUTTON), false, false, 0);
            box.pack_start (new Gtk.Label (page.page_title) { xalign = 0 }, true, true, 0);
            status = new Gtk.Label ("");
            status.get_style_context ().add_class ("nav-status");
            box.pack_start (status, false, false, 0);
            add (box);
            refresh ();
            page.status_changed.connect (refresh);
        }

        private void refresh () {
            status.label = page.status_text () ?? "";
        }
    }

    private class HitRow : Gtk.ListBoxRow {
        public Page page;
        public Row row;

        public HitRow (Page page, Row row) {
            this.page = page;
            this.row = row;
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                margin_top = 7, margin_bottom = 7, margin_start = 14, margin_end = 14
            };
            box.pack_start (new Gtk.Label (row.title) { xalign = 0, ellipsize = Pango.EllipsizeMode.END }, false, false, 0);
            var where = new Gtk.Label (row.visible ? page.page_title
                                                   : _("%s · shown when its option is selected").printf (page.page_title)) {
                xalign = 0
            };
            where.get_style_context ().add_class ("hit-page");
            box.pack_start (where, false, false, 0);
            add (box);
        }
    }

    public class MainWindow : Gtk.ApplicationWindow {
        private Gtk.Stack pages;
        private Gtk.Stack side;
        private Gtk.ListBox nav;
        private Gtk.ListBox results;
        private Gtk.SearchEntry search;
        private GLib.GenericArray<Page> all_pages = new GLib.GenericArray<Page> ();

        public MainWindow (Gtk.Application app) {
            Object (application: app, title: _("Polo Tweaks"), default_width: 1080, default_height: 780,
                    icon_name: "preferences-system-windows");

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (STYLE);
                Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("Could not load the style: %s", e.message);
            }

            var header = new Gtk.HeaderBar () { show_close_button = true, title = _("Polo Tweaks") };
            var menu = new Menu ();
            menu.append (_("Restore All Defaults…"), "win.reset-all");
            menu.append (_("About Polo Tweaks"), "win.about");
            header.pack_end (new Gtk.MenuButton () {
                menu_model = menu,
                image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.BUTTON)
            });
            header.show_all ();
            set_titlebar (header);

            var reset_all = new SimpleAction ("reset-all", null);
            reset_all.activate.connect (confirm_reset_all);
            add_action (reset_all);
            var about = new SimpleAction ("about", null);
            about.activate.connect (show_about);
            add_action (about);
            var find = new SimpleAction ("find", null);
            find.activate.connect (() => search.grab_focus ());
            add_action (find);
            app.set_accels_for_action ("win.find", { "<Primary>f" });

            pages = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE, hexpand = true, vexpand = true
            };

            string[] missing = Schemas.missing ();
            if (missing.length > 0) {
                add (missing_schemas_view (missing));
                return;
            }

            all_pages.add (new GeneralPage ());
            if (Schemas.installed (Schemas.BACKGROUND)) {
                all_pages.add (new BackgroundPage ());
            }
            all_pages.add (new WobblyPage ());
            all_pages.add (new AnimationsPage ());
            all_pages.add (new ExpoPage ());
            all_pages.add (new CubePage ());
            all_pages.add (new ShortcutsPage ());

            nav = new Gtk.ListBox () { selection_mode = Gtk.SelectionMode.SINGLE };
            nav.set_header_func ((row, before) => {
                var r = (NavRow) row;
                var b = before as NavRow;
                if (b == null || b.page.nav_section != r.page.nav_section) {
                    var heading = new Gtk.Label (r.page.nav_section) { xalign = 0 };
                    heading.get_style_context ().add_class ("nav-heading");
                    row.set_header (heading);
                } else {
                    row.set_header (null);
                }
            });
            for (int i = 0; i < all_pages.length; i++) {
                pages.add_named (all_pages[i], all_pages[i].page_id);
                nav.add (new NavRow (all_pages[i]));
            }
            nav.row_selected.connect ((row) => {
                var r = row as NavRow;
                if (r != null) {
                    pages.visible_child = r.page;
                }
            });

            results = new Gtk.ListBox () { selection_mode = Gtk.SelectionMode.NONE };
            results.row_activated.connect ((row) => {
                var hit = (HitRow) row;
                show_page (hit.page);
                hit.page.reveal (hit.row);
            });

            search = new Gtk.SearchEntry () {
                placeholder_text = _("Search settings"), margin = 10
            };
            search.search_changed.connect (run_search);
            search.stop_search.connect (() => {
                search.text = "";
            });

            side = new Gtk.Stack ();
            side.add_named (new Gtk.ScrolledWindow (null, null) { child = nav, hscrollbar_policy = Gtk.PolicyType.NEVER }, "nav");
            side.add_named (new Gtk.ScrolledWindow (null, null) { child = results, hscrollbar_policy = Gtk.PolicyType.NEVER }, "results");

            var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { width_request = 270 };
            sidebar.pack_start (search, false, false, 0);
            sidebar.pack_start (side, true, true, 0);

            var layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            layout.pack_start (sidebar, false, false, 0);
            layout.pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL), false, false, 0);
            layout.pack_start (pages, true, true, 0);
            add (layout);
            layout.show_all ();

            show_page (all_pages[0]);
        }

        public bool show_page_by_id (string id) {
            for (int i = 0; i < all_pages.length; i++) {
                if (all_pages[i].page_id == id) {
                    show_page (all_pages[i]);
                    return true;
                }
            }
            return false;
        }

        private void show_page (Page page) {
            nav.foreach ((child) => {
                if (((NavRow) child).page == page) {
                    nav.select_row ((Gtk.ListBoxRow) child);
                }
            });
        }

        private void run_search () {
            string needle = search.text.strip ().down ();
            results.foreach ((child) => results.remove (child));
            if (needle == "") {
                side.visible_child_name = "nav";
                return;
            }
            int found = 0;
            for (int p = 0; p < all_pages.length; p++) {
                var page = all_pages[p];
                bool page_matches = page.page_title.down ().contains (needle);
                for (int g = 0; g < page.groups.length; g++) {
                    var rows = page.groups[g].rows;
                    for (int r = 0; r < rows.length; r++) {
                        if (page_matches || rows[r].matches (needle)) {
                            var hit = new HitRow (page, rows[r]);
                            results.add (hit);
                            hit.show_all ();
                            found++;
                        }
                    }
                }
            }
            if (found == 0) {
                var none = new Gtk.Label (_("Nothing matches “%s”").printf (search.text.strip ())) { margin = 18 };
                none.get_style_context ().add_class ("row-subtitle");
                var row = new Gtk.ListBoxRow () { activatable = false, selectable = false };
                row.add (none);
                results.add (row);
                row.show_all ();
            }
            side.visible_child_name = "results";
        }

        private Gtk.Widget missing_schemas_view (string[] missing) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                halign = Gtk.Align.CENTER, valign = Gtk.Align.CENTER, margin = 40
            };
            box.pack_start (new Gtk.Image.from_icon_name ("dialog-warning-symbolic", Gtk.IconSize.DIALOG), false, false, 0);
            var title = new Gtk.Label (_("Polo's settings are not installed"));
            title.get_style_context ().add_class ("page-title");
            box.pack_start (title, false, false, 0);
            var text = new Gtk.Label (_("Polo Tweaks edits Polo's GSettings schemas, but these were not found:\n\n%s\n\nInstall Polo (or run glib-compile-schemas on its data directory) and start Polo Tweaks again.").printf (string.joinv ("\n", missing))) {
                wrap = true, max_width_chars = 60, justify = Gtk.Justification.CENTER
            };
            box.pack_start (text, false, false, 0);
            box.show_all ();
            return box;
        }

        private void confirm_reset_all () {
            var dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                                                Gtk.ButtonsType.NONE, _("Restore every Polo setting?"));
            dialog.format_secondary_text (_("All settings on every page, including keyboard shortcuts, go back to their original values."));
            dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
            dialog.add_button (_("_Restore All"), Gtk.ResponseType.ACCEPT);
            if (dialog.run () == Gtk.ResponseType.ACCEPT) {
                foreach (string id in Schemas.ALL) {
                    var settings = Schemas.get (id);
                    if (settings != null) {
                        Schemas.reset_schema (settings);
                    }
                }
            }
            dialog.destroy ();
        }

        private void show_about () {
            var dialog = new Gtk.AboutDialog () {
                transient_for = this,
                modal = true,
                program_name = _("Polo Tweaks"),
                version = Config.VERSION,
                comments = _("Settings for Polo's effects, desktop cube, Expo and keyboard shortcuts."),
                logo_icon_name = "preferences-system-windows",
                license_type = Gtk.License.GPL_3_0
            };
            dialog.run ();
            dialog.destroy ();
        }
    }
}
