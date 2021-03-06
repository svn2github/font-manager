/* FontSource.vala
 *
 * Copyright (C) 2009 - 2015 Jerry Casiano
 *
 * This file is part of Font Manager.
 *
 * Font Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Font Manager is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Font Manager.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 *        Jerry Casiano <JerryCasiano@gmail.com>
*/

namespace FontConfig {

    public class FontSource : Object {

        public signal void changed ();

        public new string name {
            get {
                return _name != null ? _name : _path;
            }
        }

        public string icon_name {
            get {
                if (filetype == FileType.DIRECTORY || filetype == FileType.MOUNTABLE)
                    return "folder-symbolic";
                else
                    return "font-x-generic";
            }
        }

        public new string condition {
            get {
                return _condition;
            }
        }

        /* XXX : Fix this! */
        public new bool active {
            get {
                if (filetype == FileType.REGULAR || filetype == FileType.SYMBOLIC_LINK) {
                    return false;
                } else if (filetype == FileType.DIRECTORY || filetype == FileType.MOUNTABLE) {
                    return (path in list_user_dirs());
                } else {
                    return false;
                }
            }
            set {
                var main = FontManager.Main.instance;
                main.fontconfig.init();
                if (value)
                    main.fontconfig.dirs.add(path);
                else
                    main.fontconfig.dirs.remove(path);
                main.fontconfig.dirs.save();
            }
        }

        public string uri {
            get {
                return _uri;
            }
        }

        public string path {
            get {
                return _path;
            }
        }

        public FileType filetype {
            get {
                return _filetype;
            }
        }

        public bool available {
            get {
                return _available;
            }
            set {
                _available = value;
            }
        }

        private File? file = null;
        private string? _name = null;
        private string? _uri = null;
        private string? _path = null;
        private string? _condition = null;
        private FileType _filetype;
        private bool _available = true;

        public FontSource (File file) {
            this.file = file;
            this.update();
        }

        public void update () {
            _uri = file.get_uri();
            _path = file.get_path();
            var pattern = "\"%" + "%s".printf(file.get_path()) + "%\"";
            _condition = "filepath LIKE %s".printf(pattern);
            try {
                FileInfo info = file.query_info(FileAttribute.STANDARD_DISPLAY_NAME, FileQueryInfoFlags.NONE);
                _name = Markup.escape_text(info.get_display_name());
                _filetype = file.query_file_type(FileQueryInfoFlags.NONE);
                available = true;
            } catch (Error e) {
                _name = _("%s --> Resource Unavailable").printf(_path);
                available = false;
            }
            changed();
            return;
        }

    }

}
