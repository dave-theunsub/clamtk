# ClamTk, copyright (C) 2004-2018 Dave M
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
package ClamTk::Settings;

# use strict;
# use warnings;
$| = 1;

use File::Basename 'basename';

use Glib 'TRUE', 'FALSE';

use POSIX 'locale_h';
use Locale::gettext;

sub show_window {
    my $top_box = Gtk2::EventBox->new;

    # my $white = Gtk2::Gdk::Color->new( 0xFFFF, 0xFFFF, 0xFFFF );
    # $top_box->modify_bg( 'normal', $white );

    my $box = Gtk2::VBox->new( FALSE, 0 );
    $top_box->add( $box );

    my %prefs = ClamTk::Prefs->get_all_prefs();

    my $grid = Gtk2::Table->new( 6, 1, FALSE );
    $box->pack_start( $grid, FALSE, FALSE, 10 );
    $grid->set_col_spacings( 5 );
    $grid->set_row_spacings( 5 );
    $grid->set_homogeneous( TRUE );

    my $option = Gtk2::CheckButton->new_with_label( _( 'Scan for PUAs' ) );
    $option->can_focus( FALSE );
    $option->set_tooltip_text(
        _( 'Detect packed binaries, password recovery tools, and more' ) );
    $option->set_active( TRUE ) if ( $prefs{ Thorough } );
    $grid->attach_defaults( $option, 0, 1, 0, 1 );
    $option->signal_connect(
        toggled => sub {
            my $btn = shift;
            ClamTk::Prefs->set_preference( 'Thorough', $btn->get_active
                ? 1
                : 0 );
        }
    );

    $option = Gtk2::CheckButton->new_with_label(
        _( 'Scan files beginning with a dot (.*)' ) );
    $option->can_focus( FALSE );
    $option->set_tooltip_text( _( 'Scan files typically hidden from view' ) );
    $option->set_active( TRUE ) if ( $prefs{ ScanHidden } );
    $grid->attach_defaults( $option, 0, 1, 1, 2 );
    $option->signal_connect(
        toggled => sub {
            my $btn = shift;
            ClamTk::Prefs->set_preference( 'ScanHidden', $btn->get_active
                ? 1
                : 0 );
        }
    );

    $option = Gtk2::CheckButton->new_with_label(
        _( 'Scan files larger than 20 MB' ) );
    $option->can_focus( FALSE );
    $option->set_tooltip_text(
        _( 'Scan large files which are typically not examined' ) );
    $option->set_active( TRUE ) if ( $prefs{ SizeLimit } );
    $grid->attach_defaults( $option, 0, 1, 2, 3 );
    $option->signal_connect(
        toggled => sub {
            my $btn = shift;
            ClamTk::Prefs->set_preference( 'SizeLimit', $btn->get_active
                ? 1
                : 0 );
        }
    );

    $option = Gtk2::CheckButton->new_with_label(
        _( 'Scan directories recursively' ) );
    $option->can_focus( FALSE );
    $option->set_tooltip_text(
        _( 'Scan all files and directories within a directory' ) );
    $option->set_active( TRUE ) if ( $prefs{ Recursive } );
    $grid->attach_defaults( $option, 0, 1, 3, 4 );
    $option->signal_connect(
        toggled => sub {
            my $btn = shift;
            ClamTk::Prefs->set_preference( 'Recursive', $btn->get_active
                ? 1
                : 0 );
        }
    );

    $option = Gtk2::CheckButton->new_with_label(
        _( 'Check for updates to this program' ) );
    $option->can_focus( FALSE );
    $option->set_tooltip_text(
        _( 'Check online for application and signature updates' ) );
    $option->set_active( TRUE ) if ( $prefs{ GUICheck } );
    $grid->attach_defaults( $option, 0, 1, 4, 5 );
    $option->signal_connect(
        toggled => sub {
            my $btn = shift;
            ClamTk::Prefs->set_preference( 'GUICheck', $btn->get_active
                ? 1
                : 0 );
        }
    );

    my $infobar = Gtk2::InfoBar->new;
    #$box->pack_start( $infobar, FALSE, FALSE, 10 );
    $infobar->set_message_type( 'other' );
    $infobar->add_button( 'gtk-go-back', -7 );
    $infobar->signal_connect(
        response => sub {
            ClamTk::GUI->swap_button;
            ClamTk::GUI->add_default_view;
        }
    );

    $top_box->show_all;
    return $top_box;
}

1;
