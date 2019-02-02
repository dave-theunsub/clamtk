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
package ClamTk::Startup;

use Glib 'FALSE';

use Time::Piece;

# use strict;
# use warnings;
$| = 1;

sub startup_check {
    my ( $sigs_outdated, $gui_outdated );

    # If the user wants a GUI update check on startup:
    if ( ClamTk::Prefs->get_preference( 'GUICheck' ) ) {
        if ( check_gui() ) {
            $gui_outdated++;
        }
    }

    # Check AV date - 4 days and sound the alarm
    my $t        = localtime;
    my $today    = $t->dmy( " " );
    my $sig_date = check_sigs();

    my $date_format = '%d %m %Y';
    $today    = Time::Piece->strptime( $today,    '%d %m %Y' );
    $sig_date = Time::Piece->strptime( $sig_date, '%Y %m %d' );

    my $diff = $today - $sig_date;
    if ( int( $diff->days ) >= 4 ) {
        $sigs_outdated++;
    }

    if ( $sigs_outdated && $gui_outdated ) {
        return 'both';
    } elsif ( $sigs_outdated ) {
        return 'sigs';
    } elsif ( $gui_outdated ) {
        return 'gui';
    } else {
        return 0;
    }
}

sub check_sigs {
    my $av_date = ClamTk::App->get_sigtool_info( 'date' );
    return $av_date;
}

sub check_gui {
    my $local_tk_version  = ClamTk::App->get_TK_version();
    my $remote_tk_version = ClamTk::Update->get_remote_TK_version();

    my ( $local_chopped, $remote_chopped );
    ( $local_chopped  = $local_tk_version ) =~ s/[^0-9]//;
    ( $remote_chopped = $remote_tk_version ) =~ s/[^0-9]//;

    # Sanity check to ensure we received an answer
    if ( $local_chopped && $remote_chopped ) {
        return 1 if ( $remote_chopped > $local_chopped );
    }
    return 0;
}

1;
