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
my $iter_hash;    # Must be global to update sig area

my $updated = 0;

sub show_window {
    my $box = Gtk2::VBox->new( FALSE, 5 );

    my $top_box = Gtk2::VBox->new( FALSE, 5 );
    $box->pack_start( $top_box, TRUE, TRUE, 0 );

    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_policy( 'never', 'never' );
    $scrolled->set_shadow_type( 'etched-out' );
    $top_box->pack_start( $scrolled, FALSE, TRUE, 2 );

    # update available images:
    # gtk-yes = yes
    # gtk-no  = no
    # gtk-dialog-error = unknown

    $liststore = Gtk2::ListStore->new(
        # product, local version,
        'Glib::String', 'Glib::String',
    );

    # Product column
    my $view = Gtk2::TreeView->new_with_model( $liststore );
    $view->set_can_focus( FALSE );
    $scrolled->add( $view );
    my $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'Product' ),
        Gtk2::CellRendererText->new,
        text => 0,
    );
    $view->append_column( $column );

    # Installed version column
    $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'Installed' ),
        Gtk2::CellRendererText->new,
        text => 1,
    );
    $view->append_column( $column );

    # Get local information
    my $local_sig_version = ClamTk::App->get_local_sig_version();

    #<<<
    my @data = (
        {
            product => _( 'Antivirus signatures' ),
            local   => $local_sig_version,
        },
    );

    for my $item ( @data ) {
        my $iter = $liststore->append;

        # make a copy for updating
        $iter_hash = $iter;

        $liststore->set( $iter,
                0, $item->{ product },
                1, $item->{ local },
        );
    }
    #>>>

    $infobar = Gtk2::InfoBar->new;
    $infobar->set_message_type( 'other' );

    my $text = '';
    if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'shared' ) {
        $text = _( 'You are configured to automatically receive updates' );
    } else {
        $text = _( 'Check for updates' );
        $infobar->add_button( 'gtk-ok', -5 );
    }

    my $label = Gtk2::Label->new;
    $label->set_text( $text );
    $infobar->get_content_area()->add( $label );
    #<<<
    $infobar->signal_connect(
        response => sub {
                # update_store();
                update_signatures();
        }
    );
    #>>>

    $box->pack_start( Gtk2::VBox->new, TRUE, TRUE, 5 );

    $pb = Gtk2::ProgressBar->new;
    $box->pack_start( $infobar, FALSE, FALSE, 0 );
    $box->pack_start( $pb,      FALSE, FALSE, 0 );

    $box->show_all;
    $pb->hide;
    return $box;
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
    $pb->{ timer } = Glib::Timeout->add( 100, \&progress_timeout, $pb );
    $pb->show;
    #$pb->set_show_text( TRUE );
    $pb->set_text( _( 'Please wait...' ) );

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
        $pb->set_text( _( 'Downloading...' ) );
        Gtk2->main_iteration while Gtk2->events_pending;
        chomp( $line );

        if ( $line =~ /^Downloading daily-(\d+)/ ) {
            my $new_daily = $1;
            Gtk2->main_iteration while Gtk2->events_pending;

            $liststore->set( $iter_hash, 0, _( 'Antivirus signatures' ),
                1, $new_daily, );

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
    # Get local information. It would probably be okay to just
    # keep the same number we saw during the update, but this
    # gives the "for sure" sig version installed:
    my $local_sig_version = ClamTk::App->get_local_sig_version();

    $liststore->set( $iter_hash, 0, _( 'Antivirus signatures' ),
        1, $local_sig_version, );
    Glib::Source->remove( $pb->{ timer } );
    $pb->set_fraction( 1.0 );
    $pb->set_text( _( 'Complete' ) );

    # Update infobar type and text; remove button
    Gtk2->main_iteration while Gtk2->events_pending;
    set_infobar_text( 'info', '' );
    ClamTk::GUI::set_infobar_mode( 'info', '' );
    # $pb->hide;
    # destroy_button();

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

sub progress_timeout {
    Gtk2->main_iteration while Gtk2->events_pending;
    $pb->pulse;
    Gtk2->main_iteration while Gtk2->events_pending;

    return TRUE;
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
