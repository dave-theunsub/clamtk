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
my $dialog;
binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

sub show_window {
    my ( $pkg_name, $hash, $parent ) = @_;

    $dialog = Gtk3::Dialog->new( _( 'Results' ),
        $parent, [ qw| destroy-with-parent use-header-bar | ] );
    $dialog->set_size_request( 600, 300 );

    my $hb = Gtk3::HeaderBar->new;
    $hb->set_title( _( 'Results' ) );
    $hb->set_show_close_button( TRUE );
    $hb->set_decoration_layout( 'menu:close' );
    $hb->show();
    $dialog->set_titlebar( $hb );

    my $sbox = Gtk3::Box->new( 'vertical', 10 );
    $sbox->set_homogeneous( FALSE );
    # This scrolled window holds the slist
    my $sw = Gtk3::ScrolledWindow->new( undef, undef );
    $sw->set_vexpand( TRUE );
    $sw->set_shadow_type( 'etched_in' );
    $sw->set_policy( 'automatic', 'automatic' );
    $sbox->pack_start( $sw, TRUE, TRUE, 0 );
    $dialog->get_content_area->add( $sbox );

    use constant FILE         => 0;
    use constant STATUS       => 1;
    use constant ACTION_TAKEN => 2;

    #<<<
    $liststore = Gtk3::ListStore->new(
            # FILE
            'Glib::String',
            # STATUS
            'Glib::String',
            # ACTION_TAKEN
            'Glib::String',
    );

    my $tree = Gtk3::TreeView->new_with_model( $liststore );
    $tree->set_rules_hint( TRUE );
    $sw->add( $tree );

    my $renderer = Gtk3::CellRendererText->new;
    my $column
        = Gtk3::TreeViewColumn->new_with_attributes(
                _( 'File' ),
                $renderer,
                markup => FILE,
    );
    $column->set_sort_column_id( FILE );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $column->set_resizable( TRUE );
    $tree->append_column( $column );

    $column = Gtk3::TreeViewColumn->new_with_attributes(
                _( 'Status' ),
                $renderer,
                markup => STATUS,
    );
    $column->set_sort_column_id( STATUS );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $column->set_resizable( TRUE );
    $tree->append_column( $column );

    $column = Gtk3::TreeViewColumn->new_with_attributes(
            _( 'Action Taken' ),
            $renderer,
            markup => ACTION_TAKEN,
    );
    $column->set_sort_column_id( ACTION_TAKEN );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $column->set_resizable( TRUE );
    $tree->append_column( $column );

    my ($w, undef) = $dialog->get_size();
    for my $tvc ($tree->get_columns()) {
        $tvc->set_fixed_width($w / 3)
    }

    #<<<
    my $i = 0;
    while ( $i <= scalar keys %$hash ) {
        # print 'name = ', $hash->{ $i }->{ name }, "\n";
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

    my $hbox = Gtk3::Toolbar->new;
    $hbox->set_style( 'both-horiz' );
    $hbox->set_vexpand( FALSE );
    $sbox->pack_start( $hbox, FALSE, FALSE, 0 );

    my $theme     = Gtk3::IconTheme->new;
    my $use_image = ClamTk::Icons->get_image( 'system-lock-screen' );
    my $image     = Gtk3::Image->new_from_icon_name( $use_image, 'menu' );
    my $button    = Gtk3::ToolButton->new( $image, _( 'Quarantine' ) );
    $button->set_is_important( TRUE );
    $hbox->insert( $button, -1 );
    $button->signal_connect( clicked => \&action, $tree );

    $use_image = ClamTk::Icons->get_image( 'user-trash-full' );
    $image     = Gtk3::Image->new_from_icon_name( $use_image, 'menu' );
    $button    = Gtk3::ToolButton->new( $image, _( 'Delete' ) );
    $button->set_is_important( TRUE );
    $hbox->insert( $button, -1 );
    $button->signal_connect( clicked => \&action, $tree );

    # Testing to see if we can add Analysis button.
    # See ClamTk::Analysis->button_test for more
    if ( ClamTk::Analysis->button_test ) {
        my $use_image = ClamTk::Icons->get_image( 'edit-find' );
        $image  = Gtk3::Image->new_from_icon_name( $use_image, 'menu' );
        $button = Gtk3::ToolButton->new( $image, _( 'Analysis' ) );
        $button->set_is_important( TRUE );
        $hbox->insert( $button, -1 );
        $button->signal_connect( clicked => \&action, $tree );
    }

    my $sep = Gtk3::SeparatorToolItem->new;
    $sep->set_draw( FALSE );
    $sep->set_expand( TRUE );
    $hbox->insert( $sep, -1 );

    $use_image = ClamTk::Icons->get_image( 'window-close' );
    $image     = Gtk3::Image->new_from_icon_name( $use_image, 'menu' );
    $button    = Gtk3::ToolButton->new( $image, _( 'Close' ) );
    $button->signal_connect(
        clicked => sub {
            $dialog->destroy;
        }
    );
    $button->set_is_important( TRUE );
    $hbox->insert( $button, -1 );

    $sbox->show_all;
    $sbox->set_vexpand( TRUE );
    $dialog->run;
    $dialog->destroy;
}

sub action {
    my ( $button, $view ) = @_;

    my $selected = $view->get_selection;
    my ( $model, $iter ) = $selected->get_selected;
    return unless $iter;

    # These look like
    # first_col_value = >/home/foo/mime.cache<
    # second_col_value = >PUA.Win.Exploit.CVE_2012_0110<

    my $first_col_value  = $model->get_value( $iter, FILE );
    my $second_col_value = $model->get_value( $iter, STATUS );
    my $third_col_value  = $model->get_value( $iter, ACTION_TAKEN );

    # Don't mess with inboxes and empty values (!)
    my $maildirs = get_maildirs();
    if ( $first_col_value =~ /$maildirs/ || !-e $first_col_value ) {
        color_out( $model, $iter );
        return TRUE;
    }
    # Don't quarantine or delete PUAs outside of home directory
    if ( $second_col_value =~ /^PUA/ ) {
        if ( $first_col_value !~ m#^/home/# ) {
            color_out( $model, $iter );
            return TRUE;
        }
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
    } elsif ( $button->get_label eq _( 'Analysis' ) ) {
        ClamTk::Analysis->show_window( $first_col_value, $dialog );
        return TRUE;
    } else {
        warn 'Unable to ' . $button->get_label . " file >$first_col_value<\n";
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
            or warn "Unable to delete tmp file $paths/$basename\n: $!\n";
        return FALSE;
    };
}

sub delete_file {
    my $file     = shift;
    my $basename = basename( $file );

    # This is where threats go
    my $paths = ClamTk::App->get_path( 'viruses' );

    my $question
        = sprintf( _( 'Really delete this file (%s) ?' ), $basename );

    my $message
        = Gtk3::MessageDialog->new( undef,
        [ qw| modal destroy-with-parent | ],
        'question', 'ok-cancel', $question, );

    if ( 'ok' eq $message->run ) {
        $message->destroy;
    } else {
        $message->destroy;
        return FALSE;
    }
    unlink( $file ) or do {
        warn "Unable to delete >$file<: $!\n";
        return FALSE;
    };

    # If it's in the trash, remove its associated information file
    my $trash_info_path = ClamTk::App->get_path( 'trash_files_info' );
    my $trash_info_file = $trash_info_path . '/' . $basename . '.trashinfo';
    if ( $file =~ m#Trash# ) {
        if ( -e $trash_info_file ) {
            unlink( $trash_info_file )
                or warn "Unable to delete trashinfo file for $file: $!\n";
        }
    }
    return TRUE;
}

sub color_out {
    # We optionally take a value to set the third
    # column to (e.g., Quarantined, Deleted)
    my ( $store, $iter, $third_value_change ) = @_;
    if ( !$third_value_change ) {
        $third_value_change = ' - ';
    }

    my $first_col_value
        = "<span foreground = '#CCCCCC'>"
        . $store->get_value( $iter, FILE )
        . " </span>";
    my $second_col_value
        = "<span foreground='#CCCCCC'>"
        . $store->get_value( $iter, STATUS )
        . "</span > ";
    my $third_col_value = "<span foreground = '#CCCCCC'>"
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
    return join(
        '|',
        '.thunderbird', '.mozilla-thunderbird', 'evolution(?!/ tmp
            ) ',
        ' Mail ', ' kmail ', "\.pst"
    );
}

sub get_hash {
    my $file = shift;

    my $slurp = do {
        local $/ = undef;
        open( my $f, ' < ', $file ) or do {
            warn "Unable to open >$file<: $!\n";
            return;
        };
        binmode( $f );
        <$f>;
    };
    return sha256_hex( $slurp );
}

1;
