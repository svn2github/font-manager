/* WaterfallPreview.vala
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

namespace FontManager {

    public class WaterfallPreview : StaticTextView {

        public string pangram {
            get {
                return _pangram;
            }
            set {
                _pangram = "%s\n".printf(value);
                this.update();
            }
        }

        private string _pangram;

        public WaterfallPreview (StandardTextTagTable tag_table) {
            base(tag_table);
            view.pixels_above_lines = 1;
            view.wrap_mode = Gtk.WrapMode.NONE;
            pangram = get_localized_pangram();
        }

        public void update () {
            buffer.set_text("", -1);
            Gtk.TextIter iter;
            for (int i = (int) MIN_FONT_SIZE; i <= MAX_FONT_SIZE; i++) {
                var line = i.to_string();
                string point;
                if (i < 10)
                    point = "%spt.   ".printf(line);
                else
                    point = "%spt.  ".printf(line);
                buffer.get_iter_at_line(out iter, i);
        #if VALA_0271_OR_LATER
                buffer.insert_with_tags_by_name(ref iter, point, -1, "SizePoint", null);
        #else
                buffer.insert_with_tags_by_name(iter, point, -1, "SizePoint", null);
        #endif
                if (tag_table.lookup(line) == null)
                    buffer.create_tag(line, "size-points", (double) i, null);
                buffer.get_end_iter(out iter);
        #if VALA_0271_OR_LATER
                buffer.insert_with_tags_by_name(ref iter, _pangram, -1, line, "FontDescription", null);
        #else
                buffer.insert_with_tags_by_name(iter, _pangram, -1, line, "FontDescription", null);
        #endif
            }
        #if GTK_316_OR_LATER
            Gtk.TextIter start, end;
            buffer.get_bounds(out start, out end);
            buffer.apply_tag(this.tag_table.lookup("FontFallback"), start, end);
        #endif
            return;
        }

    }

}
