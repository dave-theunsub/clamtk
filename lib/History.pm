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
package ClamTk::History;

# use strict;
# use warnings;

use File::Basename 'basename';
use Locale::gettext;
use Encode 'decode';

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
    my $basename = '';
    $select->selected_foreach(
        sub {
            my ( $model, $path, $iter ) = @_;
            $basename = $model->get( $iter, 0 );
        }
    );
    #<<<
    my $full_path
        = ClamTk::App->get_path( 'history' )
        . '/'
        . $basename
        . '.log';
    #>>>

    my $win = Gtk2::Window->new;
    $win->set_title( sprintf( _( 'Viewing %s' ), $basename ) );
    $win->signal_connect( destroy => sub { $win->destroy } );
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
    $win->add( $scrollbox );

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
    return;
}

sub del_history {
    my ( $button, $tree ) = @_;
    my $sel = $tree->get_selection;

    my ( $model, $iter ) = $sel->get_selected;
    return unless $iter;

    my $row = $model->get( $iter, 0 );

    my $paths     = ClamTk::App->get_path( 'history' );
    my $top_dir   = $paths . '/';
    my $full_path = $top_dir . $row . '.log';
    $row = undef;
    return FALSE unless ( -e $full_path );
    unlink( $full_path ) or warn "couldn't delete $full_path: $!\n";

    $model->remove( $iter );
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
