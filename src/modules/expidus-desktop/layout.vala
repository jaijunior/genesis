namespace ExpidusDesktop {
	public class WindowLayout : GenesisShell.WindowLayout {
		public override Gdk.Rectangle geometry {
			get {
				return { -5, -5, 20, 20 };
			}
		}
		
		public override GenesisCommon.LayoutWindowingMode windowing_mode {
			get {
				return GenesisCommon.LayoutWindowingMode.FLOATING;
			}
		}

		public WindowLayout(GenesisShell.Window win) {
			Object(window: win);
		}

		public override void draw(Cairo.Context cr) {
			GLib.message("We're rendering!");
		}
	}

	public class ShellLayout : GenesisShell.Layout {
		public override GenesisCommon.LayoutFlags flags {
			get {
				return GenesisCommon.LayoutFlags.WINDOW_DECORATION;
			}
		}

		public override string[] monitors {
			owned get {
				return this.shell.monitors;
			}
		}

		public override string name {
			get {
				return "desktop";
			}
		}

		public override bool try_last {
			get {
				return true;
			}
		}

		public override GenesisShell.WindowLayout? get_window_layout(GenesisShell.Window win) {
			return new WindowLayout(win);
		}
	}

	public class DesktopLayout : GenesisCommon.DesktopLayout {
		private GenesisWidgets.WallpaperSettings _wallpaper;

		public DesktopLayout(GenesisCommon.Shell shell, string monitor_name) {
			Object(shell: shell, monitor_name: monitor_name);
		}

		construct {
			this._wallpaper = new GenesisWidgets.WallpaperSettings();
			this._wallpaper.notify["image"].connect(() => this.queue_draw());
			this._wallpaper.notify["style"].connect(() => this.queue_draw());
		}

		public override void draw(Cairo.Context cr) {
			var geometry = this.monitor.geometry;
			cr.set_source_rgba(0.14, 0.15, 0.23, 1.0);
			cr.rectangle(0, 0, geometry.width, geometry.height);
			cr.fill();

			try {
				this._wallpaper.draw(cr, geometry.width, geometry.height);
			} catch (GLib.Error e) {}
		}
	}

	public class StatusPanelLayout : GenesisCommon.PanelLayout {
		private Gtk.Box _box;
		private GenesisWidgets.SimpleClock _clock;
		private GenesisWidgets.GlobalMenu _global_menu;
		private GLib.Settings _settings;
		
		public override Gdk.Rectangle geometry {
			get {
				var geo = this.monitor.geometry;
				return { 0, 0, geo.width, this.monitor.dpi(25) };
			}
		}

		public override GenesisCommon.PanelAnchor anchor {
			get {
				return GenesisCommon.PanelAnchor.TOP;
			}
		}

		public StatusPanelLayout(GenesisCommon.Shell shell, string monitor_name) {
			Object(shell: shell, monitor_name: monitor_name);
			
			this._settings = new GLib.Settings("com.expidus.genesis.desktop");

			this._box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			
			this._global_menu = new GenesisWidgets.GlobalMenu(shell);
			this._box.pack_start(this._global_menu, true, true, 0);

			this._clock = new GenesisWidgets.SimpleClock();
			this._settings.bind("clock-format", this._clock, "format", GLib.SettingsBindFlags.GET);
			this._clock.format = this._settings.get_string("clock-format");
			this._box.pack_end(this._clock, false, false, 0);
		}
		
		public override void attach(Gtk.Container widget) {
			widget.add(this._box);
			this._box.show_all();
		}
		
		public override void detach(Gtk.Container widget) {
			widget.remove(this._box);
		}

		public override void draw(Cairo.Context cr) {
			var geometry = this.geometry;
			cr.set_source_rgba(0.14, 0.15, 0.23, 1.0);
			cr.rectangle(0, 0, geometry.width, geometry.height);
			cr.fill();
			
			this._box.draw(cr);
		}
	}

	public class PolkitDialog : GenesisCommon.PolkitDialog {
		public PolkitDialog(GenesisCommon.Monitor monitor, string action_id, string message, string icon_name, string cookie, GLib.Cancellable? cancellable) {
			Object(monitor: monitor, action_id: action_id, message: message, icon_name: icon_name, cookie: cookie, cancellable: cancellable);
		}
	}

	public class ComponentLayout : GenesisCommon.Layout {
		public override GenesisCommon.LayoutFlags flags {
			get {
				return GenesisCommon.LayoutFlags.DESKTOP | GenesisCommon.LayoutFlags.PANEL | GenesisCommon.LayoutFlags.POLKIT_DIALOG;
			}
		}

		public override string[] monitors {
			owned get {
				return this.shell.monitors;
			}
		}

		public override string name {
			get {
				return "desktop";
			}
		}

		public override bool try_last {
			get {
				return true;
			}
		}

		public override GenesisCommon.DesktopLayout? get_desktop_layout(GenesisCommon.Monitor monitor) {
			return new DesktopLayout(monitor.shell, monitor.name);
		}

		public override GenesisCommon.PolkitDialog? get_polkit_dialog(GenesisCommon.Monitor monitor, string action_id, string message, string icon_name, string cookie, GLib.Cancellable? cancellable) {
			return new PolkitDialog(monitor, action_id, message, icon_name, cookie, cancellable);
		}

		public override GenesisCommon.PanelLayout? get_panel_layout(GenesisCommon.Monitor monitor, int i) {
			if (i == 0) return new StatusPanelLayout(monitor.shell, monitor.name);
			return null;
		}

		public override int get_panel_count(GenesisCommon.Monitor monitor) {
			return 1;
		}
	}
}