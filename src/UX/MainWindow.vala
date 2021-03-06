/* MainWindow.vala
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

    public enum Mode {
        MANAGE,
        BROWSE,
        CHARACTER_MAP,
        COMPARE,
        ORGANIZE,
        WEB,
        N_MODES;

        public static Mode parse (string mode) {
            switch (mode.down()) {
                case "browse":
                    return Mode.BROWSE;
                case "compare":
                    return Mode.COMPARE;
                case "character map":
                    return Mode.CHARACTER_MAP;
                default:
                    return Mode.MANAGE;
            }
        }

        public string to_string () {
            switch (this) {
                case BROWSE:
                    return "Browse";
                case COMPARE:
                    return "Compare";
                case CHARACTER_MAP:
                    return "Character Map";
                default:
                    return "Default";
            }
        }

        public string to_translatable_string () {
            switch (this) {
                case BROWSE:
                    return _("Browse");
                case COMPARE:
                    return _("Compare");
                case CHARACTER_MAP:
                    return _("Character Map");
                default:
                    return _("Manage");
            }
        }

        public string [] settings () {
            switch (this) {
                case BROWSE:
                    return { "Browse", "Default", "Default" };
                case COMPARE:
                    return { "Default", "Compare",  "Default"};
                case CHARACTER_MAP:
                    return { "Default", "Character Map", "Character Map"};
                default:
                    return { "Default", "Default", "Default" };
            }
        }

    }

    public class MainWindow : Gtk.ApplicationWindow {

        public signal void mode_changed (int new_mode);

        public Gtk.Stack main_stack { get; private set; }
        public Gtk.Stack content_stack { get; private set; }
        public Gtk.Stack view_stack { get; private set; }

        public Gtk.Box main_box { get; private set; }
        public Gtk.Box content_box { get; private set; }

        public ThinPaned main_pane { get; private set; }
        public ThinPaned content_pane { get; private set; }
        public Browse browser { get; private set; }
        public Compare compare { get; private set; }
        public FontPreview preview { get; private set; }
        public CharacterMap character_map { get; private set; }
        public SideBar sidebar { get; private set; }
        public TitleBar titlebar { get; private set; }
        public FontList fontlist { get; private set; }
        public FontListTree fonttree { get; private set; }
        public UserSourceList user_source_list { get; private set; }
        public Metadata.Pane metadata { get; private set; }
        public State state { get; private set; }

        public Mode mode {
            get {
                return _mode;
            }
            set {
                real_set_mode(value, loading);
            }
        }

        public weak FontModel? font_model {
            get {
                return (FontModel) fontlist.model;
            }
            set {
                fontlist.model = browser.model = value;
            }
        }

        public weak CollectionModel? collections {
            get {
                return sidebar.standard.collection_tree.model;
            }
            set {
                sidebar.standard.collection_tree.model = value;
            }
        }

        public weak CategoryModel? categories {
            get {
                return sidebar.standard.category_tree.model;
            }
            set {
                sidebar.standard.category_tree.model = value;
            }
        }

        public FontConfig.Reject reject {
            get {
                return fontlist.reject;
            }
            set {
                fontlist.reject = browser.reject =
                sidebar.standard.collection_tree.reject = value;
            }
        }

        public double progress {
            get {
                return _progress;
            }
            set {
                _progress = value;
                browser.progress.set_fraction(value);
                fonttree.progress.set_fraction(value);
                if (value >= 0.99) {
                    browser.loading = false;
                    fonttree.loading = false;
                }
                ensure_ui_update();
            }
        }

        public bool loading {
            get {
                return _loading;
            }
            set {
                _loading = value;
                if (mode != Mode.CHARACTER_MAP)
                    sidebar.loading = value;
                browser.loading = value;
                fonttree.loading = value;
            }
        }

        private bool _loading = false;
        private bool sidebar_switch = false;
        private double _progress = 0.0;
        private Mode _mode;
        private Gtk.Box separator;
        private Gtk.Box _main_pane_;
        private Unsorted? unsorted = null;
        private Disabled? disabled = null;

        construct {
            title = About.NAME;
            type = Gtk.WindowType.TOPLEVEL;
        }

        public MainWindow () {
            init_components();
            pack_components();
            add(main_box);
            connect_signals();
            state = new State(this, Main.instance.settings);
        }

        private void init_components () {
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            main_pane = new ThinPaned(Gtk.Orientation.HORIZONTAL);
            content_pane = new ThinPaned(Gtk.Orientation.VERTICAL);
            browser = new Browse();
            compare = new Compare();
            preview = new FontPreview();
            character_map = new CharacterMap();
            sidebar = new SideBar();
            sidebar.add_view(new MainSideBar(), "Default");
            sidebar.add_view(character_map.sidebar, "Character Map");
            titlebar = new TitleBar();
            fonttree = new FontListTree();
            user_source_list = new UserSourceList();
            metadata = new Metadata.Pane();
            fontlist = fonttree.fontlist;
            main_stack = new Gtk.Stack();
            main_stack.set_transition_duration(720);
            main_stack.set_transition_type(Gtk.StackTransitionType.UNDER_UP);
            view_stack = new Gtk.Stack();
            view_stack.add_titled(preview, "Default", _("Preview"));
            view_stack.add_titled(compare, "Compare", _("Compare"));
            view_stack.add_titled(character_map.pane, "Character Map", _("Character Map"));
            view_stack.add_titled(metadata, "Metadata", "Metadata");
            view_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE);
            content_stack = new Gtk.Stack();
            content_stack.set_transition_duration(420);
            content_stack.add_titled(content_pane, "Default", _("Manage"));
            content_stack.add_titled(browser, "Browse", _("Browse"));
            content_stack.set_transition_type(Gtk.StackTransitionType.OVER_LEFT);
            return;
        }

        private void pack_components () {
            main_pane.add1(sidebar);
            main_pane.add2(content_box);
            add_separator(content_box, Gtk.Orientation.VERTICAL);
            content_box.pack_end(content_stack, true, true, 0);
            content_pane.add1(fonttree);
            separator = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            add_separator(separator, Gtk.Orientation.HORIZONTAL);
            separator.pack_end(view_stack, true, true, 0);
            content_pane.add2(separator);
            _main_pane_ = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            _main_pane_.pack_start(main_pane, true, true, 0);
            add_separator(_main_pane_, Gtk.Orientation.HORIZONTAL);
            main_stack.add_named(_main_pane_, "Default");
            main_stack.add_named(user_source_list, "Sources");
            main_box.pack_end(main_stack, true, true, 0);
            /* XXX: Should be true by default? It's not... */
            main_pane.child_set_property(sidebar, "resize", true);
            main_pane.child_set_property(content_box, "resize", true);
            content_pane.child_set_property(fonttree, "resize", true);
            content_pane.child_set_property(separator, "resize", true);
            if (Gnome3()) {
                set_titlebar(titlebar);
            } else {
                main_box.pack_start(titlebar, false, true, 0);
                add_separator(main_box, Gtk.Orientation.HORIZONTAL);
                titlebar.use_toolbar_styling();
            }
            return;
        }

        public override void show () {
            separator.show();
            _main_pane_.show();
            content_stack.show();
            view_stack.show();
            main_box.show();
            content_box.show();
            main_pane.show();
            content_pane.show();
            browser.show();
            compare.show();
            preview.show();
            character_map.show();
            sidebar.show();
            titlebar.show();
            fonttree.show();
            user_source_list.show();
            metadata.show();
            main_stack.show();
            state.restore();
            base.show();
            return;
        }

        public void unset_all_models () {
            font_model = null;
            categories = null;
            return;
        }

        public void set_all_models () {
            font_model = Main.instance.font_model;
            collections = Main.instance.collection_model;
            categories = Main.instance.category_model;
            user_source_list.sources = Main.instance.fontconfig.sources;
            return;
        }

        private void real_set_mode (Mode mode, bool loading) {
            _mode = mode;
            titlebar.source_toggle.set_active(false);
            titlebar.main_menu_label.set_markup("<b>%s</b>".printf(mode.to_translatable_string()));
            var settings = mode.settings();
            /* XXX */
            content_stack.set_visible_child_name(settings[0]);
            view_stack.set_visible_child_name(settings[1]);
            sidebar.mode = settings[2];
            sidebar.loading = (mode != Mode.CHARACTER_MAP) ? loading : false;
            sidebar.standard.reveal_collection_controls((mode == Mode.MANAGE));
            titlebar.reveal_controls((mode == Mode.MANAGE));
            fonttree.show_controls = (mode != Mode.BROWSE);
            fontlist.controls.set_remove_sensitivity((mode == Mode.MANAGE && sidebar.standard.mode == MainSideBarMode.COLLECTION));
            fontlist.controls.set_metadata_sensitivity((mode == Mode.MANAGE));
            fontlist.queue_draw();
            if (mode == Mode.BROWSE)
                browser.treeview.queue_draw();
            mode_changed(_mode);
            return;
        }

        private void update_font_model (Filter? filter) {
            if (filter == null)
                return;
            font_model = null;
            Main.instance.font_model.update(filter);
            font_model = Main.instance.font_model;
            fonttree.fontlist.select_first_row();
            browser.expand_all();
            return;
        }

        private void set_font_desc (Pango.FontDescription font_desc) {
            preview.font_desc = font_desc;
            compare.font_desc = font_desc;
            character_map.font_desc = font_desc;
            /* XXX : Workaround zoom breakage... */
            character_map.preview_size++;
            character_map.preview_size--;
            return;
        }

        private Category get_category_by_index (int index) {
            Value val;
            Gtk.TreeIter iter;
            Main.instance.category_model.get_iter_from_string(out iter, index.to_string());
            Main.instance.category_model.get_value(iter, 0, out val);
            var result = (Category) val.get_object();
            val.unset();
            return result;
        }

        private void update_unsorted_category () {
            if (unsorted == null)
                unsorted = (Unsorted) get_category_by_index(11);
            var collections = Main.instance.collections;
            unsorted.update(Main.instance.database, collections.get_full_contents());
            return;
        }

        private void update_disabled_category () {
            if (disabled == null)
                disabled = (Disabled) get_category_by_index(12);
            disabled.update(Main.instance.database, Main.instance.fontconfig.reject);
            return;
        }

        private void connect_signals () {
            mode_changed.connect((m) => {
                var action_map = (Application) GLib.Application.get_default();
                var action = ((SimpleAction) action_map.lookup_action("mode"));
                action.set_state(((Mode) m).to_string());
            });

            sidebar.standard.collection_tree.rename_collection.connect((c, n) => {
                Main.instance.collections.rename_collection(c, n);
            });

            sidebar.standard.category_selected.connect((c, i) => {
                if (font_model == null)
                    return;
                if (c is Unsorted)
                    update_unsorted_category();
                else if (c is Disabled)
                    update_disabled_category();
                update_font_model(c);
                }
            );
            sidebar.standard.collection_selected.connect((c) => {
                if (font_model == null)
                    return;
                update_font_model(c);
                }
            );
            sidebar.standard.mode_selected.connect(() => {
                /* XXX */
                if (font_model == null || sidebar_switch)
                    return;
                var m = sidebar.standard.mode;
                if (m == MainSideBarMode.CATEGORY)
                    update_font_model(sidebar.standard.selected_category);
                else
                    update_font_model(sidebar.standard.selected_collection);
                fontlist.controls.set_remove_sensitivity(mode == Mode.MANAGE && m == MainSideBarMode.COLLECTION);
                }
            );

            fontlist.font_selected.connect((string_desc) => {
                set_font_desc(Pango.FontDescription.from_string(string_desc));
                if (view_stack.get_visible_child_name() == "Metadata")
                    metadata.update(fontlist.fontdata);
            });

            fontlist.controls.remove_selected.connect(() => {
                sidebar.standard.collection_tree.remove_fonts(fontlist.get_selected_families());
                update_font_model(sidebar.standard.collection_tree.selected_collection);
            });

            fontlist.enable_model_drag_dest(AppDragTargets, AppDragActions);
            fontlist.enable_model_drag_source(Gdk.ModifierType.BUTTON1_MASK | Gdk.ModifierType.RELEASE_MASK, AppDragTargets, AppDragActions);
            var collections = sidebar.standard.collection_tree.tree;
            /* Let GTK+ handle re-ordering */
            collections.set_reorderable(true);

            fontlist.drag_data_received.connect(on_drag_data_received);
            fontlist.drag_begin.connect((w, c) => {
                /* When reorderable is set no other drag and drop is possible.
                 * Temporarily disable it and set the treeview up as a drag destination.
                 */
                collections.set_reorderable(false);
                collections.enable_model_drag_dest(AppDragTargets, AppDragActions);
                if (sidebar.standard.mode == MainSideBarMode.CATEGORY) {
                    sidebar_switch = true;
                    sidebar.standard.mode = MainSideBarMode.COLLECTION;
                }
            });
            fontlist.drag_end.connect((w, c) => {
                if (sidebar_switch) {
                    Idle.add(() => {
                        sidebar.standard.mode = MainSideBarMode.CATEGORY;
                        return false;
                    });
                    sidebar_switch = false;
                }
                collections.set_reorderable(true);
            });
            collections.drag_data_received.connect(on_drag_data_received);

            sidebar.standard.collection_tree.update_ui.connect(() => {
                sidebar.standard.collection_tree.queue_draw();
                fontlist.queue_draw();
                browser.queue_draw();
            });

            sidebar.standard.collection_tree.changed.connect(() => {
                update_unsorted_category();
            });

            titlebar.install_selected.connect(() => {
                var selected = FileSelector.run_install((Gtk.Window) this);
                if (selected.length > 0)
                    install_fonts(selected);
            });

            titlebar.add_selected.connect(() => {
                user_source_list.on_add_source();
            });

            titlebar.remove_selected.connect(() => {
                if (titlebar.source_toggle.get_active())
                    user_source_list.on_remove_source();
                else
                    remove_fonts();
            });

            titlebar.manage_sources.connect((a) => {
                if (a)
                    main_stack.set_visible_child_name("Sources");
                else
                    main_stack.set_visible_child_name("Default");
            });

            view_stack.notify["visible-child-name"].connect(() => {
                if (view_stack.get_visible_child_name() == "Metadata")
                    metadata.update(fontlist.fontdata);
            });

            main_stack.notify["visible-child-name"].connect(() => {
                if (main_stack.get_visible_child_name() == "Default")
                    main_stack.set_transition_type(Gtk.StackTransitionType.UNDER_UP);
                else
                    main_stack.set_transition_type(Gtk.StackTransitionType.OVER_DOWN);
            });

            content_stack.notify["visible-child-name"].connect(() => {
                if (content_stack.get_visible_child_name() == "Default")
                    content_stack.set_transition_type(Gtk.StackTransitionType.OVER_LEFT);
                else
                    content_stack.set_transition_type(Gtk.StackTransitionType.UNDER_RIGHT);
            });

            fontlist.controls.show_metadata.connect((s) => {
                if (s)
                    view_stack.set_visible_child_name("Metadata");
                else
                    view_stack.set_visible_child_name(mode.settings()[1]);
            });

            Main.instance.fontconfig.reject.changed.connect(() => {
                update_disabled_category();
                if (sidebar.standard.category_tree.selected_filter is Disabled)
                    update_font_model(sidebar.standard.category_tree.selected_filter);
            });

        }

        private void remove_fonts () {
            var _model = new UserFontModel(Main.instance.fontconfig.families, Main.instance.database);
            var arr = FileSelector.run_removal((Gtk.Window) this, _model);
            if (arr != null) {
                /* Avoid empty boxes and Pango warnings when removing fonts */
                unset_all_models();
                set_font_desc(Pango.FontDescription.from_string(DEFAULT_FONT));
                fonttree.progress.set_fraction(0f);
                loading = true;
                Library.progress = (m, p, t) => {
                    fonttree.progress.set_fraction((float) p / (float) t);
                    ensure_ui_update();
                };
                Main.instance.fontconfig.sources.cancel_monitors();
                Library.Remove.from_file_array(arr);
                queue_reload();
            }
            return;
        }

        private void install_fonts (string [] arr) {
            fonttree.loading = true;
            font_model = null;
            fonttree.progress.set_fraction(0f);
            Library.progress = (m, p, t) => {
                fonttree.progress.set_fraction((float) p / (float) t);
                ensure_ui_update();
            };
            Main.instance.fontconfig.sources.cancel_monitors();
            Library.Install.from_uri_array(arr);
            fonttree.loading = false;
            font_model = Main.instance.font_model;
            queue_reload();
            return;
        }

        private void on_drag_data_received (Gtk.Widget widget,
                                            Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint time)
        {
            switch (info) {
                case DragTargetType.FAMILY:
                    family_drop_handler(widget, x, y);
                    break;
                case DragTargetType.EXTERNAL:
                    install_fonts(selection_data.get_uris());
                    break;
                default:
                    warning("Unsupported drag target.");
                    return;
            }
            return;
        }

        private void family_drop_handler (Gtk.Widget widget, int x, int y) {
            if (!(widget.name == "FontManagerCollectionTree"))
                return;
            Gtk.TreePath path;
            var tree = widget as Gtk.TreeView;
            tree.get_path_at_pos(x, y, out path, null, null, null);
            if (path == null) {
                return;
            }
            Gtk.TreeIter iter;
            var model = tree.get_model();
            if (!model.get_iter(out iter, path))
                /* Invalid drop, non-existent path */
                return;
            Value val;
            model.get_value(iter, CollectionColumn.OBJECT, out val);
            var group = (Collection) val.get_object();
            if (group != null) {
                group.families.add_all(fontlist.get_selected_families());
                group.set_active_from_fonts(Main.instance.fontconfig.reject);
                Main.instance.collections.cache();
                Idle.add(() => {
                    update_unsorted_category();
                    return false;
                });
            }
            return;
        }

    }

}
