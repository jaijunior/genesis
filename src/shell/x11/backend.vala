namespace Genesis.X11 {
    public class Backend : GLib.Object, Genesis.ShellBackend {
        private Genesis.Shell _shell;

        private Xcb.Connection _conn;
        private int _def_screen;
        private Xcb.RandR.Connection _randr;

        private GLib.HashTable<string, Monitor> _monitors;
        private GLib.HashTable<string, Xcb.Atom?> _atoms;
        private GLib.List<Window*> _windows;

        public Xcb.Connection conn {
            get {
                return this._conn;
            }
        }

        public Xcb.RandR.Connection randr {
            get {
                return this._randr;
            }
        }

        public GLib.List<weak Genesis.MonitorBackend> monitors {
            owned get {
                var list = this._monitors.get_values();
                return list;
            }
        }

        public GLib.List<Genesis.WindowBackend> windows {
            get {
                return this._windows;
            }
        }

        public Backend(Genesis.Shell shell) throws Genesis.ShellError {
            Object();

            this._shell = shell;
            this._conn = new Xcb.Connection(null, out this._def_screen);
            assert(this._conn != null);
            if (this._conn.has_error() > 0) {
                throw new Genesis.ShellError.BACKEND("Failed to connect");
            }

            this._randr = Xcb.RandR.get_connection(this._conn);
            assert(this._randr != null);

            var def_screen = this.get_default_screen();
            uint32[] values = { Xcb.EventMask.SUBSTRUCTURE_REDIRECT | Xcb.EventMask.SUBSTRUCTURE_NOTIFY | Xcb.EventMask.STRUCTURE_NOTIFY };
            var cwa_cookie = this._conn.change_window_attributes_checked(def_screen.root, Xcb.CW.EVENT_MASK, values);
            var error = this._conn.request_check(cwa_cookie);
            if (error != null) {
                throw new Genesis.ShellError.BACKEND("A compositor is already running");
            }

            this._monitors = new GLib.HashTable<string, Monitor>(GLib.str_hash, GLib.str_equal);
            this._atoms = new GLib.HashTable<string, Xcb.Atom?>(GLib.str_hash, GLib.str_equal);
            this._windows = new GLib.List<Window*>();

            var res_cookie = this._randr.get_screen_resources(def_screen.root);

            var res = this._randr.get_screen_resources_reply(res_cookie, out error);
            if (error == null) {
                foreach (var output in res.outputs) {
                    var monitor = new Monitor(this, output);
                    this._monitors.insert(monitor.name, monitor);
                }
            } else {
                throw new Genesis.ShellError.BACKEND("Failed to retrieve RandR screen resources");
            }

            this._randr.select_input(def_screen.root, Xcb.RandR.NotifyMask.SCREEN_CHANGE);

            var main_ctx = GLib.MainContext.@default();
            var events = new GLib.IOSource(new GLib.IOChannel.unix_new(this._conn.get_file_descriptor()), GLib.IOCondition.IN);
            events.set_callback(() => {
                var ev = this._conn.poll_for_event();
                if (ev == null) return true;

                if ((ev.response_type & Xcb.RandR.NotifyMask.SCREEN_CHANGE) != 0) {
                    bool[] monitor_states = {};
                    foreach (var monitor in this._monitors.get_values()) {
                        if (monitor.previous_state != monitor.connected) {
                            monitor.update();
                            monitor.connection_changed();
                            monitor_states += true;
                        } else {
                            monitor_states += false;
                        }
                    }
                    this.monitors_changed(monitor_states);
                } else {
                    stdout.printf("Event %d\n", ev.response_type);
                    switch (ev.response_type & ~0x80) {
                        case Xcb.CREATE_NOTIFY:
                            {
                                var _ev = (Xcb.CreateNotifyEvent)ev;
                                this.add_window(_ev.window);
                            }
                            break;
                        case Xcb.CONFIGURE_REQUEST:
                            {
                                var _ev = (Xcb.ConfigureRequestEvent)ev;
                                this.add_window(_ev.window);
                            }
                            break;
                        case Xcb.CONFIGURE_NOTIFY:
                            {
                                var _ev = (Xcb.ConfigureNotifyEvent)ev;
                                this.add_window(_ev.window);
                            }
                            break;
                        case Xcb.MAP_REQUEST:
                            {
                                var _ev = (Xcb.MapRequestEvent)ev;
                                var win = this.find_window(_ev.window);
                                if (win == null) {
                                    var cookie = this._conn.map_window_checked(_ev.window);
                                    error = this._conn.request_check(cookie);
                                    if (error != null) {
                                        stderr.printf("Failed to map window %lu\n", _ev.window);
                                    } else {
                                        stdout.printf("Mapped window\n");
                                    }
                                } else {
                                    win->map_request();
                                }
                            }
                            break;
                        case Xcb.UNMAP_NOTIFY:
                            {
                                var _ev = (Xcb.UnmapNotifyEvent)ev;
                                var win = this.find_window(_ev.window);
                                if (win != null) {
                                    this._windows.remove(win);
                                    delete win;
                                }
                            }
                            break;
                        default:
                            break;
                    }
                }

                this._conn.flush();
                return true;
            });
            events.attach(main_ctx);
        }

        public Window* find_window(Xcb.Window wid) {
            foreach (var win in this._windows) {
                if (win->wid == wid) {
                    return win;
                }
            }

            return null;
        }

        public void add_window(Xcb.Window wid) {
            if (this.find_window(wid) == null) {
                Window* win = new Window(this, wid);
                this._windows.append(win);
                this.window_added(win);
            }
        }

        public Xcb.Screen get_default_screen() {
            return this._conn.get_setup().screens[this._def_screen];
        }

        public Xcb.Atom? get_atom(string name) {
            if (this._atoms.contains(name)) {
                return this._atoms.get(name);
            }

            Xcb.GenericError? error = null;
            var atom_cookie = this._conn.intern_atom(false, name);
            var atom = this._conn.intern_atom_reply(atom_cookie, out error);
            if (error != null) return null;

            this._atoms.insert(name, atom.atom);
            return atom.atom;
        }
    }

    [Compact]
    [CCode(cname = "_xcb_randr_screen_change_notify_event_t")]
    public class xcb_randr_screen_change_notify_event {
        public uint8 response_type;
        public uint8 rotation;
        public uint16 sequence;
        public Xcb.Timestamp timestamp;
        public Xcb.Timestamp config_timestamp;
        public Xcb.Window root;
        public Xcb.Window request_window;
        public uint16 size_id;
        public uint16 subpixel_order;
        public uint16 width;
        public uint16 height;
        public uint16 mwidth;
        public uint16 mheight;
    }
}