/* FontConfig.vala
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

    public class Main : Object {

        public signal void changed (File? file, FileMonitorEvent event);
        public signal void progress (string? message, int processed, int total);

        public Accept accept { get; private set; }
        public Directories dirs { get; private set; }
        public Families families { get; private set; }
        public Reject reject { get; private set; }
        public Sources sources { get; private set; }

        private bool init_called = false;

        public Main () {
            accept = new Accept();
            dirs = new Directories();
            reject = new Reject();
            families = new Families();
            sources = new Sources();
            families.progress.connect((m, p, t) => { progress(m, p, t); });
            sources.changed.connect((f, e) => { changed(f, e); });
        }

        public void init () {
            if (init_called)
                return;
            accept.init();
            dirs.init();
            reject.init();
            sources.init();
            this.update();
            init_called = true;
            return;
        }

        public void update () {
            enable_user_config(false);
            load_user_fontconfig_files();
            sources.cancel_monitors();
            if (!load_user_font_sources(sources.to_array()))
                critical("Failed to register user font sources with FontConfig! User fonts may be unavailable for preview.");
            families.update();
            sources.enable_monitors();
            return;
        }

        public async bool async_update () throws ThreadError {
            SourceFunc callback = async_update.callback;
            bool output = true;
            ThreadFunc <void*> run = () => {
                lock(families) {
                    lock(sources) {
                        start_update();
                        if (!load_user_font_sources(sources.to_array())) {
                            critical("Failed to register user font sources with FontConfig! User fonts may be unavailable for preview.");
                            output = false;
                        }
                    }
                }
                end_update();
                Idle.add((owned) callback);
                return null;
            };

            new Thread <void*> ("FontConfig.async_update", run);
            yield;
            return output;
        }

        public void start_update () {
            enable_user_config(false);
            load_user_fontconfig_files();
            sources.cancel_monitors();
            return;
        }

        public void end_update () {
            families.update();
            sources.update();
            sources.enable_monitors();
            return;
        }

    }

    private string get_config_dir () {
        string config_dir = Path.build_filename(Environment.get_user_config_dir(), "fontconfig", "conf.d");
        DirUtils.create_with_parents(config_dir, 0755);
        return config_dir;
    }

    /*
     * This function loads any user configuration files which do not
     * interfere with our ability to render fonts properly.
     */
    private void load_user_fontconfig_files () {
        string [] exclude = {"78-Reject.conf"};
        try {
            string config_dir = get_config_dir();
            File directory = File.new_for_path(config_dir);
            FileEnumerator enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);
            GLib.FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                string filename = file_info.get_name();
                if (filename.has_suffix(".conf")) {
                    if (filename in exclude)
                        continue;
                    string filepath = Path.build_filename(config_dir, filename);
                    if (!load_config(filepath))
                        warning("Fontconfig : Failed to parse file : %s", filepath);
                }
            }
        } catch (Error e) {
            critical(e.message);
        }
        return;
    }

    private bool load_user_font_sources (FontSource [] sources) {
        clear_app_fonts();
        bool res = true;
        if (!add_app_font_dir(Path.build_filename(Environment.get_user_data_dir(), "fonts")))
            res = false;
        foreach (var source in sources)
            if (!add_app_font_dir(source.path))
                res = false;
        return res;
    }

}
