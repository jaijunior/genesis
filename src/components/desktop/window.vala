namespace Genesis {
    [DBus(name = "com.expidus.GenesisDesktopWindow")]
    public class DesktopWindow : Gtk.ApplicationWindow {
        private Gtk.Widget? _widget = null;
        private string _monitor_name;

        public string monitor_name {
            get {
                return this._monitor_name;
            }
            construct {
                this._monitor_name = value;
            }
        }

        public int monitor_index {
            get {
                var disp = this.get_display();
                for (var i = 0; i < disp.get_n_monitors(); i++) {
                    var mon = disp.get_monitor(i);
                    if (mon.geometry.equal(this.monitor.geometry)) return i;
                }
                return -1;
            }
        }

        [DBus(visible = false)]
        public unowned Gdk.Monitor? monitor {
            get {
                var disp = this.get_display();
                for (var i = 0; i < disp.get_n_monitors(); i++) {
                    unowned var mon = disp.get_monitor(i);
                    if (mon.get_model() == this.monitor_name) return mon;
                }

                int index = 0;
                if (int.try_parse(this.monitor_name, out index)) {
                    return disp.get_monitor(index);
                }
                return null;
            }
        }

        public class DesktopWindow(DesktopApplication application, string monitor_name) {
            Object(application: application, monitor_name: monitor_name);

            var mon = this.monitor;
            assert(mon != null);
            
            var rect = mon.geometry;

            this.get_style_context().add_class("genesis-shell-desktop");

            this.type_hint = Gdk.WindowTypeHint.DESKTOP;
            this.decorated = false;
			this.skip_pager_hint = true;
			this.skip_taskbar_hint = true;
            this.resizable = false;
            this.show_all();
            this.move(rect.x, rect.y);

            try {
                application.conn.register_object("/com/expidus/GenesisDesktop/window/%lu".printf(this.get_id()), this);
            } catch (GLib.Error e) {}

            GLib.Timeout.add(600, () => {
                this.update();
                return false;
            });

            GLib.Timeout.add(10000, () => {
                this.update();
                return true;
            });
        }

        public override void get_preferred_width(out int min_width, out int nat_width) {
            min_width = nat_width = this.monitor.geometry.width;
        }

        public override void get_preferred_width_for_height(int height, out int min_width, out int nat_width) {
			this.get_preferred_width(out min_width, out nat_width);
		}

        public override void get_preferred_height(out int min_height, out int nat_height) {
            min_height = nat_height = this.monitor.geometry.height;
        }

        public override void get_preferred_height_for_width(int width, out int min_height, out int nat_height) {
			this.get_preferred_height(out min_height, out nat_height);
		}

        [DBus(visible = false)]
        public void update() {
            if (this._widget != null) this.remove(this._widget);

            var app = this.application as DesktopApplication;
            assert(app != null);

            this._widget = app.component.get_default_widget(this.monitor_name);
            if (this._widget != null) {
                var style_ctx = this.get_style_context();
                var margins = style_ctx.get_margin(style_ctx.get_state());

                this._widget.margin_top = margins.top + this.monitor.workarea.y;
                this._widget.margin_start = margins.left + this.monitor.workarea.x;

                this._widget.margin_end = this.monitor.geometry.width - (margins.right + this.monitor.workarea.width + this.monitor.workarea.x);
                this._widget.margin_bottom = this.monitor.geometry.height - (margins.bottom + this.monitor.workarea.height + this.monitor.workarea.y);

                var self = this._widget as Gtk.Bin;
                if (self != null) {
                    var child = self.get_child();
                    if (child != null) {
                        style_ctx = child.get_style_context();
                        style_ctx.add_class("genesis-shell-desktop-content");
                    }
                }

                this.add(this._widget);
            }
        }

        [DBus(name = "Update")]
        public void dbus_update() throws GLib.Error {
            this.update();
        }
    }
}