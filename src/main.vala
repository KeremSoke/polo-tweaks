public class PoloTweaks.Application : Gtk.Application {
    public Application () {
        Object (application_id: "org.mate.PoloTweaks", flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        add_main_option ("page", 'p', OptionFlags.NONE, OptionArg.STRING,
                         "Open a page: general, hot-corners, wobbly, animations, expo, cube or shortcuts", "PAGE");
    }

    protected override int command_line (ApplicationCommandLine command_line) {
        string? page = null;
        command_line.get_options_dict ().lookup ("page", "s", out page);
        var window = (MainWindow?) active_window;
        if (window == null) {
            window = new MainWindow (this);
        }
        if (page != null && !window.show_page_by_id (page)) {
            command_line.printerr ("Unknown page “%s”\n", page);
        }
        window.present ();
        return 0;
    }
}

public int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (PoloTweaks.Config.DOMAIN, PoloTweaks.Config.LOCALEDIR);
    Intl.bind_textdomain_codeset (PoloTweaks.Config.DOMAIN, "UTF-8");
    Intl.textdomain (PoloTweaks.Config.DOMAIN);
    return new PoloTweaks.Application ().run (args);
}
