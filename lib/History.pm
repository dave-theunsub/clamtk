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
package ClamTk::History;

# use strict;
# use warnings;

use File::Basename 'basename';
use Locale::gettext;
use Encode 'decode';
use Gtk2::Gdk::Keysyms;

use Glib 'TRUE', 'FALSE';

sub show_window {
    my $box = Gtk2::VBox->new( FALSE, 5 );

    my $sort = 0;    # 0 = asc, 1 = desc

    my $swin = Gtk2::ScrolledWindow->new( undef, undef );
    $swin->set_policy( 'never', 'automatic' );
    $box->pack_start( $swin, TRUE, TRUE, 0 );

    my $store = create_model();

    my $view = Gtk2::TreeView->new_with_model( $store );
    $view->set_rules_hint( TRUE );
    my $column = Gtk2::TreeViewColumn->new_with_attributes(
        _( 'History' ),
        Gtk2::CellRendererText->new,
        text => 0,
    );
    $column->set_sort_column_id( 0 );
    $view->append_column( $column );
    $swin->add( $view );

    # Add delete signals
    $box->signal_connect(
        key_press_event => sub {
            my ( $widget, $event ) = @_;
            if ( $event->keyval == $Gtk2::Gdk::Keysyms{ Delete } ) {
                del_history( undef, $view );
            }
            return TRUE;
        }
    );

    # "Select" a row to make keyboard use easier
    my $first_iter = $store->get_iter_first;
    # Make sure they *have* a history
    if ( $first_iter ) {
        if ( $store->iter_is_valid( $first_iter ) ) {
            my $viewpath = $store->get_path( $store->get_iter_first );
            $view->set_cursor( $viewpath ) if ( $viewpath );
        }
    }

    $box->pack_start( Gtk2::VSeparator->new, FALSE, FALSE, 0 );

    my $viewbar = Gtk2::Toolbar->new;
    $box->pack_start( $viewbar, FALSE, FALSE, 5 );
    $viewbar->set_style( 'both-horiz' );

    my $button = Gtk2::ToolButton->new_from_stock( 'gtk-select-all' );
    $button->set_label( _( 'View' ) );
    $viewbar->insert( $button, -1 );
    $button->set_is_important( TRUE );
    $button->signal_connect( clicked => \&view_history, $view );

    my $v_sep = Gtk2::SeparatorToolItem->new;
    $v_sep->set_draw( FALSE );
    $v_sep->set_expand( TRUE );
    $viewbar->insert( $v_sep, -1 );

    $button = Gtk2::ToolButton->new_from_stock( 'gtk-delete' );
    $viewbar->insert( $button, -1 );
    $button->set_is_important( TRUE );
    $button->signal_connect( clicked => \&del_history, $view );

    $box->show_all;
    return $box;
}

sub history_sort {
    my %orcish;
    return
        #<<<
        sort {
        ( $orcish{ $a } ||= -M $a )
                <=> ( $orcish{ $b } ||= -M $b ) }
                        @_;
        #>>>
}

sub view_history {
    my ( $button, $view ) = @_;
    my $select = $view->get_selection;
    return unless ( $select );

    my ( $model, $iter ) = $select->get_selected;
    return unless $iter;

    my $basename = '';
    $select->selected_foreach(
        sub {
            my ( $model, $path, $iter ) = @_;
            $basename = $model->get( $iter, 0 );
        }
    );

    # Grab the next item so the user can just hit View or Enter
    my $next_iter;
    my $new_path;
    if ( $model->iter_is_valid( $iter ) ) {
        $next_iter = $model->iter_next( $iter );
    } else {
        # This does not work. And that's stupid.
        # Or I am, for leaving it here.
        $next_iter = $model->get_iter_first;
    }
    if ( $next_iter && $model->iter_is_valid( $next_iter ) ) {
        $new_path = $model->get_path( $next_iter );
        $select->select_path( $new_path );
    }

    #<<<
    my $full_path
        = ClamTk::App->get_path( 'history' )
        . '/'
        . $basename
        . '.log';
    #>>>

    my $win = Gtk2::Dialog->new(
        sprintf( _( 'Viewing %s' ), $basename ),
        undef, [ qw| modal destroy-with-parent no-separator | ],
    );
    $win->signal_connect( destroy => sub { $win->destroy; 1 } );
    $win->set_default_size( 800, 350 );

    my $textview = Gtk2::TextView->new;
    $textview->set( editable       => FALSE );
    $textview->set( cursor_visible => FALSE );

    my $text;
    $text = do {
        my $FILE;    # filehandle for histories log
        #<<<
        unless ( open( $FILE, '<:encoding(UTF-8)', $full_path ) ) {
            my $notice
                = sprintf _( 'Problems opening %s...' ), $full_path;
                return;
        }
        #>>>
        local $/ = undef;
        <$FILE>;
    };
    #close( $FILE )
    #    or warn sprintf( "Unable to close FILE %s! %s\n" ),
    #    $full_path;

    my $textbuffer = $textview->get_buffer;
    # I hate setting a font here, but it makes the printf stuff
    # look MUCH better.
    $textbuffer->create_tag( 'mono', family => 'Monospace' );
    $textbuffer->insert_with_tags_by_name( $textbuffer->get_start_iter,
        $text, 'mono' );

    my $scroll_win = Gtk2::ScrolledWindow->new;
    $scroll_win->set_border_width( 5 );
    $scroll_win->set_shadow_type( 'none' );
    $scroll_win->set_policy( 'automatic', 'automatic' );

    my $scrollbox = Gtk2::VBox->new( FALSE, 5 );
    $win->get_content_area->add( $scrollbox );

    $scrollbox->pack_start( $scroll_win, TRUE, TRUE, 0 );
    $scroll_win->add( $textview );

    my $viewbar = Gtk2::Toolbar->new;
    $scrollbox->pack_start( $viewbar, FALSE, FALSE, 0 );
    $viewbar->set_style( 'both-horiz' );

    my $v_sep = Gtk2::SeparatorToolItem->new;
    $v_sep->set_draw( FALSE );
    $v_sep->set_expand( TRUE );
    $viewbar->insert( $v_sep, -1 );

    my $close_btn = Gtk2::ToolButton->new_from_stock( 'gtk-close' );
    $close_btn->set_is_important( TRUE );
    $viewbar->insert( $close_btn, -1 );
    $close_btn->signal_connect( clicked => sub { $win->destroy } );

    $win->show_all();
    $win->run;
    $win->destroy;
    return;
}

sub del_history {
    my ( $button, $tree ) = @_;
    my $sel = $tree->get_selection;

    my ( $model, $iter ) = $sel->get_selected;
    return unless $iter;

    my $row = $model->get( $iter, 0 );
    my $first_iter = $model->get_iter_first;
    # my $next_iter  = $model->iter_next($iter);
    my $new_path = $model->get_path( $iter );

    my $paths     = ClamTk::App->get_path( 'history' );
    my $top_dir   = $paths . '/';
    my $full_path = $top_dir . $row . '.log';
    # $row = undef;
    return FALSE unless ( -e $full_path );
    unlink( $full_path ) or warn "couldn't delete $full_path: $!\n";

    $model->remove( $iter );
    if ( $model->iter_is_valid( $iter ) ) {
        $sel->select_iter( $iter );
    } else {
        return;
    }
    # $sel->select_path( $new_path );
    return TRUE;
}

sub create_model {
    my $paths   = ClamTk::App->get_path( 'history' );
    my @h_files = glob "$paths/*.log";
    for ( @h_files ) {
        $_ = decode( 'utf8', $_ );
    }
    if ( @h_files > 1 ) {
        @h_files = history_sort( @h_files );
    }

    my $liststore = Gtk2::ListStore->new( 'Glib::String' );
    for my $log ( @h_files ) {
        my $iter     = $liststore->append;
        my $basename = basename( $log );
        $basename =~ s/(.*?)\.log/$1/;
        $liststore->set( $iter, 0, $basename );
    }
    return $liststore;
}

1;
