# ClamTk, copyright (C) 2004-2016 Dave M
#
# This file is part of ClamTk (https://dave-theunsub.github.io/clamtk).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".
package ClamTk::Shortcuts;

use Glib 'FALSE';

# use strict;
# use warnings;
$| = 1;

use POSIX 'locale_h';
use Locale::gettext;

sub get_pseudo_keys {
    #<<<
    my @entries = (
        [
           'About', undef,
           _('About'), '<control>A',
            undef, sub { ClamTk::GUI::about() },
            FALSE
        ],
        [
            'Exit', undef,
            _('Exit'), '<control>X',
            undef, sub { Gtk2->main_quit },
            FALSE
        ],
        [
            'Select a file', undef,
            _('Select a file'), '<control>F',
            undef, sub { ClamTk::GUI::select_file() },
            FALSE
        ],
        [
            'Select a directory', undef,
            _('Select a directory'), '<control>D',
            undef, sub { ClamTk::GUI::select_directory() },
            FALSE
        ],
    );
    #>>>

    return @entries;
}

sub get_ui_info {
    return "<ui>
                <menubar name='MenuBar'>
                 <menuitem action='About'/>
                 <menuitem action='Exit'/>
                 <menuitem action='Select a file'/>
                 <menuitem action='Select a directory'/>
                </menubar>
                </ui>";
}

1;
