#!/usr/bin/env python
#
# ClamTk, copyright (C) 2004-2015 Dave M
#
# This file is part of ClamTk (http://code.google.com/p/clamtk/).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".

import os
import urllib
import re

import locale
locale.setlocale(locale.LC_ALL, '')

import gettext
_ = lambda x: gettext.ldgettext("clamtk", x)

from gi.repository import Nautilus, GObject

class OpenTerminalExtension(GObject.GObject, Nautilus.MenuProvider):
       
    def _open_scanner(self, file):
        filename = urllib.unquote(file.get_uri()[7:])
        filename = re.escape(filename)

        #os.chdir(filename)
        os.system('clamtk %s &' % filename)
        
    def menu_activate_cb(self, menu, file):
        self._open_scanner(file)
        
    def menu_background_activate_cb(self, menu, file): 
        self._open_scanner(file)
       
    def get_file_items(self, window, files):
        if len(files) != 1:
            return
        
        file = files[0]
        #if not file.is_directory() or file.get_uri_scheme() != 'file':
        #    return
        
        item = Nautilus.MenuItem(name='NautilusPython::openscanner',
                                 label=_('Scan for threats...') ,
                                 tip=_('Scan %s for threats...') % file.get_name(),
                                 icon='clamtk')
        item.connect('activate', self.menu_activate_cb, file)
        return item,

    def get_background_items(self, window, file):
        item = Nautilus.MenuItem(name='NautilusPython::openscanner_directory',
                                 label=_('Scan directory for threats...'),
                                 tip=_('Scan this directory for threats...'),
                                 icon='clamtk')
        item.connect('activate', self.menu_background_activate_cb, file)
        return item,
