/* FontListTree.vala
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

    enum FontListColumn {
        TOGGLE,
        TEXT,
        PREVIEW,
        COUNT,
        N_COLUMNS
    }

    public class FontList : MultiDNDTreeView {

        public signal void font_selected (string description);

        public new weak Gtk.TreeStore? model {
            get {
                return _model;
            }
            set {
                _model = value;
                base.set_model(_model);
                select_first_row();
                if (controls.expanded)
                    expand_all();
            }
        }

        public weak FontConfig.Reject reject {
            get {
                return _reject;
            }
            set {
                _reject = value;
            }
        }

        public string selected_iter { get; protected set; default = "0"; }
        public FontData? fontdata { get; protected set; default = null; }
        public weak FontConfig.Family? selected_family { get; private set; default = null; }
        public weak FontConfig.Font? selected_font { get; private set; default = null; }
        public FontListControls controls { get; protected set; }

        private weak FontConfig.Reject _reject;
        private weak Gtk.TreeStore? _model = null;
        private Gtk.CellRendererToggle toggle;

        public FontList () {
            headers_visible = false;
            controls = new FontListControls();
            toggle = new Gtk.CellRendererToggle();
            var text = new Gtk.CellRendererText();
            var preview = new Gtk.CellRendererText();
            preview.ellipsize = Pango.EllipsizeMode.END;
            var count = new CellRendererCount();
            count.junction_side = Gtk.JunctionSides.RIGHT;
            insert_column_with_data_func(FontListColumn.TOGGLE, "", toggle, toggle_cell_data_func);
            insert_column_with_data_func(FontListColumn.TEXT, "", text, text_cell_data_func);
            insert_column_with_data_func(FontListColumn.PREVIEW, "", preview, preview_cell_data_func);
            insert_column_with_data_func(FontListColumn.COUNT, "", count, count_cell_data_func);
            get_column(FontListColumn.TOGGLE).expand = false;
            get_column(FontListColumn.TEXT).expand = false;
            get_column(FontListColumn.PREVIEW).expand = true;
            get_column(FontListColumn.COUNT).expand = false;
            set_enable_search(true);
            set_search_column(FontListColumn.TEXT);
            controls.show();
            connect_signals();
            set_search_entry(controls.entry);
        }

        private void connect_signals () {
            get_selection().changed.connect(on_selection_changed);
            toggle.toggled.connect(on_family_toggled);
            controls.expand_all.connect((e) => {
                if (e)
                    expand_all();
                else
                    collapse_all();
            });
            return;
        }

        public void select_first_row () {
            get_selection().select_path(new Gtk.TreePath.first());
            return;
        }

        public Gee.ArrayList <string> get_selected_families () {
            var selected = new Gee.ArrayList <string> ();
            List <Gtk.TreePath> _selected = get_selection().get_selected_rows(null);
            foreach (var path in _selected) {
                Value val;
                Gtk.TreeIter iter;
                model.get_iter(out iter, path);
                model.get_value(iter, FontModelColumn.OBJECT, out val);
                var obj = val.get_object();
                if (obj is FontConfig.Family)
                    selected.add(((FontConfig.Family) obj).name);
                else
                    selected.add(((FontConfig.Font) obj).family);
                val.unset();
            }
            return selected;
        }

        public override void drag_begin (Gdk.DragContext context) {
            Gtk.drag_set_icon_name(context, About.ICON, 0, 0);
            return;
        }

        private void on_selection_changed (Gtk.TreeSelection selection) {
            List <Gtk.TreePath> selected = selection.get_selected_rows(null);
            if (selected == null || selected.length() < 1)
                return;
            Gtk.TreePath path = selected.nth_data(0);
            Gtk.TreeIter iter;
            model.get_iter(out iter, path);
            Value val;
            model.get_value(iter, FontModelColumn.OBJECT, out val);
            string description;
            var obj = val.get_object();
            if (obj is FontConfig.Family) {
                description = ((FontConfig.Family) obj).description;
                selected_family = (FontConfig.Family) obj;
                selected_font = null;
            } else {
                description = ((FontConfig.Font) obj).description;
                selected_family = null;
                selected_font = (FontConfig.Font) obj;
            }
            try {
                if (selected_font != null) {
                    var fontinfo = get_fontinfo_from_db_entry(Main.instance.database, selected_font.filepath);
                    fontdata = {
                        File.new_for_path(selected_font.filepath),
                        selected_font,
                        fontinfo
                    };
                } else {
                    var target = selected_family.get_default_variant();
                    var fontinfo = get_fontinfo_from_db_entry(Main.instance.database, target.filepath);
                    fontdata = {
                        File.new_for_path(target.filepath),
                        target,
                        fontinfo
                    };
                }
            } catch (DatabaseError e) {
                warning(e.message);
                fontdata = null;
            }
            font_selected(description);
            selected_iter = model.get_string_from_iter(iter);
            val.unset();
            return;
        }

        private void on_family_toggled (string path) {
            Gtk.TreeIter iter;
            Value val;
            model.get_iter_from_string(out iter, path);
            model.get_value(iter, FontModelColumn.OBJECT, out val);
            var family = (FontConfig.Family) val.get_object();
            if (family.description in reject)
                reject.remove(family.description);
            else
                reject.add(family.description);
            reject.save();
            val.unset();
            queue_draw();
            return;
        }

        private void preview_cell_data_func (Gtk.TreeViewColumn layout,
                                    Gtk.CellRenderer cell,
                                    Gtk.TreeModel model,
                                    Gtk.TreeIter treeiter) {
            Value val;
            model.get_value(treeiter, FontModelColumn.OBJECT, out val);
            var obj = val.get_object();
        #if GTK_316_OR_LATER
            Pango.AttrList attrs = new Pango.AttrList();
            attrs.insert(Pango.attr_fallback_new(false));
            cell.set_property("attributes", attrs);
        #endif
            if (obj is FontConfig.Family) {
                cell.set_property("text", ((FontConfig.Family) obj).description);
                cell.set_property("ypad", 0);
                cell.set_property("xpad", 0);
                cell.set_property("visible", false);
                set_sensitivity(cell, treeiter, ((FontConfig.Family) obj).name);
            } else {
                cell.set_property("text", ((FontConfig.Font) obj).description);
                cell.set_property("ypad", 3);
                cell.set_property("xpad", 6);
                cell.set_property("visible", true);
                cell.set_property("font", ((FontConfig.Font) obj).description);
                set_sensitivity(cell, treeiter, ((FontConfig.Font) obj).family);
            }
            val.unset();
            return;
        }

        private void toggle_cell_data_func (Gtk.TreeViewColumn layout,
                                    Gtk.CellRenderer cell,
                                    Gtk.TreeModel model,
                                    Gtk.TreeIter treeiter) {
            Value val;
            model.get_value(treeiter, FontModelColumn.OBJECT, out val);
            var obj = val.get_object();
            if (obj is FontConfig.Family) {
                cell.set_property("visible", true);
                cell.set_property("sensitive", true);
                cell.set_property("active", !(reject.contains(((FontConfig.Family) obj).description)));
            } else
                cell.set_property("visible", false);
            val.unset();
            return;
        }

        private void text_cell_data_func (Gtk.TreeViewColumn layout,
                                    Gtk.CellRenderer cell,
                                    Gtk.TreeModel model,
                                    Gtk.TreeIter treeiter) {
            Value val;
            model.get_value(treeiter, FontModelColumn.OBJECT, out val);
            var obj = val.get_object();
            if (obj is FontConfig.Family) {
                cell.set_property("text", ((FontConfig.Family) obj).name);
                cell.set_property("ypad", 0);
                cell.set_property("xpad", 0);
                set_sensitivity(cell, treeiter, ((FontConfig.Family) obj).name);
            } else {
                cell.set_property("text", ((FontConfig.Font) obj).style);
                cell.set_property("ypad", 3);
                cell.set_property("xpad", 6);
                set_sensitivity(cell, treeiter, ((FontConfig.Font) obj).family);
            }
            val.unset();
            return;
        }

        private void count_cell_data_func (Gtk.TreeViewColumn layout,
                                    Gtk.CellRenderer cell,
                                    Gtk.TreeModel model,
                                    Gtk.TreeIter treeiter) {
            if (model.iter_has_child(treeiter)) {
                int count = 0;
                Gtk.TreeIter child;
                bool have_child = model.iter_children(out child, treeiter);
                while (have_child) {
                    count++;
                    have_child = model.iter_next(ref child);
                }
                cell.set_property("count", count);
                cell.set_property("visible", true);
            } else {
                cell.set_property("count", 0);
                cell.set_property("visible", false);
            }
            return;
        }

        private void set_sensitivity(Gtk.CellRenderer cell, Gtk.TreeIter treeiter, string family) {
            bool inactive = (family in reject);
            cell.set_property("strikethrough" , inactive);
            if (inactive && get_selection().iter_is_selected(treeiter))
                cell.set_property("sensitive" , true);
            else
                cell.set_property("sensitive" , !inactive);
            return;
        }

    }

    public class FontListTree : Gtk.Overlay {

        public FontList fontlist { get; private set; }
        public Gtk.ProgressBar progress { get; private set; }

        public bool loading {
            get {
                return _loading;
            }
            set {
                _loading = value;
                if (value)
                    progress.show();
                else
                    progress.hide();
            }
        }

        public bool show_controls {
            get {
                return revealer.get_reveal_child();
            }
            set {
                revealer.set_reveal_child(value);
            }
        }

        private bool _loading;
        private Gtk.Box _box;
        private Gtk.Box fontlist_box;
        private Gtk.Revealer revealer;
        private Gtk.ScrolledWindow scroll;
//        private Gtk.Menu context_menu;

        public FontListTree () {
            expand = true;
            scroll = new Gtk.ScrolledWindow(null, null);
            fontlist = new FontList();
            fontlist.expand = true;
            progress = new Gtk.ProgressBar();
            progress.halign = progress.valign = Gtk.Align.CENTER;
            get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
            revealer = new Gtk.Revealer();
            revealer.expand = false;
            fontlist_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            _box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            _box.pack_start(fontlist.controls, false, true, 0);
            revealer.add(_box);
            fontlist_box.pack_start(revealer, false, true, 0);
            scroll.add(fontlist);
            fontlist_box.pack_end(scroll, true, true, 0);
            add(fontlist_box);
            add_overlay(progress);
//            context_menu = get_context_menu();
//            connect_signals();
        }

        public override void show () {
            _box.show();
            fontlist_box.show();
            revealer.show();
            scroll.show();
            fontlist.show();
            base.show();
            return;
        }

//        private void connect_signals () {
//            fontlist.menu_request.connect((w, e) => {
//                context_menu.popup(null, null, null, e.button, e.time);
//            });
//            return;
//        }

//        private Gtk.Menu get_context_menu () {
//            MenuEntry [] context_menu_entries = {
//                /* action_name, display_name, detailed_action_name, accelerator, method */
//                MenuEntry("font_details", _("Show Details"), "app.font_details", null, new MenuCallbackWrapper(on_show_details)),
//            };
//            var _menu = new Gtk.Menu();
//            foreach (var entry in context_menu_entries) {
//                var item = new Gtk.MenuItem.with_label(entry.display_name);
//                item.activate.connect(() => { entry.method.run(); });
//                item.show();
//                _menu.append(item);
//            }
//            return _menu;
//        }

//        public void on_show_details () {
//            message("%s", fontlist.selected_font != null ? fontlist.selected_font.filepath: fontlist.selected_family.name);
//        }

    }

}

