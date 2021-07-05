# ClamTk, copyright (C) 2004-2021 Dave M
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
package ClamTk::Update;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use LWP::UserAgent;
use Locale::gettext;

# Keeping these global for easy messaging.
my $infobar;      # InfoBar for status
my $pb;           # ProgressBar for ... showing progress
my $liststore;    # Information on current and remote versions
my $iter_hash;    # Must be global to update sig area

my $updated = 0;

sub show_window {
    my $box = Gtk3::Box->new( vertical, 5 );
    $box->set_homogeneous( FALSE );

    my $top_box = Gtk3::Box->new( vertical, 5 );
    $top_box->set_homogeneous( FALSE );
    $box->pack_start( $top_box, TRUE, TRUE, 0 );

    my $scrolled = Gtk3::ScrolledWindow->new( undef, undef );
    $scrolled->set_policy( 'never', 'never' );
    $scrolled->set_shadow_type( 'etched-out' );
    $top_box->pack_start( $scrolled, FALSE, TRUE, 2 );

    # update available images:
    # gtk-yes = yes
    # gtk-no  = no
    # gtk-dialog-error = unknown

    $liststore = Gtk3::ListStore->new(
        # product, local version,
        'Glib::String', 'Glib::String', 'Glib::String',
    );

    # Product column
    my $view = Gtk3::TreeView->new_with_model( $liststore );
    $view->set_can_focus( FALSE );
    $scrolled->add( $view );
    my $column = Gtk3::TreeViewColumn->new_with_attributes(
        _( 'Product' ),
        Gtk3::CellRendererText->new,
        text => 0,
    );
    $column->set_alignment( 0.5 );
    $view->append_column( $column );

    # Installed version column
    $column = Gtk3::TreeViewColumn->new_with_attributes(
        _( 'Installed' ),
        Gtk3::CellRendererText->new,
        text => 1,
    );
    $column->set_alignment( 0.5 );
    $view->append_column( $column );

    # Date of signatures
    $column = Gtk3::TreeViewColumn->new_with_attributes(
        _( 'Date' ),
        Gtk3::CellRendererText->new,
        text => 2,
    );
    $column->set_alignment( 0.5 );
    $view->append_column( $column );

    # Get local information
    my $local_sig_version = ClamTk::App->get_local_sig_version();

    # Get date of signatures
    my $av_date = ClamTk::App->get_sigtool_info( 'date' );

    #<<<
    my @data = (
        {
            product => _( 'Antivirus signatures' ),
            local   => $local_sig_version,
            date    => $av_date,
        },
    );

    for my $item ( @data ) {
        my $iter = $liststore->append;

        # make a copy for updating
        $iter_hash = $iter;

        $liststore->set( $iter,
                0, $item->{ product },
                1, $item->{ local },
                2, $item->{ date },
        );
    }
    #>>>

    $infobar = Gtk3::InfoBar->new;
    $infobar->set_message_type( 'other' );

    my $text = '';
    if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'shared' ) {
        my $label = Gtk3::Label->new;
        $label->set_text(
            _( 'You are configured to automatically receive updates' ) );
        $infobar->get_content_area()->add( $label );
    } else {
        $text = _( 'Check for updates' );
        $infobar->add_button( $text, -5 );

        $infobar->signal_connect(
            response => sub {
                Gtk3::main_iteration while Gtk3::events_pending;
                update_signatures();
                Gtk3::main_iteration while Gtk3::events_pending;
            }
        );
    }

    $box->pack_start( Gtk3::VBox->new, TRUE, TRUE, 5 );

    $pb = Gtk3::ProgressBar->new;
    $box->pack_start( $infobar, FALSE, FALSE, 0 );
    $box->pack_start( $pb,      FALSE, FALSE, 0 );

    $view->columns_autosize();
    $box->show_all;
    $pb->hide;
    return $box;
}

sub get_remote_TK_version {
    my $url
        = 'https://raw.githubusercontent.com/dave-theunsub/clamtk/master/latest';

    $ENV{ HTTPS_DEBUG } = 1;

    my $ua = add_ua_proxy();

    my $response = $ua->get( $url );

    if ( $response->is_success ) {
        my $content = $response->content;
        chomp( $content );
        # warn "remote tk version = >$content<\n";
        return $content;
    } else {
        warn "failed remote tk check >", $response->status_line, "<\n";
        return '';
    }

    return '';
}

sub update_signatures {
    $pb->{ timer } = Glib::Timeout->add( 100, \&progress_timeout, $pb );
    $pb->show;
    $pb->set_text( _( 'Please wait...' ) );

    my $freshclam = get_freshclam_path();
    if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'single' ) {
        my $dbpath = ClamTk::App->get_path( 'localfreshclamconf' );
        if ( -e $dbpath ) {
            $freshclam .= " --config-file=$dbpath";
        }
    }

    # The mirrors can be slow sometimes and may return/die
    # 'failed' despite that the update is still in progress.

    # my $update = file_handle
    # my $update_sig_pid = process ID for $update

    my $update;
    my $update_sig_pid;
    eval {
        local $SIG{ ALRM } = sub {
            die "failed updating signatures (timeout)\n";
        };
        alarm 100;

        $update_sig_pid = open( $update, '-|', "$freshclam --stdout" );
        defined( $update_sig_pid )
            or do {
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
    #
    # logg("!Database update process failed: %s (%d)\n"
    # Downloading database patch # 25961..

    while ( defined( my $line = <$update> ) ) {
        Gtk3::main_iteration while Gtk3::events_pending;
        $pb->set_text( _( 'Downloading...' ) );
        chomp( $line );

        if ( $line =~ /failed/ ) {
            # Print these out to terminal window for now
            warn $line, "\n";

        } elsif ( $line =~ /Database test passed./ ) {
            warn "Database test passed.\n";

        } elsif ( $line =~ /^Downloading daily-(\d+).*?$/ ) {
            # This one should probably be removed;
            # was probably changed to the next elsif
            my $new_daily = $1;

            $liststore->set( $iter_hash, 0, _( 'Antivirus signatures' ),
                1, $new_daily, );

        } elsif ( $line
            =~ q#^Retrieving https://database.clamav.net/daily-(\d+).cdiff# )
        {
            my $new_daily = $1;

            $liststore->set( $iter_hash, 0, _( 'Antivirus signatures' ),
                1, $new_daily, );

        } elsif ( $line =~ /^Testing database/ ) {
            $pb->set_text( _( 'Testing database' ) );

        } elsif ( $line =~ /^Downloading database patch # (\d+).*?$/ ) {
            my $new_daily = $1;

            $liststore->set( $iter_hash, 0, _( 'Antivirus signatures' ),
                1, $new_daily, );

        } elsif ( $line =~ /Database updated/ ) {
            $pb->set_fraction( 1.0 );

        } elsif (
            # bytecode appears to be last
            $line =~ /.*?bytecode.*?$/ && ( $line =~ /.*?up-to-date\.$/
                || $line =~ /.*?up to date .*?/
                || $line =~ /.*?updated\.$/ )
            )
        {
            $pb->set_fraction( 1.0 );
        } else {
            # warn "skipping line: >$line<\n";
            next;
        }
        Gtk3::main_iteration while Gtk3::events_pending;
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
    set_infobar_text( 'info', _( 'Complete' ) );
    ClamTk::GUI::set_infobar_mode( 'info', '' );
    $pb->hide;
    destroy_button();

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
    # Add verbosity
    $command .= " --verbose";

    # Was the proxy option set?
    if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) ) {
        if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 2 ) {
            if ( -e $paths->{ localfreshclamconf } ) {
                $command .= " --config-file=$paths->{ localfreshclamconf }";
            }
        }
    }

    return $command;
}

sub set_infobar_text {
    my ( $type, $text ) = @_;
    $infobar->set_message_type( $type );

    for my $child ( $infobar->get_content_area->get_children ) {
        if ( $child->isa( 'Gtk3::Label' ) ) {
            $child->set_text( $text );
            $infobar->queue_draw;
        }
    }
}

sub set_infobar_button {
    my ( $stock_icon, $signal ) = @_;
    if ( !$infobar->get_action_area->get_children ) {
        $infobar->add_button( $stock_icon, $signal );
    } else {
        for my $child ( $infobar->get_action_area->get_children ) {
            if ( $child->isa( 'Gtk3::Button' ) ) {
                $child->set_label( $stock_icon );
            }
        }
    }
}

sub destroy_button {
    # Remove button from $infobar
    for my $child ( $infobar->get_action_area->get_children ) {
        if ( $child->isa( 'Gtk3::Button' ) ) {
            $child->destroy;
        }
    }
}

sub progress_timeout {
    $pb->pulse;

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
                        last
                            if ( !$url );
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
