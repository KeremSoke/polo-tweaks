/* Which hot corners and edges fire on which screen: Polo's rules, for drawing them. */

namespace PoloTweaks {

    public const string[] HOT_SPOTS = { "top-left", "top-right", "bottom-left", "bottom-right",
                                        "top", "bottom", "left", "right" };

    public class HotEdgeRun {
        public int start;
        public int length;
    }

    public class HotScreenSpots {
        public bool allowed;
        public bool[] corner = new bool[4];
        public GenericArray<HotEdgeRun>[] edges = new GenericArray<HotEdgeRun>[4];
    }

    namespace HotGeometry {
        public int dir_x (int spot) {
            return spot == 0 || spot == 2 || spot == 6 ? -1 : (spot == 1 || spot == 3 || spot == 7 ? 1 : 0);
        }

        public int dir_y (int spot) {
            return spot == 0 || spot == 1 || spot == 4 ? -1 : (spot == 2 || spot == 3 || spot == 5 ? 1 : 0);
        }

        private bool on_screen (Gdk.Rectangle[] screens, int px, int py) {
            foreach (unowned Gdk.Rectangle s in screens) {
                if (px >= s.x && px < s.x + s.width && py >= s.y && py < s.y + s.height) {
                    return true;
                }
            }
            return false;
        }

        private void corner_point (Gdk.Rectangle s, int spot, out int x, out int y) {
            x = dir_x (spot) < 0 ? s.x : s.x + s.width - 1;
            y = dir_y (spot) < 0 ? s.y : s.y + s.height - 1;
        }

        private bool walled (Gdk.Rectangle[] screens, int index, int spot, out bool wall_x, out bool wall_y) {
            int x, y;
            corner_point (screens[index], spot, out x, out y);
            wall_x = !on_screen (screens, x + dir_x (spot), y);
            wall_y = !on_screen (screens, x, y + dir_y (spot));
            return wall_x && wall_y;
        }

        private int whole_area_owner (Gdk.Rectangle[] screens, int spot) {
            int left = int.MAX, top = int.MAX, right = int.MIN, bottom = int.MIN;
            foreach (unowned Gdk.Rectangle s in screens) {
                left = int.min (left, s.x);
                top = int.min (top, s.y);
                right = int.max (right, s.x + s.width - 1);
                bottom = int.max (bottom, s.y + s.height - 1);
            }
            int px = dir_x (spot) < 0 ? left : right;
            int py = dir_y (spot) < 0 ? top : bottom;
            int best = -1;
            int64 best_distance = int64.MAX;
            int64 best_area = -1;
            for (int i = 0; i < screens.length; i++) {
                bool wx, wy;
                if (!walled (screens, i, spot, out wx, out wy)) {
                    continue;
                }
                int x, y;
                corner_point (screens[i], spot, out x, out y);
                int64 dx = x - px;
                int64 dy = y - py;
                int64 distance = dx * dx + dy * dy;
                int64 area = (int64) screens[i].width * screens[i].height;
                if (distance < best_distance || (distance == best_distance && area > best_area)) {
                    best = i;
                    best_distance = distance;
                    best_area = area;
                }
            }
            return best;
        }

        private GenericArray<HotEdgeRun> edge_runs (Gdk.Rectangle[] screens, int index, int spot) {
            var runs = new GenericArray<HotEdgeRun> ();
            var s = screens[index];
            bool horizontal = dir_y (spot) != 0;
            int start = horizontal ? s.x : s.y;
            int end = start + (horizontal ? s.width : s.height);
            int line = horizontal ? (dir_y (spot) < 0 ? s.y : s.y + s.height - 1)
                                  : (dir_x (spot) < 0 ? s.x : s.x + s.width - 1);
            int run_start = -1;
            for (int along = start; along <= end; along++) {
                bool free = false;
                if (along < end) {
                    free = horizontal ? !on_screen (screens, along, line + dir_y (spot))
                                      : !on_screen (screens, line + dir_x (spot), along);
                }
                if (free && run_start < 0) {
                    run_start = along;
                } else if (!free && run_start >= 0) {
                    runs.add (new HotEdgeRun () { start = run_start - start, length = along - run_start });
                    run_start = -1;
                }
            }
            return runs;
        }

        public GenericArray<HotScreenSpots> compute (Gdk.Rectangle[] screens, bool[] allowed, string layout) {
            var result = new GenericArray<HotScreenSpots> ();
            for (int i = 0; i < screens.length; i++) {
                var spots = new HotScreenSpots () { allowed = allowed[i] };
                for (int e = 0; e < 4; e++) {
                    spots.edges[e] = allowed[i] ? edge_runs (screens, i, 4 + e) : new GenericArray<HotEdgeRun> ();
                }
                for (int c = 0; c < 4 && allowed[i]; c++) {
                    bool wx, wy;
                    bool both = walled (screens, i, c, out wx, out wy);
                    spots.corner[c] = layout == "every-screen" ? wx || wy : (layout == "whole-area" ? false : both);
                }
                result.add (spots);
            }
            if (layout == "whole-area") {
                for (int c = 0; c < 4; c++) {
                    int owner = whole_area_owner (screens, c);
                    if (owner >= 0 && allowed[owner]) {
                        result[owner].corner[c] = true;
                    }
                }
            }
            return result;
        }

        public bool screen_allowed (Settings hot, ScreenInfo screen) {
            switch (hot.get_string ("screens")) {
                case "primary":
                    return screen.primary;
                case "selected":
                    return screen.id in hot.get_strv ("selected-screens");
                default:
                    return true;
            }
        }

        public void set_screen_allowed (Settings hot, GenericArray<ScreenInfo> screens, ScreenInfo screen,
                                        bool on) {
            string[] chosen = {};
            string mode = hot.get_string ("screens");
            if (mode == "selected") {
                foreach (string id in hot.get_strv ("selected-screens")) {
                    if (id != screen.id) {
                        chosen += id;
                    }
                }
            } else {
                foreach (var other in screens) {
                    bool was_on = mode == "primary" ? other.primary : true;
                    if (other != screen && was_on) {
                        chosen += other.id;
                    }
                }
            }
            if (on) {
                chosen += screen.id;
            }
            bool every = true;
            foreach (var other in screens) {
                if (!(other.id in chosen)) {
                    every = false;
                }
            }
            hot.delay ();
            if (every && mode != "selected") {
                hot.set_string ("screens", "all");
                hot.reset ("selected-screens");
            } else {
                hot.set_strv ("selected-screens", chosen);
                hot.set_string ("screens", "selected");
            }
            hot.apply ();
        }
    }
}
