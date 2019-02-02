# ClamTk, copyright (C) 2004-2019 Dave M
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
package ClamTk::Schedule;

# I haven't found a cross-distro Perl module for
# scheduling, so we have call crontab as a system command.

# use strict;
# use warnings;
$| = 1;

use POSIX 'locale_h';
use Locale::gettext;

use Glib 'TRUE', 'FALSE';

use open ':encoding(utf8)';

# This should be under /usr/bin, but we'll check anyway.
my $cmd
    = ( -e '/usr/bin/crontab' ) ? '/usr/bin/crontab'
    : ( -e '/usr/local/bin/crontab' ) ? '/usr/local/bin/crontab'
    : ( -e '/bin/crontab' )           ? '/bin/crontab'
    :                                   '';
chomp( $cmd );

my ( $scan_status_label, $defs_status_label );

my ( $hour_spin_av,   $min_spin_av );
my ( $hour_spin_scan, $min_spin_scan );
my ( $hour_spin_defs, $min_spin_defs );
my ( $scan_apply_btn, $scan_remove_btn );
my ( $defs_apply_btn, $defs_remove_btn );

sub show_window {
    my $dialog
        = Gtk2::Dialog->new( _( 'Schedule' ), undef, 'destroy-with-parent' );
    $dialog->signal_connect( close   => sub { $dialog->destroy } );
    $dialog->signal_connect( destroy => sub { Gtk2->main_quit } );

    my $ebox = Gtk2::EventBox->new;
    #$ebox->modify_bg( 'normal',
    #    Gtk2::Gdk::Color->new( 0xFFFF, 0xFFFF, 0xFFFF ) );
    $dialog->get_content_area->add( $ebox );
    $dialog->set_position( 'mouse' );

    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $ebox->add( $vbox );

    ################
    # scan options #
    ################

    my $scan_frame = Gtk2::Frame->new( _( 'Scan' ) );
    $vbox->pack_start( $scan_frame, FALSE, FALSE, 5 );
    my $scan_box = Gtk2::VBox->new( FALSE, 5 );
    $scan_frame->add( $scan_box );

    my $label = Gtk2::Label->new(
        _( 'Select a time to scan your home directory' ) );
    $scan_box->pack_start( $label, FALSE, FALSE, 5 );

    $label
        = Gtk2::Label->new( _( 'Set the scan time using a 24 hour clock' ) );
    $scan_box->pack_start( $label, FALSE, FALSE, 5 );

    my $time_hbox = Gtk2::HBox->new;
    $scan_box->pack_start( $time_hbox, FALSE, FALSE, 0 );

    $hour_spin_scan = Gtk2::SpinButton->new_with_range( 0, 23, 1 );
    $time_hbox->pack_start( $hour_spin_scan, TRUE, TRUE, 5 );
    $hour_spin_scan->set_wrap( TRUE );
    $hour_spin_scan->set_tooltip_text(
        _( 'Set the hour using a 24 hour clock' ) );
    my $hour_label = Gtk2::Label->new( _( 'Hour' ) );
    $hour_label->set_alignment( 0.0, 0.5 );
    $time_hbox->pack_start( $hour_label, FALSE, TRUE, 5 );

    $min_spin_scan = Gtk2::SpinButton->new_with_range( 0, 59, 1 );
    $min_spin_scan->set_wrap( TRUE );
    $time_hbox->pack_start( $min_spin_scan, TRUE, TRUE, 5 );
    my $min_label = Gtk2::Label->new( _( 'Minute' ) );
    $min_label->set_alignment( 0.0, 0.5 );
    $time_hbox->pack_start( $min_label, FALSE, TRUE, 5 );

    my $time_bar = Gtk2::Toolbar->new;
    $scan_box->pack_start( $time_bar, FALSE, FALSE, 0 );
    $time_bar->set_style( 'icons' );

    my $dsep = Gtk2::SeparatorToolItem->new;
    $dsep->set_draw( FALSE );
    $dsep->set_expand( TRUE );
    $time_bar->insert( $dsep, -1 );

    $scan_apply_btn = Gtk2::ToolButton->new_from_stock( 'gtk-add' );
    $time_bar->insert( $scan_apply_btn, -1 );
    $scan_apply_btn->signal_connect( 'clicked' => \&apply_scan );

    $time_bar->insert( Gtk2::SeparatorToolItem->new, -1 );

    $scan_remove_btn = Gtk2::ToolButton->new_from_stock( 'gtk-remove' );
    $time_bar->insert( $scan_remove_btn, -1 );
    $scan_remove_btn->signal_connect(
        'clicked' => sub {
            remove( 'clamtk-scan' );
        }
    );

    ###############################
    # antivirus signature options #
    ###############################

    my $defs_frame = Gtk2::Frame->new( _( 'Antivirus signatures' ) );
    $vbox->pack_start( $defs_frame, FALSE, FALSE, 5 );

    my $defs_vbox = Gtk2::VBox->new;
    $defs_frame->add( $defs_vbox );

    $label
        = Gtk2::Label->new( _( 'Select a time to update your signatures' ) );
    $defs_vbox->pack_start( $label, FALSE, FALSE, 5 );

    my $defs_hbox = Gtk2::HBox->new;
    $defs_vbox->pack_start( $defs_hbox, FALSE, FALSE, 0 );

    $hour_spin_defs = Gtk2::SpinButton->new_with_range( 0, 23, 1 );
    $defs_hbox->pack_start( $hour_spin_defs, TRUE, TRUE, 5 );
    $hour_spin_defs->set_wrap( TRUE );
    $hour_spin_defs->set_tooltip_text(
        _( 'Set the hour using a 24 hour clock' ) );
    $label = Gtk2::Label->new( _( 'Hour' ) );
    $defs_hbox->pack_start( $label, FALSE, TRUE, 5 );

    $min_spin_defs = Gtk2::SpinButton->new_with_range( 0, 59, 1 );
    $min_spin_defs->set_wrap( TRUE );
    $defs_hbox->pack_start( $min_spin_defs, TRUE, TRUE, 5 );
    $label = Gtk2::Label->new( _( 'Minute' ) );
    $defs_hbox->pack_start( $label, FALSE, TRUE, 5 );

    my $defs_hbb = Gtk2::HButtonBox->new;
    $defs_vbox->pack_start( $defs_hbb, FALSE, FALSE, 0 );
    $defs_hbb->set_layout( 'end' );

    my $defs_bar = Gtk2::Toolbar->new;
    $defs_vbox->pack_start( $defs_bar, FALSE, FALSE, 0 );
    $defs_bar->set_style( 'icons' );

    $dsep = Gtk2::SeparatorToolItem->new;
    $dsep->set_draw( FALSE );
    $dsep->set_expand( TRUE );
    $defs_bar->insert( $dsep, -1 );

    my $can_update
        = ( ClamTk::Prefs->get_preference( 'Update' ) eq 'shared' )
        ? FALSE
        : TRUE;

    $defs_apply_btn = Gtk2::ToolButton->new_from_stock( 'gtk-add' );
    if ( $can_update ) {
        $defs_bar->insert( $defs_apply_btn, -1 );
        $defs_apply_btn->signal_connect( 'clicked' => \&apply_defs );
    }

    $defs_bar->insert( Gtk2::SeparatorToolItem->new, -1 );

    $defs_remove_btn = Gtk2::ToolButton->new_from_stock( 'gtk-remove' );
    $defs_bar->insert( $defs_remove_btn, -1 );
    $defs_remove_btn->signal_connect(
        'clicked' => sub {
            remove( 'clamtk-defs' );
        }
    );

    ##########
    # status #
    ##########

    my $status_frame = Gtk2::Frame->new( _( 'Status' ) );
    $vbox->pack_start( $status_frame, FALSE, FALSE, 5 );

    my $status_box = Gtk2::VBox->new( TRUE, 5 );
    $status_frame->add( $status_box );

    # By default, put the label in; helps with spacing and what not
    $scan_status_label = Gtk2::Label->new;
    $status_box->pack_start( $scan_status_label, FALSE, FALSE, 0 );
    $scan_status_label->set_text( _( 'A daily scan is scheduled' ) );

    $defs_status_label = Gtk2::Label->new;
    $status_box->pack_start( $defs_status_label, FALSE, FALSE, 0 );
    $defs_status_label->set_text(
        _( 'A daily definitions update is scheduled' ) );

    my $end_bar = Gtk2::Toolbar->new;
    $vbox->pack_start( $end_bar, FALSE, FALSE, 0 );
    $end_bar->set_style( 'both-horiz' );

    $dsep = Gtk2::SeparatorToolItem->new;
    $dsep->set_draw( FALSE );
    $dsep->set_expand( TRUE );
    $end_bar->insert( $dsep, -1 );

    my $btn = Gtk2::ToolButton->new_from_stock( 'gtk-close' );
    $btn->set_is_important( TRUE );
    $end_bar->insert( $btn, -1 );
    $btn->signal_connect( 'clicked' => sub { $dialog->destroy } );

    $dialog->show_all;

    is_enabled();
    Gtk2->main();
}

sub is_enabled {
    my ( $scan, $scan_hour, $scan_minute, $updates, $updates_hour,
        $updates_minute )
        = ( 0 ) x 6;
    my $excludes = 0;     # guess if user is ignoring whitelist or not
    my $target   = '';    # guess if scan involves Home or System

    open( my $L, '-|', $cmd, '-l' )
        or warn "problem checking crontab listing in is_enabled\n";

    while ( <$L> ) {
        Gtk2->main_iteration while ( Gtk2->events_pending );
        next if /^#/;
        next if /^\s*$/;
        chomp;
        my ( $min, $hour ) = split( /\s+/ );
        if ( /# clamtk-scan/ ) {
            $scan        = 1;
            $scan_hour   = $hour;
            $scan_minute = $min;
            $excludes++ while /--exclude/g;
            $target = 'home';
        } elsif ( /# clamtk-defs/ ) {
            $updates        = 1;
            $updates_hour   = $hour;
            $updates_minute = $min;
        }
    }
    close( $L );

    if ( $scan ) {
        $hour_spin_scan->set_value( $scan_hour );
        $min_spin_scan->set_value( $scan_minute );
        $scan_apply_btn->set_sensitive( FALSE );
        $scan_remove_btn->set_sensitive( TRUE );
        $scan_status_label->set_text( _( 'A daily scan is scheduled' ) );
    } else {
        $scan_apply_btn->set_sensitive( TRUE );
        $scan_remove_btn->set_sensitive( FALSE );
        $scan_status_label->set_text( _( 'A daily scan is not scheduled' ) );
    }

    if ( $updates ) {
        $hour_spin_defs->set_value( $updates_hour );
        $min_spin_defs->set_value( $updates_minute );
        $defs_apply_btn->set_sensitive( FALSE );
        $defs_remove_btn->set_sensitive( TRUE );
        $defs_status_label->set_text(
            _( 'A daily definitions update is scheduled' ) );
    } else {
        $defs_apply_btn->set_sensitive( TRUE );
        $defs_remove_btn->set_sensitive( FALSE );
        $defs_status_label->set_text(
            _( 'A daily definitions update is not scheduled' ) );
    }

    my $can_update
        = ( ClamTk::Prefs->get_preference( 'Update' ) eq 'shared' )
        ? FALSE
        : TRUE;
    if ( !$can_update ) {
        $defs_status_label->set_text(
            _( 'You are set to automatically receive updates' ) );
    }
    return;
}

sub apply_scan {
    my $hour = $hour_spin_scan->get_value;
    my $min  = $min_spin_scan->get_value;

    my $paths = ClamTk::App->get_path( 'all' );

    # This probably isn't necessary;
    # ensure old task is removed
    remove( '# clamtk-scan' );

    my $tmp_file = "$paths->{clamtk}" . "/" . "cron";
    open( my $T, '>', $tmp_file )
        or do {
        warn "Error opening temporary file in apply_scan: $!\n";
        return;
        };

    open( my $L, '-|', $cmd, '-l' )
        or do {
        warn "Error opening crontab command in apply_scan: $!\n";
        return;
        };

    while ( <$L> ) {
        Gtk2->main_iteration while ( Gtk2->events_pending );
        print $T $_;
    }
    close( $L );
    close( $T );

    my $full_cmd = $paths->{ clamscan };
    $full_cmd =~ s/(.*?clamscan)\s.*/$1/;

    # We don't scan the quarantine directory
    $full_cmd .= ' --exclude-dir=' . $paths->{ viruses };

    # Directories set as whitelisted in preferences
    for ( split /;/, ClamTk::Prefs->get_preference( 'Whitelist' ) ) {
        $full_cmd .= ' --exclude-dir=' . quotemeta( $_ );
    }

    # By default, we ignore .gvfs directories.
    for my $m ( 'smb4k', "/run/user/$ENV{USER}/gvfs", "$ENV{HOME}/.gvfs" ) {
        $full_cmd .= " --exclude-dir=$m";
    }

    # Ignore mail directories until we can parse stuff
    for my $not_parse (
        qw| .thunderbird        .mozilla-thunderbird
        .evolution      Mail    kmail |
        )
    {
        $full_cmd .= ' --exclude-dir=' . $not_parse;
    }

    # Use the appropriate signatures
    if ( ClamTk::Prefs->get_preference( 'Update' ) eq 'single' ) {
        $full_cmd .= " --database=$paths->{db}";
    }

    # Only report "infected" (-i)
    $full_cmd .= " -i ";

    # Does the user want PUA reporting?
    if ( ClamTk::Prefs->get_preference( 'Thorough' ) ) {
        $full_cmd .= " --detect-pua ";
    }

    # Home directory will be scanned
    $full_cmd .= "-r " . $paths->{ directory };

    # Add the (ugly) logging
    $full_cmd .= ' --log="$HOME/.clamtk/history/$(date +\%b-\%d-\%Y).log"'
        . ' 2>/dev/null';

    # Temporary file used for crontab
    open( $T, '>>', $tmp_file ) or do {
        warn "Error opening temporary file in apply_scan: $!\n";
        return;
    };
    print $T "$min $hour * * * $full_cmd # clamtk-scan\n";
    close( $T );

    # reload crontab
    system( $cmd, $tmp_file ) == 0
        or do {
        warn 'Error reloading cron file';
        unlink( $tmp_file )
            or warn "Unable to delete tmp_file $tmp_file: $!\n";
        return;
        };
    is_enabled();
    return;
}

sub apply_defs {
    my $hour = $hour_spin_defs->get_value;
    my $min  = $min_spin_defs->get_value;

    my $paths = ClamTk::App->get_path( 'all' );

    # this probably isn't necessary;
    # ensure old task is removed
    remove( '# clamtk-defs' );

    my $tmp_file = $paths->{ clamtk } . "/" . "cron";
    open( my $T, '>', $tmp_file )
        or do {
        warn "Error opening temporary file in apply_defs: $!\n";
        return;
        };

    open( my $L, '-|', $cmd, '-l' )
        or do {
        warn "Error opening crontab command in apply_defs: $!\n";
        return;
        };

    while ( <$L> ) {
        Gtk2->main_iteration while ( Gtk2->events_pending );
        print $T $_;
    }
    close( $L );
    close( $T );

    my $full_cmd = $paths->{ freshclam };

    if (ClamTk::Prefs->get_preference( 'Update' ) eq 'single'
        # The following is necessary if the user is not root, as
        # the update attempt will fail due to lack of permissions.
        # It's still not a good fix since the user might not realize it...
        # But with the ability to rerun the AV choice, it should work.
        || $> != 0
        )
    {
        $full_cmd
            .= " --datadir=$paths->{db} --log=$paths->{db}/freshclam.log";
    }

    # Add config file if user has configured a proxy
    if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) ) {
        if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 2 ) {
            if ( -e "$paths->{db}/local.conf" ) {
                $full_cmd .= " --config-file=$paths->{db}/local.conf";
            }
        }
    }

    open( $T, '>>', $tmp_file ) or do {
        warn "Error opening temporary file in apply_defs: $!";
        return;
    };

    print $T "$min $hour * * * $full_cmd # clamtk-defs\n";
    close( $T );

    # reload crontab

    system( $cmd, $tmp_file ) == 0
        or do {
        warn "Error reloading cron file: $!\n";
        };
    unlink( $tmp_file )
        or warn "Unable to delete tmp_file $tmp_file: $!\n";
    is_enabled();
    return;
}

sub remove {
    # $which = 'clamtk-scan' or 'clamtk-defs'
    my ( $which ) = shift;

    my $paths = ClamTk::App->get_path( 'clamtk' );

    my $tmp_file = "$paths/cron";
    open( my $T, '>', $tmp_file )
        or do {
        warn "Error opening temporary file in remove: $!\n";
        return;
        };
    open( my $L, '-|', $cmd, '-l' )
        or do {
        warn "Error opening crontab in remove: $!\n";
        return;
        };

    while ( <$L> ) {
        Gtk2->main_iteration while ( Gtk2->events_pending );
        print $T $_ unless ( /$which/ );
    }
    close( $L );

    # reload crontab
    system( $cmd, $tmp_file ) == 0
        or do {
        warn "Error reloading cron file in remove: $!\n";
        };
    unlink( $tmp_file )
        or warn "Unable to delete tmp_file $tmp_file: $!\n";

    if ( $which eq 'clamtk-scan' ) {
        $hour_spin_scan->set_value( '00' );
        $min_spin_scan->set_value( '00' );
    } elsif ( $which eq 'clamtk-defs' ) {
        $hour_spin_defs->set_value( '00' );
        $min_spin_defs->set_value( '00' );
    }
    is_enabled();
    return;
}

1;
