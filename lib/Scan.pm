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
package ClamTk::Scan;

use Glib 'TRUE', 'FALSE';
use File::Find;
use Cwd 'chdir';

# use strict;
# use warnings;
$| = 1;

use constant HATE_GNOME_SHELL    => -6;
use constant DESTROY_GNOME_SHELL => -11;

use POSIX 'locale_h', 'strftime';
use File::Basename 'basename', 'dirname', 'fileparse';
use Locale::gettext;
use Encode 'decode';

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

my $SCAN;     # File handle for scanning
my $found;    # Holds information of bad stuff found

my $found_count = 0;    # Scalar number of bad stuff found
my $num_scanned = 0;    # Overall number of files scanned
my %dirs_scanned;       # Directories scanned

my $hb;                     # HeaderBar
my $pb;                     # ProgressBar
my $pb_file_counter = 0;    # For ProgressBar
my $pb_step;                # For ProgressBar
my $root_scan = FALSE;      # Scanning /
my $scan_pid;               # PID of scanner, for killing/cancelling scan

my $stopped = 1;            # Whether scanner is stopped (1) or running (0)
my $directive;              # Options sent to scanner
my $topbar;                 # InfoBar on top
my $bottombar;              # InfoBar on bottom
my $files_scanned_label;    # Label
my $threats_label;          # Label
my $show;                   # Whether or not to show the preferences button
my $window;                 # Main window/dialog
my $from_cli;               # from the commandline?

sub filter {
    # $pkg_name = drop this
    # $scanthis = file or directory to be scanned
    # $show = whether or not to show the preferences button;
    #   we do if it's a commandline or right-click scan; otherwise we don't
    # $from = from the commandline?
    my ( $pkg_name, $scanthis, $show, $from ) = @_;
    $from_cli = $from;

    # Currently just to test permissions:
    # If given a file/directory from the commandline
    # AND we can't scan it, just die.
    # However, if interface is running
    # AND we can't scan it, just return to interface.
    if ( !sanity_check( $scanthis ) ) {
        if ( $from && $from eq 'startup' ) {
            Gtk3->main_quit;
        } else {
            return;
        }
    }

    # We're gonna need these:
    my $paths = ClamTk::App->get_path( 'all' );
    my %prefs = ClamTk::Prefs->get_all_prefs();

    # Don't bother doing anything if clamscan can't be found
    if ( !-e $paths->{ clampath } ) {
        warn "Cannot scan without clamscan!\n";
        return;
    }

    # Begin popup scanning
    $window
        = Gtk3::Dialog->new( undef, undef,
        [ qw| modal destroy-with-parent use-header-bar | ],
        );
    $window->set_deletable( FALSE );
    $window->set_default_size( 450, 80 );

    $hb = Gtk3::HeaderBar->new;
    $window->set_titlebar( $hb );
    $hb->set_title( _( 'Please wait...' ) );
    $hb->set_show_close_button( TRUE );
    $hb->set_decoration_layout( 'menu:close' );

    $window->signal_connect(
        'destroy' => sub {
            if ( !$stopped ) {
                return TRUE;
            } else {
                $window->destroy;
                1;
            }
        }
    );
    $window->set_border_width( 5 );
    $window->set_position( 'center-on-parent' );

    my $images_dir = ClamTk::App->get_path( 'images' );
    if ( -e "$images_dir/clamtk.png" ) {
        my $pixbuf
            = Gtk3::Gdk::Pixbuf->new_from_file( "$images_dir/clamtk.png" );
        my $transparent = $pixbuf->add_alpha( TRUE, 0xff, 0xff, 0xff );
        $window->set_icon( $transparent );
    }

    my $eb = Gtk3::EventBox->new;
    $window->get_content_area->add( $eb );

    my $box = Gtk3::VBox->new( FALSE, 5 );
    $eb->add( $box );

    my $hbox = Gtk3::HBox->new( FALSE, 0 );
    $box->add( $hbox );

    $topbar = Gtk3::InfoBar->new;
    $hbox->pack_start( $topbar, TRUE, TRUE, 5 );

    Gtk3::main_iteration while Gtk3::events_pending;
    $topbar->set_message_type( 'other' );
    set_infobar_text( $topbar, _( 'Preparing...' ) );
    Gtk3::main_iteration while Gtk3::events_pending;

    $pb = Gtk3::ProgressBar->new;
    $box->pack_start( $pb, FALSE, FALSE, 5 );
    $window->{ pb } = $pb;

    # reset numbers
    reset_stats();

    $files_scanned_label
        = Gtk3::Label->new( sprintf _( "Files scanned: %d" ), $num_scanned );
    $files_scanned_label->set_alignment( 0.0, 0.5 );

    $threats_label
        = Gtk3::Label->new( sprintf _( "Possible threats: %d" ),
        $found_count );
    $threats_label->set_alignment( 0.0, 0.5 );

    my $text_box = Gtk3::VBox->new( FALSE, 5 );
    $text_box->add( $files_scanned_label );
    $text_box->add( $threats_label );

    $bottombar = Gtk3::InfoBar->new;
    $box->pack_start( $bottombar, FALSE, FALSE, 5 );

    $bottombar->set_message_type( 'other' );
    # Stupid infobars
    # $use_image = ClamTk::Icons->get_image( 'gtk-cancel' );
    $use_image = 'gtk-cancel';
    $bottombar->add_button( $use_image, HATE_GNOME_SHELL );
    if ( $show ) {
        # $use_image = ClamTk::Icons->get_image( 'preferences-system' );
        $use_image = ClamTk::Icons->get_image( 'gtk-preferences' );
        $bottombar->add_button( $use_image, DESTROY_GNOME_SHELL );
    }
    $bottombar->signal_connect(
        response => sub {
            my ( $bar, $button ) = @_;
            if ( $button eq 'cancel' ) {
                cancel_scan();
            } elsif ( $button eq 'help' ) {
                system( 'clamtk &' );
                return FALSE;
            }
        }
    );
    $bottombar->get_content_area->add( $text_box );

    $window->show_all;
    $window->set_gravity( 'south-east' );
    $window->queue_draw;
    $window->set_position( 'mouse' );
    Gtk3::main_iteration while Gtk3::events_pending;

    # Try to avoid MS Windows file systems...
    # This fubars Live ISOs: see
    # https://github.com/dave-theunsub/clamtk/issues/67
    # $directive .= ' --cross-fs=no';

    # Try to avoid scanning emails...
    $directive .= ' --scan-mail=no';

    # I didn't know we had to explicitly state this.
    # https://github.com/dave-theunsub/clamtk/issues/59
    $directive .= ' --scan-archive=yes';

    # Increase maximum amount of data to scan for each container file;
    # goes hand in hand with the $directive above
    # https://github.com/dave-theunsub/clamtk/issues/59
    $directive .= ' --max-scansize=500M';

    # By default, we ignore .gvfs directories.
    # Once we figure out KDE's process, we'll exclude that too.
    #<<<
    for my $m (
            'smb4k',
            "/run/user/$ENV{USER}/gvfs",
            "$ENV{HOME}/.gvfs" ) {
                $directive .= " --exclude-dir=$m";
    }
    #>>>

    # Now strip whitelisted directories
    for my $ignore (
        split(
            /;/,
            ClamTk::Prefs->get_preference( 'Whitelist' )
                . $paths->{ whitelist_dir }
        )
        )
    {
        # warn "excluding $ignore\n";
        # --exclude-dir=REGEX  Don't scan directories matching REGEX
        # Using REGEX is important because users could have some
        # of the whitelisted domains as part of a directory that
        # should be scanned.
        # Github #61 - https://github.com/dave-theunsub/clamtk/issues/61
        $directive .= " --exclude-dir=^" . quotemeta( $ignore );
    }

    # Remove mail directories and some backup directories for now.
    # Not all of these can be appended to $HOME for a more
    # specific path - kmail (e.g.) is somewhere
    # under $HOME/.kde/blah/foo/...
    my @maildirs = qw(
        .thunderbird	.mozilla-thunderbird
        Mail	kmail   evolution   timeshift
    );
    for my $mailbox ( @maildirs ) {
        # warn "excluding mailbox directory $mailbox\n";
        $directive .= " --exclude-dir=$mailbox";
    }

    # remove the hidden files if chosen:
    if ( !$prefs{ ScanHidden } ) {
        # But only if Trash directory is not being scanned
        if ( $scanthis !~ m#/.local/share/Trash# ) {
            $directive .= ' --exclude="\/\."';
        }
    }

    # symlinks:
    # The symlink stuff from clamscan requires >= 0.97.
    my ( $version ) = ClamTk::App->get_AV_version();
    # Ensure it's just digits and dots:
    $version =~ s/[^0-9\.]//g;
    $version =~ s/^[0\.]+//;
    $version =~ s/\.0$//;
    warn "clamscan version = >$version<\n";
    if (   ( $version <=> '97' ) == 0
        || ( $version <=> '97' ) == 1 )
    {
        $directive .= ' --follow-dir-symlinks=1';
        $directive .= ' --follow-file-symlinks=1';
    }
    # This feature mitigates the risk of malformed media files intended
    # to exploit vulnerabilities in other software. At present, media
    # validation exists for JPEG, TIFF, PNG and GIF files.
    if ( $version >= '103.1' ) {
        $directive .= ' --alert-broken-media=yes';
    }

    # we'll count this as ! $stopped
    #$stopped = 0;

    # reset %$found
    $found = {};

    # These lines are for 'thorough'. :)
    # If it's selected, we add detection for both
    # potentially unwanted applications and broken executables.
    # Version 0.101.0 changed and added some options.
    if ( $prefs{ Thorough } ) {
        if (   ( $version <=> '101' ) == 0
            || ( $version <=> '101' ) == 1 )
        {
            $directive .= ' --detect-pua --alert-broken' . ' --alert-macros';
        } else {
            $directive .= ' --detect-pua --algorithmic-detection';
        }
    } else {
        if (   ( $version cmp '101' ) == 0
            || ( $version cmp '101' ) == 1 )
        {
            $directive =~ s/\s--detect-pua --alert-broken --alert-macros'//;
        } else {
            $directive =~ s/\s--detect-pua --algorithmic-detection//;
        }
    }

    # Heuristic scanning
    if ( $prefs{ Heuristic } ) {
        # By default, if included, == yes
        $directive .= ' --heuristic-alerts=yes';
    } else {
        $directive .= ' --heuristic-alerts=no';
    }

    # only a single file

    # By default, 20Mb is the largest we go -
    # unless the preference is to ignore size.
    if ( !$prefs{ SizeLimit } ) {
        $directive .= ' --max-filesize=20M';
    }

    if ( !$prefs{ Recursive } ) {
        $directive .= ' --max-dir-recursion=1';
    } else {
        $directive .= ' --recursive=yes';
    }

    scan( $scanthis, $directive );

    clean_up();
}

sub scan {
    my ( $path_to_scan, $directive ) = @_;
    chomp( $path_to_scan );
    chomp( $directive );

    $pb_step = get_step( $path_to_scan );
    if ( $pb_step ) {
        $pb->set_pulse_step( $pb_step );
    } else {
        $pb->{ timer } = Glib::Timeout->add( 200, \&progress_timeout, $pb );
        $root_scan = TRUE;
    }

    $pb->show;

    my $quoted = quotemeta( $path_to_scan );
    chomp( $quoted );

    # Leave if we have no real path
    if ( !$path_to_scan ) {
        warn "No path to scan!\n";
        return;
    }

    my $paths   = ClamTk::App->get_path( 'all' );
    my $command = $paths->{ clamscan };

    # Use the user's sig db if it's selected
    if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'single' ) {
        $command .= " --database=$paths->{db}";
    }

    # Implicit fork; gives us the PID of clamscan so we can
    # kill it if the user hits the Stop button
    #<<<
    # Using the verbose (-v) switch gives us the next file
    # for the display "Scanning $1..."
    $scan_pid
        = open( $SCAN, '-|', "$command $directive -v $quoted 2>&1" );
    defined( $scan_pid ) or die "couldn't fork: $!\n";
    $window->queue_draw;
    Gtk3::main_iteration while Gtk3::events_pending;
    #>>>
    # binmode( $SCAN, ':utf8:bytes' );

    Gtk3::main_iteration while Gtk3::events_pending;
    while ( <$SCAN> ) {
        chomp;
        $window->queue_draw;
        Gtk3::main_iteration while Gtk3::events_pending;

        # Warning stuff we don't need
        next if ( /^LibClamAV/ );
        next if ( /^\s*$/ );

        if ( /^Scanning (.*?)$/ ) {
            my $base = decode( 'UTF-8', basename( $1 ) );
            # Display stuff in popup infobar
            set_infobar_text(
                $topbar,
                # sprintf( _( 'Scanning %s...' ), $dirname )
                # sprintf( _( 'Scanning %s...' ), $dirname )
                sprintf( _( 'Scanning %s...' ), $base )
            );
            $num_scanned++;
            if ( !$root_scan ) {
                my $pb_current = $pb->get_fraction;

                if (   $pb_current + $pb_step <= 0
                    || $pb_current + $pb_step >= 1.0 )
                {
                    $pb_current = .99;
                } else {
                    $pb_current += $pb_step;
                }
                $pb->set_fraction( $pb_current );
            }

            Gtk3::main_iteration while Gtk3::events_pending;
            $files_scanned_label->set_text( sprintf _( "Files scanned: %d" ),
                $num_scanned );
            $topbar->show_all;
            Gtk3::main_iteration while Gtk3::events_pending;
            $window->queue_draw;
            next;
        }

        my ( $file, $status );
        if ( /(.*?): ([^:]+) FOUND/ ) {
            $file   = $1;
            $status = $2;
        }

        # Ensure the file is still there (things get moved)
        # and that it got scanned
        next unless ( $file && -e $file && $status );
        next if ( $status =~ /module failure/ );

        chomp( $file )   if ( defined $file );
        chomp( $status ) if ( defined $status );

        my $dirname   = decode( 'UTF-8', dirname( $file ) );
        my $fileparse = decode( 'UTF-8', fileparse( $file ) );

        my $hidden = ClamTk::Prefs->get_preference( 'ScanHidden' );
        next if ( !$hidden && basename( $fileparse ) =~ /^\./ );

        my $dirparse;
        if ( length( $dirname ) > 35 ) {
            $dirparse = substr $dirname, 0, 35;
        } else {
            $dirparse = $dirname;
        }

        # Lots of temporary things under /tmp/clamav;
        # we'll just ignore them.
        $dirs_scanned{ $dirname } = 1
            unless ( dirname( $file ) =~ /\/tmp\/clamav/
            || dirname( $file ) eq '.' );

        # Do not show files in archives - we just want the end-result.
        # It still scans and we still show the result.
        next if ( $file =~ /\/tmp\/clamav/ );

        # $status is the "virus" name.
        $status =~ s/\s+FOUND$//;

        # These aren't necessarily clean (despite the variable's name)
        # - we just don't want them counted as viruses
        my $clean_words = join( '|',
            'OK',                 'Zip module failure',
            "RAR module failure", 'Encrypted.PDF',
            'Encrypted.RAR',      'Encrypted.Zip',
            'Empty file',         'Excluded',
            'Input/Output error', 'Files number limit exceeded',
            'handler error',      'Broken.Executable',
            'Oversized.Zip',      'Symbolic link' );

        if ( $status !~ /$clean_words/ ) {    # a virus
            $found->{ $found_count }->{ name }   = $file;
            $found->{ $found_count }->{ status } = $status;
            $found->{ $found_count }->{ action } = _( 'None' );
            $found_count++;
            $threats_label->set_text( sprintf _( "Possible threats: %d" ),
                $found_count );
        }

    }

    Gtk3::main_iteration while Gtk3::events_pending;

    # Done scanning - close filehandle and return to
    # filter() and then to clean-up
    close( $SCAN );    # or warn "Unable to close scanner! $!\n";
}

sub cancel_scan {
    kill 15, $scan_pid + 1;
    waitpid( $scan_pid + 1, 0 ) if ( $scan_pid + 1 );
    kill 15, $scan_pid if ( $scan_pid );
    waitpid( $scan_pid, 0 ) if ( $scan_pid );

    close( $SCAN );
    $stopped = 1;
}

sub clean_up {
    set_infobar_text( $topbar, _( 'Cleaning up...' ) );
    $pb->set_fraction( 1.00 );
    destroy_progress();

    destroy_buttons();
    add_closing_buttons();

    $hb->set_title( _( 'Complete' ) );
    my $message = '';
    if ( !$found_count ) {
        $message = _( 'Scanning complete' );
    } else {
        $message = _( 'Possible threats found' );
    }
    set_infobar_text( $topbar, $message );

    # Save scan information
    logit();

    if ( $found_count ) {
        ClamTk::Results->show_window( $found, $window );
        if ( $from_cli ) {
            Gtk3->main_quit;
        }
    } else {
        bad_popup();
    }

    # reset numbers
    reset_stats();
}

sub destroy_progress {
    Glib::Source->remove( $window->{ pb }->{ timer } )
        if ( $root_scan );

    return FALSE;
}

sub reset_stats {
    # reset things
    $num_scanned     = 0;
    $found_count     = 0;
    $pb_file_counter = 0;
    $pb_step         = 0;
    %dirs_scanned    = ();
    $stopped         = 1;
    $directive       = '';
    $root_scan       = FALSE;
}

sub bad_popup {
    my $dialog = Gtk3::MessageDialog->new(
        $window, [ qw| modal destroy-with-parent | ],
        'info',  'close', _( 'No threats found' ),
    );
    $dialog->run;
    $dialog->destroy;
}

sub logit {
    my $db_total = ClamTk::App->get_sigtool_info( 'count' );
    # warn "in Scan: db_total = >$db_total<\n";
    my $REPORT;    # filehandle for histories log

    #<<<
    my ( $mon, $day, $year )
        = split / /, strftime( '%b %d %Y', localtime );

    # Save date of scan
    if ( $found_count > 0 ) {
        ClamTk::Prefs->set_preference(
                'LastInfection', "$day $mon $year"
        );
    }
    #>>>

    my %prefs = ClamTk::Prefs->get_all_prefs();
    my $paths = ClamTk::App->get_path( 'history' );

    my $virus_log
        = $paths . "/" . decode( 'UTF-8', "$mon-$day-$year" ) . '.log';

    #<<<
    # sort the directories scanned for display
    my @sorted = sort { $a cmp $b } keys %dirs_scanned;
    if ( open $REPORT, '>>:encoding(UTF-8)', $virus_log ) {
        print $REPORT "\nClamTk, v",
            ClamTk::App->get_TK_version(), "\n",
            scalar localtime,
            "\n";
        print $REPORT sprintf _(
                "ClamAV Signatures: %d\n" ),
                $db_total;
        print $REPORT _( "Directories Scanned:\n" );
        for my $list ( @sorted ) {
            print $REPORT "$list\n";
        }
        printf $REPORT _(
            "\nFound %d possible %s (%d %s scanned).\n\n" ),
            $found_count,
            $found_count == 1 ? _( 'threat' ) : _( 'threats' ),
            $num_scanned,
            $num_scanned == 1 ? _( 'file' ) : _( 'files' );
    } else {
            warn "Could not write to logfile. Check permissions.\n";
    }
    #>>>

    # Set the minimum sizes for the two columns,
    # the filename and its status - if we're saving a log (which we
    # do, by default)
    my $lsize = 20;
    my $rsize = 20;
    if ( $found_count == 0 ) {
        print $REPORT _( "No threats found.\n" );
    } else {
        # Now get the longest lengths of the column contents.
        for my $length ( sort keys %$found ) {
            $lsize
                = ( length( $found->{ $length }->{ name } ) > $lsize )
                ? length( $found->{ $length }->{ name } )
                : $lsize;
            $rsize
                = ( length( $found->{ $length }->{ status } ) > $rsize )
                ? length( $found->{ $length }->{ status } )
                : $rsize;
        }
        # Set a buffer which is probably unnecessary.
        $lsize += 5;
        $rsize += 5;
        # Print to the log:
        for my $num ( sort keys %$found ) {
            printf $REPORT "%-${lsize}s %-${rsize}s\n",
                decode( 'utf8', $found->{ $num }->{ name } ),
                $found->{ $num }->{ status };
        }
    }

    print $REPORT '-' x ( $lsize + $rsize + 5 ), "\n";
    close( $REPORT );

    return;
}

sub set_infobar_text {
    my ( $bar, $text ) = @_;

    Gtk3::main_iteration while Gtk3::events_pending;
    for my $c ( $bar->get_content_area->get_children ) {
        if ( $c->isa( 'Gtk3::Label' ) ) {
            $c->set_text( $text );
            Gtk3::main_iteration while Gtk3::events_pending;
            return;
        }
    }

    #<<<
    my $label = Gtk3::Label->new;
    $label->set_text( _( $text ) );
    $label->set_alignment( 0.0, 0.5 );
    $label->set_ellipsize( 'middle' );
    $bar->get_content_area->add(
            #Gtk3::Label->new( _( $text ) )
            $label
    );
    #>>>
    $window->queue_draw;
    Gtk3::main_iteration while Gtk3::events_pending;
}

sub add_default_buttons {
    # We're going to show the following:
    # cancel-button: obviously cancels the scan
    # prefs-button: allows popup 'clamtk' with no args, for settings.
    # We don't even need translations for this.
    $bottombar->add_button( 'gtk-cancel',      HATE_GNOME_SHELL, );
    $bottombar->add_button( 'gtk-preferences', DESTROY_GNOME_SHELL, );

    $bottombar->signal_connect(
        response => sub {
            my ( $bar, $response ) = @_;
            if ( $response eq 'cancel' ) {
                cancel_scan();
                return TRUE;
            } elsif ( $response eq 'help' ) {
                system( 'clamtk &' );
                return FALSE;
            }
        }
    );
}

sub add_closing_buttons {
    $bottombar->add_button( 'gtk-close', -7 );
    if ( $show ) {
        $bottombar->add_button( 'gtk-preferences', DESTROY_GNOME_SHELL, );
    }

    $bottombar->signal_connect(
        response => sub {
            my ( $bar, $response ) = @_;
            if ( $response eq 'close' ) {
                $window->destroy;
            } elsif ( $response eq 'help' ) {
                system( 'clamtk &' );
                return FALSE;
            }
        }
    );
    $bottombar->show_all;
}

sub destroy_buttons {
    for my $c ( $bottombar->get_action_area->get_children ) {
        if ( $c->isa( 'Gtk3::Button' ) ) {
            $c->destroy;
        }
    }
    return TRUE;
}

sub get_step {
    my $dir = shift;

    my $recur = ClamTk::Prefs->get_preference( 'Recursive' );

    return if ( $dir eq '/' );

    if ( $recur ) {
        find( \&wanted, $dir );
    } else {
        find( { wanted => \&wanted, preprocess => \&nodirs }, $dir );
    }

    #find( { \&wanted, no_chdir => ( $recur ) ? 0 : 1 }, $dir );

    if ( !$pb_file_counter ) {
        return;
    }

    return 1 / $pb_file_counter;
}

sub nodirs {
    grep !-d, @_;
}

sub progress_timeout {
    $pb->pulse;

    return TRUE;
}

sub wanted {
    my $file = $_;
    return unless ( -f $file );
    my $hidden = ClamTk::Prefs->get_preference( 'ScanHidden' );
    next if ( !$hidden && $file =~ /^\./ );
    $pb_file_counter++;
}

sub sanity_check {
    my $check = shift;

    if ( -d $check ) {
        if ( !chdir( $check ) || $check =~ m#^(/proc|/sys|/dev)# ) {
            popup(
                _(  'You do not have permissions to scan that file or directory'
                )
            );
            reset_stats();
            return 0;
        } else {
            return 1;
        }
    } elsif ( -f $check ) {
        if ( !-r $check || $check =~ m#^(/proc|/sys|/dev)# ) {
            popup(
                _(  'You do not have permissions to scan that file or directory'
                )
            );
            reset_stats();
            return 0;
        } else {
            return 1;
        }
    }
}

sub popup {
    my ( $message, $option ) = @_;

    my $dialog = Gtk3::MessageDialog->new(
        undef,    # no parent
        [ qw| modal destroy-with-parent | ],
        'info',
        $option ? 'ok-cancel' : 'close',
        $message,
    );

    if ( 'ok' eq $dialog->run ) {
        $dialog->destroy;
        return TRUE;
    }
    $dialog->destroy;

    return FALSE;
}

1;
