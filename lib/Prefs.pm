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
package ClamTk::Prefs;

# use strict;
# use warnings;
$| = 1;

use Digest::MD5 'md5_hex';
use File::Path 'mkpath';

use Locale::gettext;
use POSIX 'locale_h';

sub structure {
    my $paths = ClamTk::App->get_path( 'all' );

    # Ensure default paths/files exist.
    # If they do, ensure they have the proper permissions.
    # The default Fedora umask for users is 0002,
    # while Ubuntu's is 0022... sigh.
    # I'm going to assume that it's one or the other.
    # my $umask = sprintf("%04o", umask());
    my $mask = ( umask() == 2 ) ? '0775' : '0755';

    # This is /home/user/.clamtk/viruses,
    # used for the quarantine directory
    if ( !-d $paths->{ viruses } ) {
        eval { mkpath( $paths->{ viruses }, { mode => oct( $mask ) } ) };
        warn $@  if ( $@ );
        return 0 if ( $@ );
    } else {
        # Ensure the permissions are correct
        chmod oct( $mask ), $paths->{ viruses };
    }

    # This is /home/user/.clamtk/history,
    # which holds records of scans
    if ( !-d $paths->{ history } ) {
        eval { mkpath( $paths->{ history }, { mode => oct( $mask ) } ) };
        warn $@  if ( $@ );
        return 0 if ( $@ );
    } else {
        # Ensure the permissions are correct
        chmod oct( $mask ), $paths->{ history };
    }

    # The path /home/user/.clamtk/db stores signatures
    if ( !-d $paths->{ db } ) {
        eval { mkpath( $paths->{ db }, { mode => oct( $mask ) } ) };
        warn $@  if ( $@ );
        return 0 if ( $@ );
    } else {
        # Ensure the permissions are correct
        chmod oct( $mask ), $paths->{ db };
    }

    # This is /home/user/.clamtk/prefs,
    # a custom INI-style file.
    if ( !-e $paths->{ prefs } ) {
        # warn "note: (re)creating prefs file.\n";
        open( my $F, '>:encoding(UTF-8)', $paths->{ prefs } )
            or do {
            warn "Unable to create preferences! $!\n";
            return 0;
            };
        close( $F );
        eval { custom_prefs() };
        warn $@  if ( $@ );
        return 0 if ( $@ );
    }

    # This is /home/user/.clamtk/submit.
    # This was used for submitting to ClamAV;
    # we're reusing the directory structure
    if ( !-d $paths->{ submit } ) {
        eval { mkpath( $paths->{ submit }, { mode => oct( $mask ) } ) };
        warn $@  if $@;
        return 0 if ( $@ );
    } else {
        # Ensure the permissions are correct
        chmod oct( $mask ), $paths->{ submit };
    }

    # This is /home/user/.clamtk/submit/previous_submissions,
    # a csv file.
    if ( !-e $paths->{ previous_submissions } ) {
        open( my $F, '>:encoding(UTF-8)', $paths->{ previous_submissions } )
            or do {
            warn "Unable to create previous_submissions! $!\n";
            return 0;
            };
        close( $F );
    }

    # This is /home/user/.clamtk/submit/virustotal_links,
    # a csv file.
    if ( !-e $paths->{ virustotal_links } ) {
        open( my $F, '>:encoding(UTF-8)', $paths->{ virustotal_links } )
            or do {
            warn "Unable to create virustotal_links! $!\n";
            return 0;
            };
        close( $F );
    }

    # This is /home/user/.clamtk/restore, which holds
    # information for putting back false positives
    if ( !-e $paths->{ restore } ) {
        # warn "restore does not exist; re-creating it\n";
        open( my $F, '>:encoding(UTF-8)', $paths->{ restore } )
            or do {
            warn "Unable to create restore file! $!\n";
            return 0;
            };
        close( $F );
    }

    # Automatically set local freshclam.conf for individual updates
    set_local_config();

    return 1;
}

sub custom_prefs {
    # ensure prefs have normalized variables:
    my %pkg;
    # Get the user's current prefs
    my $paths = ClamTk::App->get_path( 'prefs' );

    open( my $F, '<:encoding(UTF-8)', $paths )
        or do {
        warn "Unable to read preferences! $!\n";
        return 0;
        };

    while ( <$F> ) {
        my ( $k, $v ) = split( /=/ );
        chomp( $v );
        $pkg{ $k } = $v;
    }
    close( $F );

    # If the preferences aren't already set,
    # use 'shared' by default. This makes it work out of the box.
    if ( !exists $pkg{ Update } ) {
        $pkg{ Update } = 'shared';
    } elsif ( $pkg{ Update } !~ /shared|single/ ) {
        # If it's set to 'shared' or 'single', leave it alone.
        # Otherwise, look for system signatures
        $pkg{ Update } = 'shared';
    }

    # The proxy is off by default
    if ( !exists $pkg{ HTTPProxy } ) {
        $pkg{ HTTPProxy } = 0;
    }

    # The whitelist is off by default
    if ( !exists $pkg{ Whitelist } ) {
        $pkg{ Whitelist } = '';
    }

    # Date of last infected file
    if ( !exists $pkg{ LastInfection } ) {
        $pkg{ LastInfection } = _( 'Never' );
    }

    # ScanHidden: Scan files beginning with a dot
    # SizeLimit: Scan files larger than 20MB
    # Thorough: Scan files for PUA
    # Recursive: Scan all files/directories within a directory
    # Mounted: Scan gvfs and related directories
    for my $o (
        qw{ScanHidden SizeLimit Heuristic
        Thorough Recursive Mounted}
        )
    {
        # off by default
        if ( !exists $pkg{ $o } ) {
            $pkg{ $o } = 0;
        }
    }

    # GUICheck: Check for GUI updates
    # TruncateLog: Shorten freshclam log
    # DupeDB: Delete duplicate signature dbs
    for my $p ( qw{GUICheck TruncateLog DupeDB } ) {
        # on by default
        if ( !exists $pkg{ $p } ) {
            $pkg{ $p } = 1;
        }
    }

    # dtformat - for date-time-format
    # if ( !exists $pkg{ 'dtformat' } ) {
    #     $pkg{ 'dtformat' } = '%m %d %Y';
    # }

    write_all( %pkg );
    return;
}

sub get_all_prefs {
    # Sometimes it's useful to have all
    # the preferences rather than just one.
    my %pkg;
    my $paths = ClamTk::App->get_path( 'prefs' );
    open( my $F, '<:encoding(UTF-8)', $paths )
        or do {
        warn "Unable to read preferences! $!\n";
        return 0;
        };

    while ( <$F> ) {
        my ( $k, $v ) = split( /=/ );
        chomp( $v );
        $pkg{ $k } = $v;
    }
    close( $F );
    return %pkg if %pkg;
}

sub legit_key {
    # Sanity check the prefs file's keys.
    my @keys = qw(
        SizeLimit HTTPProxy Heuristic
        LastInfection GUICheck DupeDB
        TruncateLog SaveToLog
        Whitelist Update ScanHidden
        Thorough Recursive Mounted
    );
    return 1 if ( grep { $_[ 0 ] eq $_ } @keys );
}

sub write_all {
    my %loc = @_;

    my $paths = ClamTk::App->get_path( 'prefs' );
    open( my $F, '>:encoding(UTF-8)', $paths )
        or do {
        warn "Unable to write preferences! $!\n";
        return 0;
        };

    while ( my ( $k, $v ) = each %loc ) {
        if ( legit_key( $k ) ) {
            print $F "$k=$v\n";
        }
    }
    close( $F );

    return 1;
}

sub set_preference {
    my ( undef, $wk, $wv ) = @_;    # undef = package name
    my $paths = ClamTk::App->get_path( 'prefs' );

    open( my $F, '<:encoding(UTF-8)', $paths )
        or do {
        warn "Unable to read preferences! $!\n";
        return 0;
        };

    my %pkg;
    while ( <$F> ) {
        my ( $k, $v ) = split( /=/ );
        chomp( $v );
        $pkg{ $k } = $v;
    }
    close( $F );

    open( $F, '>:encoding(UTF-8)', $paths )
        or return -1;

    while ( my ( $k, $v ) = each %pkg ) {
        if ( legit_key( $k ) && ( $k ne $wk ) ) {
            print $F "$k=$v\n";
        }
    }
    print $F "$wk=$wv\n" if ( legit_key( $wk ) );
    close( $F )
        or warn "Couldn't close $paths: $!\n";
    return 1;
}

sub get_preference {
    my ( undef, $wanted ) = @_;    # undef = package name

    my $paths = ClamTk::App->get_path( 'prefs' );
    my %pkg;
    open( my $F, '<:encoding(UTF-8)', $paths )
        or do {
        warn "Unable to read preferences! $!\n";
        return 0;
        };

    while ( <$F> ) {
        my ( $k, $v ) = split( /=/ );
        chomp( $v );
        $pkg{ $k } = $v;
    }
    close( $F );

    return unless %pkg;
    return $pkg{ $wanted } || '';
}

sub set_proxy {
    my ( undef, $ip, $port ) = @_;    # undef = package name

    # If the user doesn't set a port, we'll just jot down port 80.
    $port = $port || '80';

    my $path = ClamTk::App->get_path( 'localfreshclamconf' );
    warn "Prefs set_proxy: path = >$path<\n";

    # This gets clobbered every time.
    open( my $FH, '>:encoding(UTF-8)', $path )
        or return -1;
    print $FH <<"EOF";
HTTPProxyServer $ip
HTTPProxyPort $port
DatabaseMirror db.local.clamav.net
DatabaseMirror database.clamav.net
EOF
    close( $FH )
        or warn "Couldn't close $path/local.conf: $!\n";
    return 1;
}

sub set_local_config {
    my $path = ClamTk::App->get_path( 'localfreshclamconf' );
    return if ( -e $path );

    # This gets clobbered every time.
    open( my $FH, '>:encoding(UTF-8)', $path )
        or return -1;
    print $FH <<"EOF";
# Local config
DatabaseMirror database.clamav.net
LogSyslog no
EOF
    close( $FH )
        or warn "Couldn't close $path: $!\n";
    if ( !-e $path ) {
        warn "Couldn't create local freshclam ($path)!\n"
            . "You will be unable to do manual updates.\n";
    }
    return 1;
}

1;
