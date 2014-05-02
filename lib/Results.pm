# ClamTk, copyright (C) 2004-2014 Dave M
#
# This file is part of ClamTk (http://code.google.com/p/clamtk/).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".
package ClamTk::Results;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use POSIX 'locale_h';
use File::Basename 'basename';
use Locale::gettext;
use File::Copy 'move';
use Digest::SHA 'sha256_hex';
use Encode 'decode';

my $liststore;
binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

sub show_window {
    my ( $pkg_name, $hash ) = @_;

    my $window = Gtk2::Window->new;
    $window->signal_connect( destroy => sub { $window->destroy } );
    $window->set_title( _( 'Results' ) );
    $window->set_border_width( 5 );
    $window->set_default_size( 650, 250 );
    $window->set_position( 'mouse' );

    my $box = Gtk2::VBox->new( FALSE, 5 );
    $window->add( $box );

    # This scrolled window holds the slist
    my $sw = Gtk2::ScrolledWindow->new;
    $box->pack_start( $sw, TRUE, TRUE, 0 );
    $sw->set_shadow_type( 'etched_in' );
    $sw->set_policy( 'never', 'automatic' );

    use constant FILE         => 0;
    use constant STATUS       => 1;
    use constant ACTION_TAKEN => 2;

    #<<<
    $liststore = Gtk2::ListStore->new(
            # FILE
            'Glib::String',
            # STATUS
            'Glib::String',
            # ACTION_TAKEN
            'Glib::String',
    );

    my $tree = Gtk2::TreeView->new_with_model( $liststore );
    $tree->set_rules_hint( TRUE );
    $sw->add( $tree );

    my $renderer = Gtk2::CellRendererText->new;
    my $column
        = Gtk2::TreeViewColumn->new_with_attributes(
                _( 'File' ),
                $renderer,
                markup => FILE,
    );
    $column->set_expand( TRUE );
    $column->set_sort_column_id( FILE );
    $column->set_resizable( TRUE );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $tree->append_column( $column );

    $column = Gtk2::TreeViewColumn->new_with_attributes(
                _( 'Status' ),
                $renderer,
                markup => STATUS,
    );
    $column->set_expand( TRUE );
    $column->set_sort_column_id( STATUS );
    $column->set_resizable( TRUE );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $tree->append_column( $column );

    $column = Gtk2::TreeViewColumn->new_with_attributes(
            _( 'Action Taken' ),
            $renderer,
            markup => ACTION_TAKEN,
    );
    $column->set_expand( TRUE );
    $column->set_sort_column_id( ACTION_TAKEN );
    $column->set_resizable( TRUE );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $tree->append_column( $column );

    #<<<
    my $i = 0;
    while ( $i <= scalar keys %$hash ) {
        #print 'name = ', $hash->{ $i }->{ name }, "\n";
        my $iter = $liststore->append;
        $liststore->set(
                $iter,
                0, decode( 'utf8', $hash->{ $i }->{ name }),
                1, $hash->{ $i }->{ status },
                2, $hash->{ $i }->{ action },
        );
        $i++;
        last if ( $i >= scalar keys %$hash );
    }
    #>>>

    my $hbox = Gtk2::Toolbar->new;
    $hbox->set_style( 'both-horiz' );
    $box->pack_start( $hbox, FALSE, FALSE, 5 );

    my $image = Gtk2::Image->new_from_stock( 'gtk-refresh', 'menu' );
    my $button = Gtk2::ToolButton->new( $image, _( 'Quarantine' ) );
    $button->set_is_important( TRUE );
    $hbox->insert( $button, -1 );
    $button->signal_connect( clicked => \&action, $tree );

    $image = Gtk2::Image->new_from_stock( 'gtk-delete', 'menu' );
    $button = Gtk2::ToolButton->new( $image, _( 'Delete' ) );
    $button->set_is_important( TRUE );
    $hbox->insert( $button, -1 );
    $button->signal_connect( clicked => \&action, $tree );

    my $sep = Gtk2::SeparatorToolItem->new;
    $sep->set_draw( FALSE );
    $sep->set_expand( TRUE );
    $hbox->insert( $sep, -1 );

    $image = Gtk2::Image->new_from_stock( 'gtk-close', 'menu' );
    $button = Gtk2::ToolButton->new( $image, _( 'Close' ) );
    $button->signal_connect(
        clicked => sub {
            $window->destroy;
            Gtk2->main_quit;
        }
    );
    $button->set_is_important( TRUE );
    $hbox->insert( $button, -1 );

    $window->show_all;
    Gtk2->main;
}

sub action {
    my ( $button, $view ) = @_;

    my $selected = $view->get_selection;
    my ( $model, $iter ) = $selected->get_selected;
    return unless $iter;

    # my $path = $model->get_path( $iter );
    my $first_col_value  = $model->get_value( $iter, FILE );
    my $second_col_value = $model->get_value( $iter, STATUS );
    my $third_col_value  = $model->get_value( $iter, ACTION_TAKEN );

    my $maildirs = get_maildirs();
    my $value = $model->get_value( $iter, FILE );
    if ( $value =~ /$maildirs/ || !-e $value ) {
        color_out( $model, $iter );
        return TRUE;
    }

    # Return 1 or TRUE for successfully deleting
    # or quarantining so we can "color_out" that row
    # and change its status column
    if ( $button->get_label eq _( 'Quarantine' ) ) {
        my $ret = quarantine( $first_col_value );
        if ( $ret ) {
            color_out( $model, $iter, _( 'Quarantined' ) );
            return TRUE;
        } else {
            return FALSE;
        }
    } elsif ( $button->get_label eq _( 'Delete' ) ) {
        my $ret = delete_file( $first_col_value );
        if ( $ret ) {
            color_out( $model, $iter, _( 'Deleted' ) );
            return TRUE;
        }
        return FALSE;
    } else {
        warn 'unable to ' . $button->get_label . " file >$first_col_value<\n";
    }

    return TRUE;
}

sub quarantine {
    my ( $file ) = shift;
    my $basename = basename( $file );

    # This is where threats go
    my $paths = ClamTk::App->get_path( 'viruses' );

    if ( !-e $paths or !-d $paths ) {
        warn "Unable to quarantine >$file<; no quarantine directory\n";
        return FALSE;
    }

    # Get permissions
    my $mode = ( stat( $file ) )[ 2 ];
    my $perm = sprintf( "%03o", $mode & oct( 7777 ) );

    # Update restore file by adding file, path and md5
    ClamTk::Quarantine->add_hash( $file, $perm );

    # Assign 600 permissions
    chmod oct( 600 ), $file;
    move( $file, "$paths/$basename" ) or do {
        # When a 'mv' fails, it still probably did a 'cp'...
        # 'mv' copies the file first, then unlinks the source.
        # d'oh... so just to make sure, unlink the intended target
        # and THEN return.
        unlink( "$paths/$basename" )
            or warn "unable to delete tmp file $paths/$basename\n: $!\n";
        return FALSE;
    };
}

sub delete_file {
    my ( $file ) = shift;

    # This is where threats go
    my $paths = ClamTk::App->get_path( 'viruses' );

    #<<<
    my $question = sprintf(
            _( 'Really delete this file (%s) ?' ),
            basename( $file ),
    );

    my $message
        = Gtk2::MessageDialog->new(
                undef,
                [ qw(modal destroy-with-parent) ],
                'question',
                'ok-cancel',
                $question,
    );
    #>>>

    if ( 'ok' eq $message->run ) {
        $message->destroy;
    } else {
        $message->destroy;
        return FALSE;
    }
    unlink( $file ) or do {
        warn "unable to delete >$file<: $!\n";
        return FALSE;
    };
    return TRUE;
}

sub color_out {
    # We optionally take a value to set the third
    # column to (e.g., Quarantined, Deleted)
    my ( $store, $iter, $third_value_change ) = @_;

    my $first_col_value
        = "<span foreground='#CCCCCC'>"
        . $store->get_value( $iter, FILE )
        . "</span>";
    my $second_col_value
        = "<span foreground='#CCCCCC'>"
        . $store->get_value( $iter, STATUS )
        . "</span>";
    my $third_col_value = "<span foreground='#CCCCCC'>"
        #. $store->get_value( $iter, ACTION_TAKEN )
        . $third_value_change . "</span>";
    #<<<
    $store->set(
        $iter,
        0, $first_col_value,
        1, $second_col_value,
        2, $third_col_value,
    );
    #>>>
}

sub get_maildirs {
    return join( '|',
        '.thunderbird', '.mozilla-thunderbird', 'evolution(?!/tmp)',
        'Mail',         'kmail',                "\.pst" );
}

sub get_hash {
    my $file = shift;

    my $slurp = do {
        local $/ = undef;
        open( my $f, '<', $file ) or do {
            warn "unable to open >$file<: $!\n";
            return;
        };
        binmode( $f );
        <$f>;
    };
    return sha256_hex( $slurp );
}

1;
