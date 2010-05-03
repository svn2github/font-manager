"""
Font Manager, a font management application for the GNOME desktop
"""
# Font Manager, a font management application for the GNOME desktop
#
# Copyright (C) 2009, 2010 Jerry Casiano
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to:
#
#    Free Software Foundation, Inc.
#    51 Franklin Street, Fifth Floor
#    Boston, MA 02110-1301, USA.

import os
import glib
import gtk
import gobject
import logging
import UserDict
import webbrowser
import subprocess

import core

from constants import PACKAGE_DATA_DIR, PACKAGE_DIR
from ui.export import Export
from ui.library import InstallFonts, RemoveFonts
from ui.treeviews import Treeviews
from ui.previews import Previews
from utils.common import disable_blacklist, open_folder, delete_cache, \
                            delete_database, reset_fontconfig_cache
from utils.xmlutils import save_collections


class Main(object):
    """
    Where everything starts.
    """
    def __init__(self):
        # FIXME disable blacklist is called by FontManager
        # But for whatever reason, we need to disable our blacklist right at
        # the start anytime we launch the gui... from cli it works as intended.
        disable_blacklist()
        self.objects = ObjectContainer()
        self.menus = PopupMenu()
        self.main_window = self.objects['MainWindow']
        self.preferences = self.objects['Preferences']
        # Showtime
        self.main_window.show()
        if self.preferences.hidden:
            self.main_window.iconify()
        # This is called just to force an update
        while gtk.events_pending():
            gtk.main_iteration()
        # Keep a handle to this connection, so we can change it if requested
        self.quit_id = self.main_window.connect('delete-event', self.quit)
        # Load
        self.objects.load_widgets()
        self.objects.load_core()
        # Notification
        self.objects.notify_send(_('Finished loading %s families') % \
                                self.objects['FontManager'].total_families)
        # Main UI elements
        self.objects.load_ui_elements()
        self.previews = self.objects['Previews']
        self.treeviews = self.objects['Treeviews']
        self.objects.connect_callbacks()
        self._connect_callbacks()
        # Tray icon
        self.tray_icon = None
        if self.preferences.minimize:
            self._use_tray_icon(None)
        # Install/Remove/Export functions
        self.export = None
        self.installer = None
        self.remover = None
        # What the hell, let's put Main into the container... :-D
        self.objects['Main'] = self

    def _connect_callbacks(self):
        # Menu callbacks
        self.menus['ManageFolder'].connect('activate', self._on_open_folder)
        self.menus['ManageInstall'].connect('activate', self._on_install_fonts)
        self.menus['ManageRemove'].connect('activate', self._on_remove_fonts)
        self.menus['TrayInstall'].connect('activate', self._on_install_fonts)
        self.menus['TrayRemove'].connect('activate', self._on_remove_fonts)
        self.menus['TrayFontPreferences'].connect('activate', _on_font_settings)
        self.menus['TrayCharacterMap'].connect('activate',
                                                    self.previews.on_char_map)
        self.menus['TrayPreferences'].connect('activate', self.objects.on_prefs)
        self.menus['TrayHelp'].connect('activate', _on_help)
        self.menus['TrayAbout'].connect('activate', _on_about_dialog,
                                            self.objects['AboutDialog'])
        self.menus['TrayQuit'].connect('activate', self.quit)
        # Miscellaneous
        self.objects['Refresh'].connect('clicked', self.reload, True)
        self.objects['Manage'].connect('button-press-event',
                                        self.menus.show_manage_menu)
        self.objects['Export'].connect('clicked', self._on_export)
        self.preferences.connect('update-tray-icon', self._use_tray_icon)
        return

    def _on_export(self, unused_widget):
        if not self.export:
            self.export = Export(self.objects)
        self.export.run()
        return

    def _on_install_fonts(self, unused_widget):
        if not self.installer:
            self.installer = InstallFonts(self.objects)
        self.installer.run()
        return

    def _on_open_folder(self, unused_widget):
        open_folder(self.objects['Preferences'].folder, self.objects)
        return

    def _on_remove_fonts(self, unused_widget):
        if not self.remover:
            self.remover = RemoveFonts(self.objects)
        self.remover.run()
        return

    def _on_tray_icon_clicked(self, unused_widget):
        """
        Show or hide application when tray icon is clicked
        """
        if not self.main_window.get_property('visible'):
            self.main_window.set_skip_taskbar_hint(False)
            self.main_window.present()
        else:
            self.main_window.set_skip_taskbar_hint(True)
            self.main_window.hide()
        return

    def reload(self, unused_widget, delete_cache = False):
        save_collections(self.objects)
        self.objects.notify_send(_('Font Manager will restart in a moment'))
        if delete_cache:
            delete_cache()
            delete_database()
            reset_fontconfig_cache()
        try:
            os.execvp('font-manager', ('--execvp_needs_to_stop_crying="True"',))
        except OSError, error:
            logging.error(error)
        return

    def _use_tray_icon(self, unused_cls_instance, minimize = True):
        if not self.tray_icon:
            self.tray_icon = \
            gtk.status_icon_new_from_icon_name('preferences-desktop-font')
            self.tray_icon.set_tooltip(_('Font Manager'))
            self.tray_icon.connect('activate', self._on_tray_icon_clicked)
            self.tray_icon.connect('popup-menu', self.menus.show_tray_menu)
        self.tray_icon.set_visible(minimize)
        self.main_window.disconnect(self.quit_id)
        if minimize:
            self.quit_id = \
            self.main_window.connect('delete-event', _delete_handler)
        else:
            self.quit_id = \
            self.main_window.connect('delete-event', self.quit)
        return

    def quit(self, unused_widget = None, possible_event = None):
        save_collections(self.objects)
        gtk.main_quit()


class ObjectContainer(UserDict.UserDict):
    """
    Provide a convenient way to share objects between classes.
    """
    _widgets = (
        'TopBox', 'MainBox', 'StatusBox', 'HorizontalPane',
        'CategoryTree', 'CollectionTree', 'NewCollection', 'RemoveCollection',
        'EnableCollection', 'DisableCollection', 'VerticalPane', 'FamilyScroll',
        'FamilyTree', 'FamilySearchBox', 'EnableFamily', 'DisableFamily',
        'RemoveFamily', 'ColorSelect', 'FontInformation', 'CharacterMap',
        'CompareButtonsBox', 'AddToCompare', 'RemoveFromCompare',
        'ClearComparison', 'PreviewScroll', 'CompareScroll', 'Export',
        'ClearComparison', 'FontSizeSpinButton', 'FontPreview', 'CompareTree',
        'FontSizeSlider', 'CustomTextEntry', 'SearchFonts', 'CompareFonts',
        'CustomText', 'About', 'Help', 'AppPreferences', 'FontSettings',
        'Manage', 'FamilyTotal', 'ProgressBar', 'LoadingLabel', 'ProgressLabel',
        'Throbber', 'Refresh', 'SizeAdjustment', 'FontOptionsBox',
        'MadFontsWarning', 'ColorSelector', 'CloseColorSelector',
        'ForegroundColor', 'BackgroundColor', 'AboutDialog', 'AppOptionsBox',
        'FontInstallDialog', 'DuplicatesWarning', 'DuplicatesView',
        'FileMissingDialog', 'FileMissingView', 'FontRemovalDialog',
        'RemoveFontsTree', 'RemoveSearchEntry', 'RemoveFontsButton',
        'ExportDialog', 'ExportAsArchive', 'ExportAsPDF', 'ExportTo',
        'ExportFileChooserBox', 'ExportFileChooser', 'ExportPermissionsWarning',
        'ExportArchiveOptionsBox', 'IncludeSampler'
        )
    def __init__(self):
        UserDict.UserDict.__init__(self)
        self.data = {}
        self.prefs_dialog = None
        self.builder = gtk.Builder()
        self.builder.set_translation_domain('font-manager')
        self.builder.add_from_file(os.path.join(PACKAGE_DATA_DIR, 'font-manager.ui'))
        self.data['MainWindow'] = self.builder.get_object('MainWindow')
        self.data['Preferences'] = core.get_preferences()
        self.data['Preferences'].connect('update-font-dirs', self.reload)
        self.data['AvailableApps'] = core.get_applist()
        # Find and set up icon for use throughout app windows
        try:
            icon_theme = gtk.icon_theme_get_default()
            self.icon = icon_theme.load_icon("preferences-desktop-font", 48, 0)
            gtk.window_set_default_icon_list(self.icon)
        except gobject.GError, exc:
            logging.warn("Could not find preferences-desktop-font icon", exc)
            self.icon = None
        # Show notifications, if available
        self.message = None
        try:
            import pynotify
            if pynotify.init('font-manager'):
                self.message = pynotify.Notification
        except ImportError:
            pass

    def connect_callbacks(self):
        """
        Connect callbacks to local functions.
        """
        self.data['About'].connect('clicked', _on_about_dialog,
                                            self.data['AboutDialog'])
        self.data['Help'].connect('clicked', _on_help)
        self.data['FontSettings'].connect('clicked', _on_font_settings)
        self.data['AppPreferences'].connect('clicked', self.on_prefs)

    def load_core(self, progress_callback = None):
        """
        Load FontManager.
        """
        self.set_sensitive(False)
        core.PROGRESS_CALLBACK = self.progress_callback
        self.data['FontManager'] = core.get_manager()
        self.set_sensitive(True)
        return

    def load_ui_elements(self):
        self.data['Previews'] = Previews(self)
        self.data['Treeviews'] = Treeviews(self)
        return

    def load_widgets(self):
        """
        Load widgets from .ui file.

        Setup any widgets that are not defined in the .ui file.
        """
        for widget in self._widgets:
            self.data[widget] = self.builder.get_object(widget)
        # Undefined widgets
        self.data['StyleCombo'] =  gtk.combo_box_new_text()
        self.data['StyleCombo'].set_focus_on_click(False)
        self.data['FontOptionsBox'].pack_end(self.data['StyleCombo'],
                                                            False, False)
        self.data['StyleCombo'].show()
        return

    def notify_send(self, message):
        """
        Display a notification bubble.
        """
        if self.message is None:
            return
        notification = self.message(_('Font Manager'), _('%s') % message)
        if self.icon:
            notification.set_icon_from_pixbuf(self.icon)
        notification.show()
        while gtk.events_pending():
            gtk.main_iteration()
        return

    def on_prefs(self, unused_widget):
        """
        Display preferences dialog.
        """
        from ui.preferences import PreferencesDialog
        if self.prefs_dialog is None:
            self.prefs_dialog = PreferencesDialog(self)
            self.prefs_dialog.run(self)
        else:
            self.prefs_dialog.run(self)
        return

    def progress_callback(self, family, total, processed):
        """
        Set progressbar text and percentage.
        """
        if family is not None:
            self.data['ProgressBar'].set_text(family)
        if processed > 0 and processed <= total:
            self.data['ProgressBar'].set_fraction(float(processed)/float(total))
        while gtk.events_pending():
            gtk.main_iteration()
        return

    def reload(self, *args):
        self.set_sensitive(False)
        self.data['Main'].reload(None)
        self.set_sensitive(True)
        return

    def set_sensitive(self, state = True):
        self.data['MainBox'].set_sensitive(state)
        self.data['Refresh'].set_sensitive(state)
        for widget in self.data['AppOptionsBox'].get_children():
            widget.set_sensitive(state)
        if state:
            self.data['ProgressBar'].hide()
            self.data['FamilyTotal'].set_text\
            (_('Families : %s') % str(self.data['FontManager'].total_families))
        else:
            self.data['FamilyTotal'].set_text(_(''))
            self.data['ProgressBar'].set_text('')
            self.data['ProgressBar'].show()
        while gtk.events_pending():
            gtk.main_iteration()
        return


class PopupMenu(UserDict.UserDict):
    _widgets = (
        'TrayMenu', 'TrayInstall', 'TrayRemove', 'TrayFontPreferences',
        'TrayCharacterMap', 'TrayPreferences', 'TrayHelp', 'TrayAbout',
        'TrayQuit', 'ManageMenu', 'ManageInstall', 'ManageRemove',
        'ManageFolder'
        )
    def __init__(self, objects = None):
        UserDict.UserDict.__init__(self)
        self.data = {}
        if objects is None:
            self.builder = gtk.Builder()
        else:
            self.builder = objects.builder
        self.builder.add_from_file(os.path.join(PACKAGE_DATA_DIR, 'menus.ui'))
        for widget in self._widgets:
            self.data[widget] = self.builder.get_object(widget)
        self.tray_menu = self.data['TrayMenu']
        self.manage_menu = self.data['ManageMenu']

    def show_manage_menu(self, unused_widget, event):
        """
        Display "manage fonts' menu.
        """
        if event.button != 1:
            return
        self.manage_menu.popup(None, None, None, event.button, event.time)
        return

    def show_tray_menu(self, unused_widget, button, event_time):
        """
        Display tray menu.
        """
        self.tray_menu.popup(None, None, None, button, event_time)
        return


def _delete_handler(window, unused_event):
    """
    PyGTK destroys the window by default, returning True from this function
    tells PyGTK that no further action is needed.

    Returning False would tell PyGTK to perform these actions then go ahead
    and destroy the window.
    """
    window.set_skip_taskbar_hint(True)
    window.hide()
    return True

def _on_about_dialog(unused_widget, dialog):
    """
    Launch about dialog.
    """
    dialog.run()
    dialog.hide()

def _on_font_settings(unused_widget):
    """
    Launch gnome-appearance-properties with the fonts tab active.
    """
    try:
        logging.info("Launching font preferences dialog")
        subprocess.Popen(['gnome-appearance-properties', '--show-page=fonts'])
    except OSError, error:
        logging.error("Error: %s" % error)
        pass
    return

def _on_help(unused_widget):
    """
    Open help pages in browser.
    """
    lang = 'en_US'
    help_files = '%s/doc/%s.html' % (PACKAGE_DIR, lang)
    if webbrowser.open(help_files):
        logging.info("Launching Help browser")
    else:
        logging.warn("Could not find any suitable browser")
    return

