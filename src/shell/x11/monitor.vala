namespace Genesis.X11 {
    public class Monitor : Genesis.MonitorBackend {
        private Backend _backend;
        private Xcb.RandR.Output _output;
        private string _name;

        public override string name {
            get {
                return this._name;
            }
        }

        public override bool connected {
            get {
                var info_cookie = this._backend.randr.get_output_info(this._output, 0);
                var info = this._backend.randr.get_output_info_reply(info_cookie);
                return info.connection == Xcb.RandR.ConnectionState.CONNECTED;
            }
        }
        
        public override Genesis.RectangleUint32 physical_rect {
            get {
                var info_cookie = this._backend.randr.get_output_info(this._output, 0);
                var info = this._backend.randr.get_output_info_reply(info_cookie);
                Genesis.RectangleUint32 rect = { 0, 0, info.mm_width, info.mm_height };
                return rect;
            }
        }

        public override Genesis.RectangleUint16 resolution {
            get {
                var info_cookie = this._backend.randr.get_output_info(this._output, 0);
                var info = this._backend.randr.get_output_info_reply(info_cookie);

                var crtc_cookie = this._backend.randr.get_crtc_info(info.crtc, 0);
                var crtc = this._backend.randr.get_crtc_info_reply(crtc_cookie);

                Genesis.RectangleUint16 rect = { crtc.x, crtc.y, crtc.width, crtc.height };
                return rect;
            }
        }

        public Monitor(Backend backend, Xcb.RandR.Output output) {
            Object();

            this._backend = backend;
            this._output = output;

            var info_cookie = this._backend.randr.get_output_info(this._output, 0);
            var info = this._backend.randr.get_output_info_reply(info_cookie);
            this._name = info.name;
        }

        public new string to_string() {
            var str = base.to_string();
            str += "\n";

            Xcb.GenericError? error = null;
            var props_cookie = this._backend.randr.list_output_properties(this._output);
            var props = this._backend.randr.list_output_properties_reply(props_cookie);
            for (var i = 0; i < props.atoms.length; i++) {
                error = null;
                var atom_name_cookie = this._backend.conn.get_atom_name(props.atoms[i]);
                var atom_name = this._backend.conn.get_atom_name_reply(atom_name_cookie, out error);
                if (error != null) continue;
                
                str += "\t" + atom_name.name;
                if ((i + 1) != props.atoms.length) str += "\n";
            }
            return str;
        }
    }
}