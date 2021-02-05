# ClamTk, copyright (C) 2004-2021 Dave M
#
# This file is part of ClamTk
# (https://gitlab.com/dave_m/clamtk-gtk3/).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the Free Software
# Foundation; either version 1, or (at your option) any later version, or
#
# b) the "Artistic License".
package ClamTk::Quarantine;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use POSIX 'locale_h';
use File::Basename 'basename', 'dirname';
use File::Copy 'move';
use Digest::SHA 'sha256_hex';
use Locale::gettext;
use Encode 'decode';

use constant ROW  => 0;
use constant FILE => 1;

my $liststore;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

sub show_window {
    my $box = Gtk3::Box->new( 'vertical', 5 );
    $box->set_homogeneous( FALSE );

    my $sw = Gtk3::ScrolledWindow->new( undef, undef );
    $sw->set_policy( 'automatic', 'automatic' );
    $sw->set_vexpand( TRUE );
    $box->pack_start( $sw, TRUE, TRUE, 5 );

    #<<<
    $liststore = Gtk3::ListStore->new(
            'Glib::Int',
            'Glib::String',
    );
    #>>>

    my $view = Gtk3::TreeView->new_with_model( $liststore );
    $view->set_rules_hint( TRUE );

    my $column = Gtk3::TreeViewColumn->new_with_attributes(
        _( 'Number' ),
        Gtk3::CellRendererText->new,
        text => ROW,
    );
    $column->set_sort_column_id( 0 );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $column->set_resizable( TRUE );
    $view->append_column( $column );

    $column = Gtk3::TreeViewColumn->new_with_attributes(
        _( 'File' ),
        Gtk3::CellRendererText->new,
        text => FILE,
    );
    $column->set_sort_column_id( 1 );
    $column->set_sizing( 'fixed' );
    $column->set_expand( TRUE );
    $column->set_resizable( TRUE );
    $view->append_column( $column );
    $sw->add( $view );

    my $viewbar = Gtk3::Toolbar->new;
    $box->pack_start( $viewbar, FALSE, FALSE, 5 );
    $viewbar->set_style( 'both-horiz' );

    my $button    = Gtk3::ToolButton->new();
    my $use_image = ClamTk::Icons->get_image( 'edit-undo' );
    $button->set_icon_name( $use_image );
    $button->set_label( _( 'Restore' ) );
    $viewbar->insert( $button, -1 );
    $button->set_is_important( TRUE );
    $button->signal_connect( clicked => \&restore, $view );

    my $v_sep = Gtk3::SeparatorToolItem->new;
    $v_sep->set_draw( FALSE );
    $v_sep->set_expand( TRUE );
    $viewbar->insert( $v_sep, -1 );

    $button    = Gtk3::ToolButton->new();
    $use_image = ClamTk::Icons->get_image( 'edit-delete' );
    $button->set_icon_name( $use_image );
    $button->set_label( _( 'Delete' ) );
    $viewbar->insert( $button, -1 );
    $button->set_is_important( TRUE );
    $button->signal_connect( clicked => \&delete, $view );

    push_viruses();

    $box->show_all;
    return $box;
}

sub delete {
    my ( $toolbutton, $treeview ) = @_;

    my $selected = $treeview->get_selection;
    my ( $model, $iter ) = $selected->get_selected;
    return unless $iter;

    my $row      = $model->get_value( $iter, ROW );
    my $viruses  = get_and_sort_viruses();
    my $file     = $viruses->{ $row }->{ basename };
    my $fullname = $viruses->{ $row }->{ fullname };

    # Get confirmation about deletion
    #<<<
    my $question = sprintf(
            _( 'Really delete this file (%s) ?' ),
            $file,
    );

    my $message
        = Gtk3::MessageDialog->new(
                undef,
                [ qw| modal destroy-with-parent | ],
                'question',
                'ok-cancel',
                $question,
    );
    #>>>

    if ( 'ok' eq $message->run ) {
        $message->destroy;
        unlink( $fullname ) or do {
            warn "Unable to delete >$fullname<: $!\n";
            return FALSE;
        };
        $model->clear;
        push_viruses();
        return TRUE;
    } else {
        $message->destroy;
        return FALSE;
    }
}

sub restore {
    my ( $toolbutton, $treeview ) = @_;

    my $selected = $treeview->get_selection;
    my ( $model, $iter ) = $selected->get_selected;
    return unless $iter;

    my $row      = $model->get_value( $iter, ROW );
    my $viruses  = get_and_sort_viruses();
    my $fullname = $viruses->{ $row }->{ fullname };
    my $basename = $viruses->{ $row }->{ basename };

    # Current location of quarantined file
    my $current_path = ClamTk::App->get_path( 'viruses' );
    $current_path .= '/';
    $current_path .= $basename;

    # By default, the final destination will be $HOME
    my $final_destination = ClamTk::App->get_path( 'directory' );
    $final_destination .= '/';
    $final_destination .= $basename;

    my $current_hash = get_hash( $current_path );

    # See if we have a record of this file
    my ( $hopeful_path, $hopeful_mode ) = query_hash( $current_hash );
    if ( $hopeful_path ) {
        $final_destination = decode( 'utf8', $hopeful_path );
    }

    # Save-as dialog
    my $dialog = Gtk3::FileChooserDialog->new(
        _( 'Save file as...' ),
        undef,
        'save',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok',
    );
    $dialog->set_current_name( $final_destination );
    $dialog->set_do_overwrite_confirmation( TRUE );

    if ( 'ok' eq $dialog->run ) {
        $dialog->destroy;
        # If we obtained permissions, apply them;
        # or, 644 by default. (?)
        # Unless someone has a better idea for default perms.
        $hopeful_mode ||= 644;
        chmod oct( $hopeful_mode ), $current_path;
        move( $current_path, $final_destination ) or do {
            warn "Unable to move >$current_path< to ",
                ">", $final_destination, "<\n";
            return FALSE;
        };
        if ( remove_hash( undef, $current_hash ) ) {
            $liststore->clear;
            push_viruses();
            return TRUE;
        } else {
            warn "error removing file >$fullname< from restore file: $!\n";
            $liststore->clear;
            push_viruses();
            return FALSE;
        }
    } else {
        $dialog->destroy;
        return FALSE;
    }
}

sub get_and_sort_viruses {
    # Where we hold the quarantined stuff
    my $path = ClamTk::App->get_path( 'viruses' );

    my $hash;
    my $i = 1;
    for my $virus ( glob "$path/*" ) {
        $hash->{ $i }->{ fullname } = decode( 'utf8', $virus );
        $hash->{ $i }->{ basename } = decode( 'utf8', basename( $virus ) );
        $hash->{ $i }->{ number }   = $i;
        $i++;
    }
    return $hash;
}

sub push_viruses {
    my $hash = shift;

    # If we weren't given a hash of info,
    # go and get it:
    if ( !$hash ) {
        $hash = get_and_sort_viruses();
    }

    #<<<
    for my $key ( sort { $a <=> $b } keys %$hash ) {
            my $iter = $liststore->append;
            $liststore->set(
                $iter,
                0, $hash->{ $key }->{ number },
                1, $hash->{ $key }->{ basename },
            );
    }
    #<<<
}

sub query_hash {
    # See if queried file exists in 'restore' file;
    # this might have to change to allow for querying
    # by hash or fullpath
    my $filehash = shift;

    my $restore_path = ClamTk::App->get_path( 'restore' );
    #open( my $F, '<:encoding(UTF-8)', $restore_path ) or do {
    open( my $F, '<', $restore_path ) or do {
        warn "Can't open restore file for reading: $!\n";
        return FALSE;
    };

    my $current_list;
    while ( <$F> ) {
        chomp;
        my ( $qhash, $qpath, $qmode ) = split /:/;
        $current_list->{ $qhash }->{ hash } = $qhash;
        $current_list->{ $qhash }->{ path } = $qpath;
        $current_list->{ $qhash }->{ mode } = $qmode;

        # See if it already exists in the restore file
        if ( $current_list->{ $qhash }->{ hash } eq $filehash ) {
            close( $F );
            return (
                $current_list->{ $qhash }->{ path },
                $current_list->{ $qhash }->{ mode }
            );
        }
    }
    close( $F );
    return FALSE;
}

sub add_hash {
    # Add quarantined file to 'restore' file
    my ( $pkg_name, $file, $permissions ) = @_;
    my $hash = get_hash( $file );

    my $restore_path = ClamTk::App->get_path( 'restore' );
    open( my $F, '<:encoding(UTF-8)', $restore_path ) or do {
        warn "Can't open restore file for reading: $!\n";
        return FALSE;
    };

    my $current_list;
    while ( <$F> ) {
        chomp;
        next if ( /^\s*$/ );
        my ( $qhash, $qpath, $qmode ) = split /:/;
        $current_list->{ $qhash }->{ hash } = $qhash;
        $current_list->{ $qhash }->{ path } = $qpath;
        $current_list->{ $qhash }->{ mode } = $qmode;

        # See if it already exists in the restore file
        if (   $current_list->{ $qhash }->{ hash } eq $hash
            || $current_list->{ $qhash }->{ path } eq $file )
        {
            return FALSE;
        }
    }
    close( $F );

    # Rewrite restore file with new addition
    open( $F, '>:encoding(UTF-8)', $restore_path ) or do {
    # open( $F, '>', $restore_path ) or do {
        warn "Can't open restore file for reading: $!\n";
        return FALSE;
    };

    for my $key ( keys %$current_list ) {
        print $F join( ':',
            $current_list->{ $key }->{ hash },
            $current_list->{ $key }->{ path },
            $current_list->{ $key }->{ mode },
        );
        print $F "\n";
    }
    print $F $hash, ':', $file, ':', $permissions, "\n";
    close( $F );

    return TRUE;
}

sub remove_hash {
    # Remove quarantined file from 'restore' file
    my ( $pkg_name, $hash ) = @_;

    my $restore_path = ClamTk::App->get_path( 'restore' );
    #open( my $F, '<:encoding(UTF-8)', $restore_path ) or do {
    open( my $F, '<', $restore_path ) or do {
        warn "Can't open restore file for reading: $!\n";
        return FALSE;
    };

    my $current_list;
    while ( <$F> ) {
        chomp;
        my ( $qhash, $qpath, $qmode ) = split /:/;
        $current_list->{ $qhash }->{ hash } = $qhash;
        $current_list->{ $qhash }->{ path } = $qpath;
        $current_list->{ $qhash }->{ mode } = $qmode;
    }
    close( $F );

    warn "no files listed in restore file!\n"
        and return FALSE
        unless scalar keys %$current_list;

    # Rewrite restore file
    #open( $F, '>:encoding(UTF-8)', $restore_path ) or do {
    open( $F, '>', $restore_path ) or do {
        warn "Can't open restore file for reading: $!\n";
        return FALSE;
    };

    # Next over the one we're removing
    for my $key ( keys %$current_list ) {
        next if ( $current_list->{ $key }->{ hash } eq $hash );
        print $F join( ':',
            $current_list->{ $key }->{ hash },
            $current_list->{ $key }->{ path },
            $current_list->{ $key }->{ mode },
        );
        print $F "\n";
    }
    close( $F );

    return TRUE;
}

sub get_hash {
    my $file = shift;

    my $slurp = do {
        local $/ = undef;
        open( my $f, '<', $file ) or do {
            warn "Unable to open >$file< for hashing: $!\n";
            return;
        };
        binmode( $f );
        <$f>;
    };
    return sha256_hex( $slurp );
}

1;
