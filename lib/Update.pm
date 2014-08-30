# ClamTk, copyright (C) 2004-2014 Dave M
#
# This file is part of ClamTk (http://code.google.com/p/clamtk/)
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".
package ClamTk::Update;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use LWP::UserAgent;
use Locale::gettext;

# Keeping these global for easy messaging.
my $infobar;      # Gtk2::InfoBar for status
my $pb;           # Gtk2::ProgressBar
my $liststore;    # Information on current and remote versions

my $updated = 0;

sub show_window {
    my $box = Gtk2::VBox->new( FALSE, 5 );

    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_policy( 'never', 'never' );
    $scrolled->set_shadow_type( 'etched-out' );
    $box->pack_start( $scrolled, FALSE, TRUE, 2 );

    # update available images:
    # gtk-yes = yes
    # gtk-no  = no
    # gtk-dialog-error = unknown

    $liststore = Gtk2::ListStore->new(
        # product, local version,
        'Glib::String', 'Glib::String',
        # remote version, update available image
        'Glib::String', 'Glib::String',
    );

    my $view = Gtk2::TreeView->new_with_model( $liststore );
    $view->set_can_focus( FALSE );
    $scrolled->add( $view );
    my $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'Product' ),
        Gtk2::CellRendererText->new,
        text => 0,
    );
    $view->append_column( $column );
    $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'Installed' ),
        Gtk2::CellRendererText->new,
        text => 1,
    );
    $view->append_column( $column );
    $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'Available' ),
        Gtk2::CellRendererText->new,
        text => 2,
    );
    $view->append_column( $column );
    $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'Update Available' ),
        Gtk2::CellRendererPixbuf->new,
        stock_id => 3,
    );
    $view->append_column( $column );

    # Get local information
    my $local_sig_version = ClamTk::App->get_local_sig_version();
    my $local_tk_version  = ClamTk::App->get_TK_version();

    #<<<
    my @data = (
        {
            product => _( 'Antivirus signatures' ),
            local   => $local_sig_version,
            remote  => _('Unknown'),
            update  => 'gtk-dialog-error',
        },
        {
            product => _( 'Graphical interface' ),
            local   => $local_tk_version,
            remote  => _('Unknown'),
            update  => 'gtk-dialog-error',
        },
        {
            product => ' ',
            local   => ' ',
            remote  => ' ',
            update  => ' ',
        },
    );

    for my $item ( @data ) {
        my $iter = $liststore->append;
        $liststore->set( $iter,
                0, $item->{ product },
                1, $item->{ local },
                2, $item->{ remote },
                3, $item->{ update },
        );
    }
    #>>>

    $infobar = Gtk2::InfoBar->new;
    $infobar->set_message_type( 'other' );
    $infobar->add_button( 'gtk-ok', -5 );

    my $label = Gtk2::Label->new;
    $label->set_text( _( 'Check for updates' ) );
    $label->set_alignment( 0.0, 0.5 );
    $infobar->get_content_area()->add( $label );
    #<<<
    $infobar->signal_connect(
        response => sub {
            update_store();
        }
    );
    #>>>

    $pb = Gtk2::ProgressBar->new;
    $box->pack_start( $infobar, FALSE, FALSE, 0 );
    $box->pack_start( $pb,      FALSE, FALSE, 0 );

    $box->show_all;
    $pb->hide;
    return $box;
}

sub update_store {
    my $web_version = get_web_info();
    my ( $remote_tk_version ) = get_remote_TK_version();

    # Reset the liststore
    $liststore->clear;

    # Get local information
    my $local_sig_version ||= ClamTk::App->get_local_sig_version();
    my $local_tk_version  ||= ClamTk::App->get_TK_version();

    # Keep track if we have updates available
    my @updates;

    my $sig_update_available = 'gtk-dialog-error';
    # Ensure we have info for both
    if ( $web_version && $web_version ne _( 'Unknown' ) ) {
        # The only thing we have to check is if
        # the web version is more - then update is available
        if ( $web_version > $local_sig_version ) {
            $sig_update_available = 'gtk-yes';
            push( @updates, 'sigs' );
        } else {
            # Everything else is 'gtk-no'.  I think.
            $sig_update_available = 'gtk-no';
        }
    } else {
        $web_version = _( 'Unknown' );
    }

    my $gui_update_available = 'gtk-dialog-error';
    # We assume we can easily get the local version
    if ( $remote_tk_version ) {
        my ( $local_chopped, $remote_chopped );
        ( $local_chopped  = $local_tk_version ) =~ s/[^0-9]//;
        ( $remote_chopped = $remote_tk_version ) =~ s/[^0-9]//;
        # The only thing we have to check is if
        # the web version is more - then update is available
        if ( $remote_chopped > $local_chopped ) {
            $gui_update_available = 'gtk-yes';
            push( @updates, 'gui' );
        } else {
            # Everything else is 'gtk-no'.  I think.
            $gui_update_available = 'gtk-no';
        }
    } else {
        # warn "unknown tk status\n";
        $remote_tk_version = _( 'Unknown' );
    }

    #<<<
    my @data = (
        {
            product => _( 'Antivirus signatures' ),
            local   => $local_sig_version,
            remote  => $web_version,
            update  => $sig_update_available,
        },
        {
            product => _( 'Graphical interface' ),
            local   => $local_tk_version,
            remote  => $remote_tk_version,
            update  => $gui_update_available,
        },
    );

    for my $item ( @data ) {
        my $iter = $liststore->append;
        $liststore->set( $iter,
            0, $item->{ product },
            1, $item->{ local },
            2, $item->{ remote },
            3, $item->{ update },
        );
    }
    #>>>

    # Can we update?  shared or single
    my $update_pref = '';
    # Return value to see if updates were applied.
    # If so, refresh the store
    my $updated = 0;
    if ( @updates ) {
        my $text = _( 'Updates are available' );
        if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'shared' ) {
            $text .= "\n";
            #<<<
            $text
             .= _( 'You are configured to automatically receive updates' );
            #>>>
            $update_pref = 'shared';
        } else {
            $update_pref = 'single';
        }

        set_infobar_text( 'warning', $text );

        # We only show the update button if the update preference
        # is "single" (user updates manually) or the user is root.
        # Also, as Google Issue #4 showed, !only! when
        # there is a sigs update and not when only a GUI update.
        if ( @updates && grep ( /sigs/, @updates ) ) {
            if ( $update_pref eq 'single' or $> == 0 ) {
                #set_infobar_button( 'gtk-apply', -5 );
                destroy_button();
                my $button = Gtk2::Button->new( _( 'Update' ) );
                $infobar->get_action_area->add( $button );
                $button->show;
                $button->signal_connect(
                    clicked => sub {
                        Gtk2->main_iteration while Gtk2->events_pending;
                        set_infobar_text( 'info', _( 'Please wait...' ) );
                        Gtk2->main_iteration while Gtk2->events_pending;
                        $updated
                            = update_signatures( $local_sig_version,
                            $web_version );
                        # Now we returned from updating signatures...
                        # clear rows (liststore) and display updated info
                        if ( $updated ) {
                            $liststore->clear;
                            # Wonder if this is bad?  Too recursive?
                            update_store();
                            Gtk2->main_iteration while Gtk2->events_pending;
                            ClamTk::GUI->startup();
                            Gtk2->main_iteration while Gtk2->events_pending;
                        } else {
                            set_infobar_text( 'error',
                                _( 'Error updating: try again later' ) );
                            destroy_button();
                        }
                    }
                );
            } else {
                # Remove buttons if they exist, since this
                # user cannot update signatures
                # warn "removing button, cannot update\n";
                destroy_button();
            }
        } else {
            # warn "no updates available\n";
            #set_infobar_text( 'info', _( 'No updates are available.' ) );
            destroy_button();
        }
    }
}

sub get_web_info {
    # Get clamav.net info
    # my $page = 'http://www.clamav.net/lang/en/';
    my $page = 'http://lurker.clamav.net/list/clamav-virusdb.html';

    my $ua = add_ua_proxy();

    Gtk2->main_iteration while Gtk2->events_pending;
    my $response = $ua->get( $page );
    Gtk2->main_iteration while Gtk2->events_pending;
    my $code = '';

    if ( $response->is_success ) {
        $code = $response->decoded_content;
    } else {
        warn "problems getting ClamAV version: ", $response->status_line,
            "\n";
        return FALSE;
    }
    return FALSE if ( !$code );

    if ( $code =~ /daily: (\d{5,})/ ) {
        return $1;
    } else {
        return FALSE;
    }
}

sub get_remote_TK_version {
    my $url = 'https://bitbucket.org/dave_theunsub/clamtk/raw/master/latest';
    # my $url = 'http://clamtk.googlecode.com/git/latest';

    $ENV{ HTTPS_DEBUG } = 1;

    my $ua = add_ua_proxy();

    Gtk2->main_iteration while Gtk2->events_pending;
    my $response = $ua->get( $url );
    Gtk2->main_iteration while Gtk2->events_pending;

    if ( $response->is_success ) {
        my $content = $response->content;
        chomp( $content );
        return $content;
    } else {
        return '';
    }

    return '';
}

sub update_signatures {
    my ( $local_version, $web_version ) = @_;

    $pb->show;
    #$pb->set_show_text( TRUE );
    $pb->set_text( _( 'Downloading...' ) );

    my $step = 1 / ( $web_version - $local_version );

    my $freshclam = get_freshclam_path();

    # The mirrors can be slow sometimes and may return/die
    # 'failed' despite that the update is still in progress.

    # my $update = file_handle
    # my $update_sig_pid = process ID for $update

    my $update;
    my $update_sig_pid;
    eval {
        local $SIG{ ALRM } = sub { die "failed\n" };
        alarm 100;

        $update_sig_pid = open( $update, '-|', "$freshclam --stdout" );
        defined( $update_sig_pid ) or do {
            set_infobar_text( 'error',
                _( 'Error updating: try again later' ) );
            return 0;
        };
        alarm 0;
    };
    if ( $@ && $@ eq "failed\n" ) {
        set_infobar_text( 'error', _( 'Error updating: try again later' ) );
        return 0;
    }

    # We don't want to print out the following lines beginning with:
    # my $do_not_print = "DON'T|WARNING|ClamAV update process";

    # We can't just print stuff out; that's bad for non-English
    # speaking users. So, we'll grab the first couple words
    # and try to sum it up.

    while ( defined( my $line = <$update> ) ) {
        Gtk2->main_iteration while Gtk2->events_pending;
        chomp( $line );

        if ( $line =~ /^Downloading daily/ ) {
            Gtk2->main_iteration while Gtk2->events_pending;
            my $fraction = $pb->get_fraction;
            $fraction += $step;
            if ( $fraction < 1.0 ) {
                $pb->set_fraction( $fraction );
            } else {
                $pb->set_fraction( 1.0 );
            }
            Gtk2->main_iteration while Gtk2->events_pending;
        } elsif ( $line =~ /Database updated/ ) {
            Gtk2->main_iteration while Gtk2->events_pending;
            $pb->set_fraction( 1.0 );
            Gtk2->main_iteration while Gtk2->events_pending;
        } else {
            # warn "skipping line: >$line<\n";
            next;
        }
        Gtk2->main_iteration while Gtk2->events_pending;
    }
    $updated++;
    $pb->set_fraction( 1.0 );
    $pb->set_text( _( 'Complete' ) );

    # Update infobar type and text; remove button
    set_infobar_text( 'info', _( 'Signatures are current' ) );
    $pb->hide;
    destroy_button();

    # Update frontpage infobar
    ClamTk::GUI->startup();

    return TRUE;
}

sub get_freshclam_path {
    my $paths = ClamTk::App->get_path( 'all' );

    my $command = $paths->{ freshclam };
    # If the user will update the signatures manually,
    # append the appropriate paths
    if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'single' ) {
        $command
            .= " --datadir=$paths->{db} --log=$paths->{db}/freshclam.log";
    }

    # Did the user set the proxy option?
    if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) ) {
        if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 2 ) {
            if ( -e "$paths->{db}/local.conf" ) {
                $command .= " --config-file=$paths->{db}/local.conf";
            }
        }
    }

    return $command;
}

sub set_infobar_text {
    my ( $type, $text ) = @_;
    $infobar->set_message_type( $type );

    for my $child ( $infobar->get_content_area->get_children ) {
        Gtk2->main_iteration while Gtk2->events_pending;
        if ( $child->isa( 'Gtk2::Label' ) ) {
            $child->set_text( $text );
            $infobar->queue_draw;
        }
    }
    Gtk2->main_iteration while Gtk2->events_pending;
}

sub set_infobar_button {
    my ( $stock_icon, $signal ) = @_;
    if ( !$infobar->get_action_area->get_children ) {
        $infobar->add_button( $stock_icon, $signal );
    } else {
        for my $child ( $infobar->get_action_area->get_children ) {
            if ( $child->isa( 'Gtk2::Button' ) ) {
                $child->set_label( $stock_icon );
            }
        }
    }
}

sub destroy_button {
    # Remove button from $infobar
    for my $child ( $infobar->get_action_area->get_children ) {
        if ( $child->isa( 'Gtk2::Button' ) ) {
            $child->destroy;
        }
    }
}

sub add_ua_proxy {
    my $agent = LWP::UserAgent->new( ssl_opts => { verify_hostname => 1 } );
    $agent->timeout( 20 );

    $agent->protocols_allowed( [ 'http', 'https' ] );

    if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) ) {
        if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 1 ) {
            $agent->env_proxy;
        } elsif ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 2 ) {
            my $path = ClamTk::App->get_path( 'db' );
            $path .= '/local.conf';
            my ( $url, $port );
            if ( -e $path ) {
                if ( open( my $FH, '<', $path ) ) {
                    while ( <$FH> ) {
                        if ( /HTTPProxyServer\s+(.*?)$/ ) {
                            $url = $1;
                        }
                        last if ( !$url );
                        if ( /HTTPProxyPort\s+(\d+)$/ ) {
                            $port = $1;
                        }
                    }
                    close( $FH );
                    $ENV{ HTTPS_PROXY }                  = "$url:$port";
                    $ENV{ HTTP_PROXY }                   = "$url:$port";
                    $ENV{ PERL_LWP_SSL_VERIFY_HOSTNAME } = 0;
                    $ENV{ HTTPS_DEBUG }                  = 1;
                    $agent->proxy( http  => "$url:$port" );
                    $agent->proxy( https => "$url:$port" );
                }
            }
        }
    }
    return $agent;
}

1;
