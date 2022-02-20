# ClamTk, copyright (C) 2004-2022 Dave M
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
package ClamTk::Network;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use LWP::UserAgent;

use POSIX 'locale_h';
use Locale::gettext;

my $proxy_status_image;    # Image
my $infobar;               # InfoBar

sub show_window {
    my $eb = Gtk3::EventBox->new;

    my $box = Gtk3::VBox->new( FALSE, 5 );
    $eb->add( $box );

    my $grid = Gtk3::Grid->new();
    $box->pack_start( $grid, FALSE, FALSE, 5 );
    $grid->set_column_spacing( 10 );
    $grid->set_column_homogeneous( TRUE );

    my $none_button = Gtk3::RadioButton->new_with_label_from_widget( undef,
        _( 'No proxy' ) );
    $grid->attach( $none_button, 0, 0, 1, 1 );

    my $env_button
        = Gtk3::RadioButton->new_with_label_from_widget( $none_button,
        _( 'Environment settings' ) );
    $grid->attach( $env_button, 0, 1, 1, 1 );

    my $manual_button
        = Gtk3::RadioButton->new_with_label_from_widget( $none_button,
        _( 'Set manually' ) );
    $grid->attach( $manual_button, 0, 2, 1, 1 );

    # Proxy host information
    my $label = Gtk3::Label->new( _( 'IP address or host' ) );
    $grid->attach( $label, 1, 3, 1, 1 );

    my $buffer     = Gtk3::EntryBuffer->new( undef, 0 );
    my $host_entry = Gtk3::Entry->new_with_buffer( $buffer );
    $host_entry->set_max_length( 63 );
    $grid->attach( $host_entry, 2, 3, 1, 1 );
    $buffer->signal_connect(
        'inserted-text' => sub {
            my ( $widget, $pos, $char, $n_chars, $data ) = @_;

            # https://datatracker.ietf.org/doc/rfc1738/
            if ( $char !~ m/[a-z0-9\+\.\-]/i ) {
                $buffer->delete_text( $pos, 1 );
                # $buffer->signal_stop_emission_by_name( 'insert-text' );
                # $host_entry->set_text($char);
            }
        }
    );

    # Proxy port information
    $label = Gtk3::Label->new( _( 'Port' ) );
    $grid->attach( $label, 1, 4, 1, 1 );
    my $port_spin = Gtk3::SpinButton->new_with_range( 1, 65535, 1 );
    $port_spin->set_value( 8080 );
    $grid->attach( $port_spin, 2, 4, 1, 1 );

    # Signals for radiobuttons
    $none_button->signal_connect(
        toggled => sub {
            if ( $none_button->get_active ) {
                $host_entry->set_sensitive( FALSE );
                $port_spin->set_sensitive( FALSE );
            }
        }
    );
    $env_button->signal_connect(
        toggled => sub {
            if ( $env_button->get_active ) {
                $host_entry->set_sensitive( FALSE );
                $port_spin->set_sensitive( FALSE );
            }
        }
    );
    $manual_button->signal_connect(
        toggled => sub {
            if ( $manual_button->get_active ) {
                $host_entry->set_sensitive( TRUE );
                $port_spin->set_sensitive( TRUE );
            }
        }
    );

    my $use_image    = ClamTk::Icons->get_image( 'document-save' );
    my $apply_button = Gtk3::Button->new_from_icon_name( $use_image, 0 );
    $apply_button->set_tooltip_text( _( 'Press Apply to save changes' ) );
    $grid->attach( $apply_button, 0, 6, 1, 1 );

    $use_image          = ClamTk::Icons->get_image( 'list-add' );
    $proxy_status_image = Gtk3::Button->new_from_icon_name( $use_image, 0 );
    $grid->attach( $proxy_status_image, 1, 6, 1, 1 );

    # What does the user have set?
    # 0 = no proxy, 1 = env_proxy and 2 = manual proxy
    my $setting = ClamTk::Prefs->get_preference( 'HTTPProxy' );
    $host_entry->set_sensitive( FALSE );
    $port_spin->set_sensitive( FALSE );

    if ( !$setting ) {
        $none_button->set_active( TRUE );
    } elsif ( $setting == 1 ) {
        $env_button->set_active( TRUE );
    } elsif ( $setting == 2 ) {
        $manual_button->set_active( TRUE );
        $host_entry->set_sensitive( TRUE );
        $port_spin->set_sensitive( TRUE );
    }

    my $path = ClamTk::App->get_path( 'db' );
    $path .= '/local.conf';

    if ( -f $path ) {
        if ( open( my $FH, '<', $path ) ) {
            while ( <$FH> ) {
                chomp;
                my $set;
                if ( /HTTPProxyServer\s+(.*?)$/ ) {
                    $set = $1;
                    if ( $set !~ m#://# ) {
                        $set = 'http://' . $set;
                    }
                    $host_entry->set_text( $set );
                    if (  !$setting
                        || $setting == 1 )
                    {
                        $host_entry->set_sensitive( FALSE );
                    }
                }
                if ( /HTTPProxyPort\s+(.*?)$/ ) {
                    $port_spin->set_value( $1 );
                    if (  !$setting
                        || $setting == 1 )
                    {
                        $port_spin->set_sensitive( FALSE );
                    }
                }
            }
            close( $FH );
        }
    }

    $infobar = Gtk3::InfoBar->new;
    $box->pack_start( $infobar, FALSE, FALSE, 5 );
    my $info_label = Gtk3::Label->new( ' ' );
    $info_label->set_alignment( 0.0, 0.5 );
    $infobar->get_content_area->add( $info_label );
    $infobar->set_message_type( 'other' );

    $apply_button->signal_connect(
        clicked => sub {
            my $choice;
            if ( $env_button->get_active ) {
                $choice = 1;
            } elsif ( $manual_button->get_active ) {
                $choice = 2;
            } else {
                $choice = 0;
            }
            if (   $choice == 0
                || $choice == 1 )
            {
                if ( ClamTk::Prefs->set_preference( 'HTTPProxy', $choice ) ) {
                    proxy_non_block_status( 'yes' );
                } else {
                    proxy_non_block_status( 'no' );
                }
            }

            if ( $manual_button->get_active ) {
                if ( length( $host_entry->get_text ) < 1 ) {
                    $none_button->set_active( TRUE );
                    return;
                }
                my $ip = $host_entry->get_text;
                if ( $ip !~ m#://# ) {
                    $ip = 'http://' . $ip;
                }
                my $port = $port_spin->get_value_as_int;
                if ( $port =~ /^(\d+)$/ ) {
                    $port = $1;
                } else {
                    $port = 8080;
                }

                # Hate to pull in LWP::UserAgent just for this,
                # but we need to sanity check it before they get
                # to using it in the first place
                eval {
                    my $ua = LWP::UserAgent->new;
                    $ua->proxy( http => "$ip:$port" );
                };
                if ( $@ ) {
                    proxy_non_block_status( 'no' );
                    return;
                }
                if (   ClamTk::Prefs->set_preference( 'HTTPProxy', $choice )
                    && ClamTk::Prefs->set_proxy( $ip, $port ) )
                {
                    proxy_non_block_status( 'yes' );
                    $host_entry->set_text( $ip );
                    $port_spin->set_value( $port );
                } else {
                    proxy_non_block_status( 'no' );
                    $host_entry->set_text( $ip );
                    $port_spin->set_value( $port );
                }
            }
        }
    );

    $eb->show_all;
    $proxy_status_image->hide;
    return $eb;
}

sub set_infobar_text {
    my $text = shift;

    Gtk3::main_iteration while Gtk3::events_pending;
    for my $child ( $infobar->get_content_area->get_children ) {
        if ( $child->isa( 'Gtk3::Label' ) ) {
            $child->set_text( $text );
        }
    }
    Gtk3::main_iteration while Gtk3::events_pending;
}

sub proxy_non_block_status {
    # This is a non-blocking way to show success or failure
    # in the proxy configuration dialog.
    # I think muppet came up with this.
    my $status  = shift;
    my $message = '';
    if ( $status eq 'yes' ) {
        my $use_image = ClamTk::Icons->get_image( 'emblem-ok' );
        my $btn       = Gtk3::Button->new_from_icon_name( $use_image, 0 );
        $btn->set_relief( 'none' );
        $proxy_status_image->set_image( $btn );
        $message = _( 'Settings saved' );
        $infobar->set_message_type( 'other' );
    } else {
        my $use_image = ClamTk::Icons->get_image( 'emblem-important' );
        my $btn       = Gtk3::Button->new_from_icon_name( $use_image, 0 );
        $btn->set_relief( 'none' );
        $proxy_status_image->set_image( $btn );
        $message = _( 'Error' );
        $infobar->set_message_type( 'other' );
    }
    set_infobar_text( $message );
    $proxy_status_image->show;
    my $loop = Glib::MainLoop->new;
    Glib::Timeout->add(
        1200,
        sub {
            $loop->quit;
            FALSE;
        }
    );
    $loop->run;
    set_infobar_text( '' );
    $proxy_status_image->hide;
    $infobar->set_message_type( 'other' );
    return;
}

1;
