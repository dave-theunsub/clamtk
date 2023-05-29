# ClamTk, copyright (C) 2004-2023 Dave M
#
# This file is part of ClamTk
# (https://gitlab.com/dave_m/clamtk/).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".
package ClamTk::Assistant;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use File::Copy 'copy';
use Locale::gettext;

my $pref;

sub show_window {
    my $box = Gtk3::Box->new( 'vertical', 0 );
    $box->set_homogeneous( FALSE );
    $box->set_border_width( 12 );

    # Get current update preference
    $pref = ClamTk::Prefs->get_preference( 'Update' );
    # Just in case, set it to 'shared' if nothing else:
    $pref ||= 'shared';

    #<<<
    my $label = Gtk3::Label->new(
          _(
           'Please choose how you will update your antivirus signatures'
          )
    );
    #>>>
    my $flabel = Gtk3::Label->new( '' );
    $flabel->set_markup( "<b>" . $label->get_label . "</b>" );
    $flabel->set_alignment( 0.0, 0.5 );
    $box->pack_start( $flabel, FALSE, FALSE, 10 );

    my $bbox = Gtk3::ButtonBox->new( 'vertical' );
    $bbox->set_layout( 'start' );
    $box->add( $bbox );

    #<<<
    my $auto_button = Gtk3::RadioButton->new_with_label_from_widget(
            undef,
            _('My computer automatically receives updates')
    );
    $auto_button->signal_connect(
        toggled => sub {
            if( $auto_button->get_active ) {
                $pref = 'shared';
            } else {
                $pref = 'single';
            }
        }
    );

    my $man_button = Gtk3::RadioButton->new_from_widget( $auto_button );
    $man_button->set_label(
            _('I would like to update signatures myself')
    );
    $man_button->signal_connect(
        toggled => sub {
            if( $man_button->get_active ) {
                $pref = 'single';
            } else {
                $pref = 'shared';
            }
         }
    );
    #>>>
    $bbox->pack_start( $auto_button, FALSE, FALSE, 0 );
    $bbox->pack_start( $man_button,  FALSE, FALSE, 0 );

    if ( $pref eq 'shared' ) {
        $auto_button->set_active( TRUE );
    } elsif ( $pref eq 'single' ) {
        $man_button->set_active( TRUE );
    }

    my $infobar = Gtk3::InfoBar->new;
    $infobar->set_message_type( 'other' );
    $box->pack_start( $infobar, FALSE, FALSE, 10 );

    $label = Gtk3::Label->new( _( 'Press Apply to save changes' ) );
    $infobar->get_content_area->add( $label );
    $infobar->add_button( 'gtk-apply', GTK_RESPONSE_APPLY );
    $infobar->signal_connect(
        response => sub {
            my ( $bar, $sig, undef ) = @_;
            # Gtk3::main_iteration while Gtk3::events_pending;
            $label->set_text( _( 'Please wait...' ) );
            if ( save() ) {
                set_infobar_text( TRUE, $bar );
            } else {
                set_infobar_text( FALSE, $bar );
            }
        }
    );

    $box->show_all();
    return $box;
}

sub set_infobar_text {
    my ( $success, $bar ) = @_;

    # The text we display
    my $label;
    # The message type of infobar we display
    my $type;

    if ( $success ) {
        $label = _( 'Your changes were saved.' );
        $type  = 'info';
    } else {
        $label = _( 'Error updating: try again later' );
        $type  = 'error';
    }

    for my $child ( $bar->get_content_area->get_children ) {
        if ( $child->isa( 'Gtk3::Label' ) ) {
            $child->set_text( $label );
        }
    }
    $bar->set_message_type( $type );

    my $loop = Glib::MainLoop->new;
    Glib::Timeout->add(
        2000,
        sub {
            $loop->quit;
            FALSE;
        }
    );
    $loop->run;

    $bar->set_message_type( 'other' );
    #for my $child ( $bar->get_content_area->get_children ) {
    for my $child ( $bar->get_children ) {
        if ( $child->isa( 'Gtk3::Label' ) ) {
            $child->set_text( _( 'Press Apply to save changes' ) );
        }
    }
}

sub save {
    my ( $ret ) = ClamTk::Prefs->set_preference( 'Update', $pref );

    if ( $ret == 1 ) {
        # It worked, so see if there are system signatures around
        # we can copy to save bandwidth and time
        my $paths = ClamTk::App->get_path( 'db' );

        if ( $pref eq 'single' ) {
            # $d(aily) and $m(ain) signatures
            my ( $d, $m ) = ( 0 ) x 2;
            # Gtk3::main_iteration while Gtk3::events_pending;
            for my $dir_list (
                '/var/clamav',             '/var/lib/clamav',
                '/opt/local/share/clamav', '/usr/share/clamav',
                '/usr/local/share/clamav', '/var/db/clamav',
                )
            {
                if ( -e "$dir_list/daily.cld" ) {
                    copy( "$dir_list/daily.cld", "$paths/daily.cld" );
                    if ( $! ) {
                        warn "issue copying daily.cld: $!\n";
                    }
                    $d = 1;
                } elsif ( -e "$dir_list/daily.cvd" ) {
                    copy( "$dir_list/daily.cvd", "$paths/daily.cvd" );
                    if ( $! ) {
                        warn "issue copying daily.cvd: $!\n";
                    }
                    $d = 1;
                }
                if ( -e "$dir_list/main.cld" ) {
                    copy( "$dir_list/main.cld", "$paths/main.cld" );
                    if ( $! ) {
                        warn "issue copying main.cld: $!\n";
                    }
                    $m = 1;
                } elsif ( -e "$dir_list/main.cvd" ) {
                    copy( "$dir_list/main.cvd", "$paths/main.cvd" );
                    if ( $! ) {
                        warn "issue copying main.cvd: $!\n";
                    }
                    $m = 1;
                }
                if ( -e "$dir_list/bytecode.cld" ) {
                    copy( "$dir_list/bytecode.cld", "$paths/bytecode.cld" );
                    if ( $! ) {
                        warn "issue copying bytecode: $!\n";
                    }
                }
                last if ( $d && $m );
            }
        }
    }
    # Update statusbar
    ClamTk::GUI->startup();

    return 1;
}

1;
