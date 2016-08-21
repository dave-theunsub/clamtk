# ClamTk, copyright (C) 2004-2016 Dave M
#
# This file is part of ClamTk (https://github.com/dave-theunsub/clamtk/wiki).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".
package ClamTk::App;

# use strict;
# use warnings;
$| = 1;

use Time::Piece;
use File::Basename 'basename';

use POSIX 'locale_h';
use Locale::gettext;
use Encode 'decode';

sub get_TK_version {
    # Stick with %.2f format - 4.50 vice 4.5
    return '5.21';
}

sub get_path {
    my ( undef, $wanted ) = @_;
    my $path;

    # These are directories and files necessary for
    # preferences, storing AV signatures, and more

    # Images directory:
    # This is a "global" setting which may need
    # to be changed depending on distro, so it's first
    $path->{ images } = '/usr/share/pixmaps/';

    # Now, determine home directory
    $path->{ directory } = $ENV{ HOME } || ( ( getpwuid $< )[ -2 ] );

    # Default personal clamtk directory
    $path->{ clamtk } = $path->{ directory } . '/.clamtk';

    # Trash directory - main
    $path->{ trash_dir } = $path->{ directory } . '/.local/share/Trash';

    # Trash directory - where files are held
    $path->{ trash_dir_files } = $path->{ trash_dir } . '/files';

    # Trash directory - where associated files are held:
    # e.g. trash.jpg.trashinfo
    $path->{ trash_files_info } = $path->{ trash_dir } . '/info';

    # For storing quarantined files
    $path->{ viruses } = $path->{ clamtk } . '/viruses';

    # Store history logs here
    $path->{ history } = $path->{ clamtk } . '/history';

    # Plain text file for preferences
    $path->{ prefs } = $path->{ clamtk } . '/prefs';

    # Plain text file for restoring quarantined files
    $path->{ restore } = $path->{ clamtk } . '/restore';

    # The db directory stores virus defs/freshclam-related stuff
    $path->{ db } = $path->{ clamtk } . '/db';

    # The submit directory stores file submission information
    $path->{ submit } = $path->{ clamtk } . '/submit';

    # Keeps track of previous VT submissions
    $path->{ previous_submissions }
        = $path->{ submit } . '/previous_submissions';

    # Keeps track of previous VT submissions
    $path->{ virustotal_links } = $path->{ submit } . '/virustotal_links';

    # Default variables
    $path->{ whitelist_dir }
        = join( ';', $path->{ viruses }, '/sys', '/dev', '/proc;' );

    # Most times freshclam is under /usr/bin
    $path->{ freshclam }
        = ( -e '/usr/bin/freshclam' ) ? '/usr/bin/freshclam'
        : ( -e '/usr/local/bin/freshclam' ) ? '/usr/local/bin/freshclam'
        : ( -e '/opt/local/bin/freshclam' ) ? '/opt/local/bin/freshclam'
        :                                     '';

    # Use sigtool for db info
    $path->{ sigtool }
        = ( -e '/usr/bin/sigtool' ) ? '/usr/bin/sigtool'
        : ( -e '/usr/local/bin/sigtool' ) ? '/usr/local/bin/sigtool'
        : ( -e '/opt/local/bin/sigtool' ) ? '/opt/local/bin/sigtool'
        :                                   '';

    # Most times clamscan is under /usr/bin
    # We'll use clampath as the actual path
    # and clamscan as clampath + scan options
    $path->{ clampath }
        = ( -e '/usr/bin/clamscan' ) ? '/usr/bin/clamscan'
        : ( -e '/usr/local/bin/clamscan' ) ? '/usr/local/bin/clamscan'
        : ( -e '/opt/local/bin/clamscan' ) ? '/opt/local/bin/clamscan'
        :                                    '';

    $path->{ clamscan } = $path->{ clampath };

    # The default ClamAV options:
    # leave out the summary and warn on encrypted
    $path->{ clamscan } .= ' --no-summary --block-encrypted ';

    return ( $wanted eq 'all' ) ? $path : $path->{ $wanted };
}

sub get_daily_sigs_path {
    # Returns path_of_daily.c?d
    # There are (or have been) 3 formats:
    # 1. The .cld files
    # 2. The .cvd files
    # 3. The {daily,main}.info directories
    # As of 4.23, we're no longer looking for the .info dirs.
    # The .cvd is the compressed database, while .cld is a
    # previous .cvd/.cld with incremental updates.
    # The problem is that you can end up with both a
    # daily.cvd AND a daily.cld, and it's a crapshoot as to
    # which one will show the most current date.  So we'll return
    # just the directory path, compare dates, and return
    # the most current date.

    # Path to the daily.c{l,v}d file(s)
    my $DAILY_PATH;

    # These are the typical directories where the sigs are found.
    # Because CentOS is a little screwy, it will often contain two
    # directories of definitions... The newer one is likely in
    # /var/clamav, so check that first.  Other distros will
    # likely find the defs under /var/lib/clamav.
    my @dirs = qw(
        /var/clamav
        /var/lib/clamav
        /opt/local/share/clamav
        /usr/share/clamav
        /usr/local/share/clamav
        /var/db/clamav
    );

    # If the user selected "manual", that directory needs
    # to be checked first, so we'll jam that in with unshift.
    my $user_set      = 0;
    my $update_method = ClamTk::Prefs->get_preference( 'Update' );
    if ( $update_method eq 'single' ) {
        $user_set = 1;
        my $paths = ClamTk::App->get_path( 'db' );
        unshift( @dirs, $paths );
    }

    # We'll search for the daily file then main;
    # Check for daily's .cld before .cvd,
    # but main's .cvd before .cld
    my $dupe_db = ClamTk::Prefs->get_preference( 'DupeDB' );
    for my $dir_list ( @dirs ) {
        # Check for duplicate daily databases
        if ( -e "$dir_list/daily.cld" && -e "$dir_list/daily.cvd" ) {
            only_one( "$dir_list" )
                if ( ( $dupe_db && $update_method eq 'single' )
                or ( $dupe_db && $> == 0 ) );
        }

        if ( -e "$dir_list/daily.cld" ) {
            $DAILY_PATH = "$dir_list/daily.cld";
        } elsif ( -e "$dir_list/daily.cvd" ) {
            $DAILY_PATH = "$dir_list/daily.cvd";
        }

        last if ( $DAILY_PATH );

        # the user may have set single - may need to update db
        last if ( $user_set );
    }

    return $DAILY_PATH;
}

sub get_main_sigs_path {
    # Path to the main.c{l,v}d file(s)
    my $MAIN_PATH;

    # If the user selected "manual", that directory needs
    # to be checked first, so we'll jam that in with unshift.
    my $update_method = ClamTk::Prefs->get_preference( 'Update' );
    my $user_set      = 0;

    my @dirs = qw(
        /var/clamav
        /var/lib/clamav
        /opt/local/share/clamav
        /usr/share/clamav
        /usr/local/share/clamav
        /var/db/clamav
    );
    # Check for duplicate main databases
    my $dupe_db = ClamTk::Prefs->get_preference( 'DupeDB' );
    for my $dir_list ( @dirs ) {
        # Check for duplicate daily databases
        if ( -e "$dir_list/main.cld" && "$dir_list/main.cvd" ) {
            unlink( "$dir_list/main.cld" )
                if ( ( $dupe_db && $update_method eq 'single' )
                or ( $dupe_db && $> == 0 ) );
        }

        if ( -e "$dir_list/main.cvd" ) {
            $MAIN_PATH = "$dir_list/main.cvd";
        } elsif ( -e "$dir_list/main.cld" ) {
            $MAIN_PATH = "$dir_list/main.cld";
        }
        last if ( $MAIN_PATH );

        # the user may have set single - may need to update db
        last if ( $user_set );
    }

    return $MAIN_PATH;
}

sub get_local_sig_version {
    my $daily = get_daily_sigs_path();

    my $sigtool = get_path( undef, 'sigtool' );
    my $version = 0;

    if ( -e $daily ) {
        if ( open( my $CLD, '-|', "$sigtool -i $daily" ) ) {
            while ( <$CLD> ) {
                if ( /Version: (\d+)/ ) {
                    $version = $1;
                }
            }
        }
    }

    return ( $version =~ /\d+/ ) ? $version : _( 'Unknown' );
}

sub only_one {
    my ( $location ) = shift;
    my $basename = basename( $location );

    my ( $cld, $cvd ) = ( '01 Jan 1900' ) x 2;
    my $sigtool = get_path( undef, 'sigtool' );

    if ( open( my $CLD, '-|', "$sigtool -i $location/daily.cld" ) ) {
        while ( <$CLD> ) {
            if ( /Build time: (\d+\s\w+\s\d{4})/ ) {
                $cld = $1;
                last;
            }
        }
    } else {
        # shouldn't happen
        $cld = '01 01 1970';
    }

    if ( open( my $CVD, '-|', "$sigtool -i $location/daily.cvd" ) ) {
        while ( <$CVD> ) {
            if ( /Build time: (\d+\s\w+\s\d{4})/ ) {
                $cvd = $1;
                last;
            }
        }
    } else {
        # shouldn't happen
        $cvd = '01 01 1970';
    }

    my $cmp = comp_dates( $cld, $cvd );
    # If cmp == -1, cvd is newer.
    # If cmp ==  1, cld is newer.
    # If cmp ==  0, they're the same.
    if ( $cmp == -1 ) {
        unlink( "$location/daily.cld" )
            or warn "Cannot delete $location/daily.cld: $!\n";
    } elsif ( $cmp == 1 ) {
        unlink( "$location/daily.cvd" )
            or warn "Cannot delete $location/daily.cvd: $!\n";
    } elsif ( $cmp == 0 ) {
        unlink( "$location/daily.cvd" )
            or warn "Cannot delete $location/daily.cvd: $!\n";
    }
    return;
}

sub get_AV_version {
    # simple 'clamscan -V'.
    # We have to parse something like this:
    # ClamAV 0.95.3/11220/Fri Jun 18 22:06:39 2010
    # Worth keeping an eye on since it's changed in
    # past without me noticing...
    local $ENV{ 'PATH' } = '/bin:/usr/bin:/usr/local/bin';
    delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
    my $paths   = ClamTk::App->get_path( 'clampath' );
    my $version = '';

    if ( open( my $c, '-|', $paths, '-V' ) ) {
        while ( <$c> ) {
            chomp;
            $version = $_;
        }
    }

    $version =~ s/^\S+\s+([0-9\.]+).*/$1/;
    return $version ? $version : '0.00';
}

sub get_sigtool_info {
    # Should get requests for:
    # count: add up daily/main sigs
    # version: version count found in sigs
    # date: show build time of sigs
    my ( undef, $wanted ) = @_;
    my $regex = '';
    if ( $wanted eq 'date' ) {
        # Build time: 16 Aug 2013
        $regex = qr|Build time:\s(\d+\s\w+\s\d{4})|;
    } elsif ( $wanted eq 'version' ) {
        # Version: 17694
        $regex = qr|Version:\s(\d+)|;
    } elsif ( $wanted eq 'count' ) {
        # Signatures: 1614500
        $regex = qr|Signatures: (\d+)|;
    }

    my $result = '';
    my $sigtool = get_path( undef, 'sigtool' );

    my $daily_path = get_daily_sigs_path();
    my $main_path  = get_main_sigs_path();

    my $found_wanted = 0;
    if ( -e $daily_path ) {
        if ( open( my $cld_db, '-|', "$sigtool -i $daily_path" ) ) {
            while ( <$cld_db> ) {
                if ( /$regex/ ) {
                    chomp;
                    $result = $1;
                }
            }
        }
    }

    if ( $wanted eq 'count' ) {
        if ( -e $main_path ) {
            if ( open( my $main_db, '-|', "$sigtool -i $main_path" ) ) {
                while ( <$main_db> ) {
                    if ( /$regex/ ) {
                        chomp;
                        $result += $1;
                    }
                }
            }
        }
    }

    # If the date is wanted, we have to tweak the results
    # first. Instead of getting translations for each 3 letter
    # month abbreviation, it's easier to change it to digits
    # and display it as $YEAR $MONTH $DAY (2013 08 01).
    if ( $wanted eq 'date' && $result ) {
        my ( $day, $month, $year ) = split( / /, $result );
        my %months = (
            'Jan' => '01',
            'Feb' => '02',
            'Mar' => '03',
            'Apr' => '04',
            'May' => '05',
            'Jun' => '06',
            'Jul' => '07',
            'Aug' => '08',
            'Sep' => '09',
            'Oct' => 10,
            'Nov' => 11,
            'Dec' => 12,
        );
        $result = join( ' ', $year, $months{ $month }, $day );
    }

    return $result;
}

sub lastscan {
    my $path = ClamTk::App->get_path( 'history' );
    my @logs = glob "$path/*.log";
    return _( 'Never' ) if ( !@logs );
    my %orcs;

    my @newer
        = sort { ( $orcs{ $a } ||= -M $a ) <=> ( $orcs{ $b } ||= -M $b ) }
        @logs;

    # The newest "file" (actually a string/scalar)
    # is a path like /home/foo/.clamtk/histories/01-01-Jan.log.
    # We just want the basename of that.
    my $chosen = basename( $newer[ 0 ] );

    my ( $month, $day, $year ) = split( /-/, $chosen );
    $year =~ s/(\d+)\.log/$1/;

    return "$day $month $year";
}

sub comp_dates {
    my ( $cld, $cvd ) = @_;
    my %months = (
        'Jan' => 1,
        'Feb' => 2,
        'Mar' => 3,
        'Apr' => 4,
        'May' => 5,
        'Jun' => 6,
        'Jul' => 7,
        'Aug' => 8,
        'Sep' => 9,
        'Oct' => 10,
        'Nov' => 11,
        'Dec' => 12,
    );

    my ( $cld_day, $cld_mon, $cld_year ) = split( /\s/, $cld );
    my ( $cvd_day, $cvd_mon, $cvd_year ) = split( /\s/, $cvd );

    my $cld_zone = $cld_day . ' ' . $months{ $cld_mon } . ' ' . $cld_year;
    my $cvd_zone = $cvd_day . ' ' . $months{ $cvd_mon } . ' ' . $cld_year;

    my $date_format = '%d %m %Y';

    $cld_zone = Time::Piece->strptime( $cld_zone, $date_format );
    $cvd_zone = Time::Piece->strptime( $cvd_zone, $date_format );

    my $cmp = ( $cld_zone ) <=> ( $cvd_zone );

    # If cmp == -1, cvd is newer.
    # If cmp ==  1, cld is newer.
    # If cmp ==  0, they're the same.

    return $cmp;
}

sub translate {
    # This is a dummy routine, solely for the .desktop file
    # and other spots...
    my $a = _( 'Scan for threats...' );
    $a = _( 'Advanced' );
    $a = _( 'Scan a file' );
    $a = _( 'Scan a directory' );

    return $a;
}

sub _ {
    # stupid gettext wrapper
    return decode( 'utf8', gettext( $_[ 0 ] ) );
}

1;
