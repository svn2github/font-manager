"""
This module is just a convenient place to group re-usable functions.
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
import re
import gtk
import time
import logging
import shutil
import subprocess

from os.path import basename, exists, join
from constants import AUTOSTART_DIR, PACKAGE_DIR, USER_FONT_DIR, HOME, \
README, USER_FONT_CONFIG_SELECT, USER_FONT_CONFIG_DESELECT, USER_LIBRARY_DIR, \
TMP_DIR, CACHE_FILE, DATABASE_FILE


AUTOSTART = \
"""[Desktop Entry]
Version=1.0
Encoding=UTF-8
Name=Font Manager
Name[en_US]=Font Manager
Comment=Preview, compare and manage fonts
Type=Application
Exec=font-manager
Terminal=false
StartupNotify=false
Icon=preferences-desktop-font
Categories=Graphics;Viewer;GNOME;GTK;Publishing;
"""

FONT_EXTS = ('.ttf', '.ttc', '.otf', '.TTF', '.TTC', '.OTF')
ARCH_EXTS = ('.zip', '.tar', '.tar.gz', '.tar.bz2',
                '.ZIP', '.TAR', '.TAR.GZ', '.TAR.BZ2' )

class AvailableApps(list):
    """
    This class is a list of available applications.
    """
    _defaults = ('dolphin', 'file-roller', 'gnome-appearance-properties',
                'gucharmap', 'konqueror', 'nautilus', 'pcmanfm', 'thunar',
                'xdg-open')
    _dirs = ['/usr/bin', '/usr/local/bin', '/bin', '/sw/bin']
    def __init__(self):
        list.__init__(self)
        self.update()

    def have(self, app):
        """
        Return True if app is installed.
        """
        if app in self:
            return True
        else:
            for appdir in self._dirs:
                if exists(join(appdir, app)):
                    self.append(app)
                    return True
        return False

    def update(self, *apps):
        """
        Update self to include apps.

        apps -- an application, list or tuple of applications.

        """
        del self[:]
        for app in self._defaults:
            if self.have(app) and app not in self:
                self.append(app)
        if apps:
            if isinstance(apps[0], str):
                if self.have(apps[0]) and apps[0] not in self:
                    self.append(apps[0])
            elif isinstance(apps[0], tuple) or isinstance(apps[0], list):
                for app in apps[0]:
                    if self.have(app) and app not in self:
                        self.append(app)
        return

    def add_bin_dir(self, dirpath):
        """
        Add a directory to search for installed programs.
        """
        if isdir(dirpath):
            self._dirs.append(dirpath)
            self.update()
            return
        else:
            raise TypeError('%s is not a valid directory path' % dirpath)


def autostart(startme=True):
    """
    Install or remove a .desktop file when requested
    """
    autostart_file = join(AUTOSTART_DIR, 'font-manager.desktop')
    if startme:
        if not exists(AUTOSTART_DIR):
            os.makedirs(AUTOSTART_DIR, 0755)
        with open(autostart_file, 'w') as start:
            start.write(AUTOSTART)
    else:
        if exists(autostart_file):
            os.unlink(autostart_file)
    return

def _convert(char):
    """
    Ensure certain characters don't affect sort order.

    So that a doesn't end up under a-a for example.

    """
    if char.isdigit():
        return int(char)
    else:
        char = char.replace('-', '')
        char = char.replace('_', '')
        return char.lower()

def create_archive_from_folder(arch_name, arch_type, destination,
                                                folder, delete = True):
    """
    Create an archive named arch_name of type arch_type in destination from
    the supplied folder.

    If delete is True (default), folder will be deleted afterwards
    """
    os.chdir(destination)
    roller = subprocess.Popen('file-roller' + ' -a "%s.%s" "%s"' % \
                                (arch_name, arch_type, folder), shell=True)
    # Wait for file-roller to finish
    while roller.poll() is None:
        continue
    if delete:
        shutil.rmtree(folder, ignore_errors = True)
    os.chdir(HOME)
    return


def delete_cache():
    """
    Remove stale cache file
    """
    if exists(CACHE_FILE):
        os.unlink(CACHE_FILE)
    return

def delete_database():
    """
    Remove stale cache file
    """
    if exists(DATABASE_FILE):
        os.unlink(DATABASE_FILE)
    return

def disable_blacklist():
    """
    Disable user blacklist.
    """
    if exists(USER_FONT_CONFIG_SELECT):
        os.rename(USER_FONT_CONFIG_SELECT, USER_FONT_CONFIG_DESELECT)
    time.sleep(0.5)
    return

def do_library_cleanup(root_dir = USER_LIBRARY_DIR):
    """
    Removes empty leftover directories and ensures correct permissions.
    """
    # Two passes here to get rid of empty top level directories
    passes = 0
    while passes <= 1:
        for root, dirs, files in os.walk(root_dir):
            if not len(dirs) > 0 and root != root_dir:
                keep = False
                for filename in files:
                    if filename.endswith(FONT_EXTS):
                        keep = True
                        break
                if not keep:
                    shutil.rmtree(root)
        passes += 1
    # Make sure we don't have any executables among our 'managed' files
    # and make sure others have read-only access, apparently this can be
    # an issue for some programs
    for root, dirs, files in os.walk(root_dir):
        for dir in dirs:
            os.chmod(join(root, dir), 0744)
        for filename in files:
            os.chmod(join(root, filename), 0644)
    return

def enable_blacklist():
    """
    Enable user blacklist.
    """
    if exists(USER_FONT_CONFIG_DESELECT):
        os.rename(USER_FONT_CONFIG_DESELECT, USER_FONT_CONFIG_SELECT)
    time.sleep(0.5)
    return

def finish_font_install():
    """
    Organize fonts alphabetically and move them to library.
    """
    for root, dirs, files in os.walk(TMP_DIR):
        for directory in dirs:
            fullpath = join(root, directory)
            new = directory[0]
            new = new.upper()
            newpath = join(USER_LIBRARY_DIR, new)
            if not exists(newpath):
                os.mkdir(newpath)
            newname = join(newpath, directory)
            if exists(newname):
                shutil.rmtree(newname, ignore_errors=True)
            shutil.move(fullpath, newname)
    for root, dirs, files in os.walk(TMP_DIR):
        for name in files:
            if name.endswith(FONT_EXTS):
                oldpath = join(root, name)
                truename = name.split('.')[0]
                truename = name.strip()
                new = truename[0]
                new = new.upper()
                newpath = join(USER_LIBRARY_DIR, new)
                if not exists(newpath):
                    os.mkdir(newpath)
                newname = join(newpath, name)
                if exists(newname):
                    shutil.rmtree(newname, ignore_errors=True)
                shutil.move(oldpath, newname)
    do_library_cleanup()
    shutil.rmtree(TMP_DIR, ignore_errors=True)
    return

def install_font_archive(filepath):
    dir_name = strip_archive_ext(basename(filepath))
    arch_dir = join(TMP_DIR, dir_name)
    if exists(arch_dir):
        i = 0
        while exists(arch_dir):
            arch_dir = arch_dir + str(i)
            i += 1
    os.mkdir(arch_dir)
    subprocess.call(['file-roller', '-e', arch_dir, filepath])
    # Todo: Need to check whether archive actually contained any fonts
    # if user_is_stupid:
    #     self.notify()
    # ;-p
    return

def install_readme():
    """
    Install a readme into ~/.fonts if it didn't previously exist

    Really just intended for users new to linux ;-)
    """
    with open(join(USER_FONT_DIR, _('Read Me.txt')), 'w') as readme:
        readme.write(README)
    return

def match(model, treeiter, data):
    """
    Tries to match a value with those in the given treemodel
    """
    column, key = data
    value = model.get_value(treeiter, column)
    return value == key

def mkfontdirs(root_dir = USER_LIBRARY_DIR):
    """
    Recursively generate fonts.scale and fonts.dir for folders containing
    font files.
    Not sure these files are even necessary but it doesn't hurt anything.
    """
    for root, dirs, files in os.walk(root_dir):
        if not len(dirs) > 0 and root != root_dir:
            if len(files) > 0:
                for filename in files:
                    if filename.endswith(FONT_EXTS):
                        try:
                            subprocess.call(['mkfontscale', root])
                            subprocess.call(['mkfontdir', root])
                        except:
                            pass
                        break
    return

def natural_sort(iter):
    """
    Sort the given iterable in the way that humans expect.
    """
    alphanum = lambda key: [ _convert(c) for c in re.split('([0-9]+)', key) ]
    return sorted(iter, key=alphanum)

def natural_sort_pathlist(iter):
    """
    Sort the given list of filepaths in the way that humans expect.
    """
    alphanum = lambda key: [ _convert(c) for c in re.split('([0-9]+)', basename(key)) ]
    return sorted(iter, key=alphanum)

def natural_size(size):
    size = float(size)
    for unit in ('bytes','kB','MB','GB','TB'):
        if size < 1000.0:
            return "%3.1f %s" % (size, unit)
        size /= 1000.0

def open_folder(folder, objects = None):
    """
    Open given folder in file browser.
    """
    if objects:
        applist = objects['AvailableApps']
    else:
        applist = AvailableApps()
    if 'xdg-open' in applist:
        try:
            logging.info('Opening font folder')
            subprocess.Popen(['xdg-open', folder])
            return
        except OSError, error:
            logging.error('xdg-open failed : %s' % error)
            pass
    else:
        logging.info('xdg-open is not available')
    logging.info('Looking for common file browsers')
    # Fallback to looking for specific file browsers
    file_browser = _find_file_browser()
    _launch_file_browser(file_browser, folder)
    return

def _find_file_browser():
    """
    Look for common file browsers.
    """
    file_browser = None
    file_browsers = 'nautilus', 'thunar', 'dolphin', 'konqueror', 'pcmanfm'
    for browser in file_browsers:
        if browser in applist:
            logging.info("Found %s File Browser" % browser.capitalize())
            file_browser = browser
            break
    if not file_browser:
        logging.info("Could not find a supported File Browser")
    return file_browser

def _launch_file_browser(file_browser, folder):
    """
    Launches file browser, displays a dialog if none was found
    """
    if file_browser:
        try:
            logging.info("Launching %s" % file_browser)
            subprocess.Popen([file_browser, folder])
            return
        except OSError, error:
            logging.error("Error: %s" % error)
    else:
        dialog = gtk.MessageDialog(_("Please install a supported file browser"),
        gtk.DIALOG_DESTROY_WITH_PARENT, gtk.MESSAGE_ERROR,
        gtk.BUTTONS_CLOSE,
_("""Supported file browsers include :

- Nautilus
- Thunar
- Dolphin
- Konqueror
- PCManFM

If a supported file browser is installed,
please file a bug against Font Manager"""))
        dialog.run()
        dialog.destroy()
        return

def reset_fontconfig_cache():
    """
    Clear all fontconfig cache files in users home directory.
    """
    cache = join(HOME, '.fontconfig')
    if exists(cache):
        for path in os.listdir(cache):
            if path.endswith('cache-2'):
                os.unlink(join(cache, path))
    return

def search(model, treeiter, func, data):
    """
    Used in combination with match to find a particular value in a
    gtk.ListStore or gtk.TreeStore.

    Usage:
    search(liststore, liststore.iter_children(None), match, ('index', 'foo'))
    """
    while treeiter:
        if func(model, treeiter, data):
            return treeiter
        result = search(model, model.iter_children(treeiter), func, data)
        if result:
            return result
        treeiter = model.iter_next(treeiter)
    return None

def strip_archive_ext(filename):
    for ext in ARCH_EXTS:
        filename = filename.replace(ext, '')
    return filename

