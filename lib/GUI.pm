# ClamTk, copyright (C) 2004-2023 Dave M
#
# This file is part of ClamTk
# (https://gitlab.com/dave_m/clamtk/).
#
# ClamTk is free software; you can redistribute it and/or modify it
# under the terms of either:
#
# a) the GNU General Public License as published by the
# Free Software Foundation; either version 1, or (at your
# option) any later version, or
#
# b) the "Artistic License".
package ClamTk::GUI;

use Gtk3 '-init';
use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use POSIX 'locale_h';
use Locale::gettext;

my $window;
my $infobar;
my $top_box;
my $box;

# Some themes don't have all the "standard" gnome icons, so
# clamtk will crash if they're not there.  This is a patch from
# Arch Linux, which may solve the issue - or at least stop dying
# because it's missing an icon :|
# https://aur.archlinux.org/packages/clamtk/
my $theme = Gtk3::IconTheme::get_default;
$theme->append_search_path( '/usr/share/icons/gnome/24x24/actions' );
$theme->append_search_path( '/usr/share/icons/gnome/24x24/places' );
$theme->append_search_path( '/usr/share/icons/gnome/24x24/mimetypes' );

sub start_gui {
    $window = Gtk3::Window->new( 'toplevel' );
    $window->signal_connect(
        destroy => sub {
            $window->destroy;
            Gtk3->main_quit;
            TRUE;
        }
    );
    $window->signal_connect(
        delete_event => sub {
            $window->destroy;
            Gtk3->main_quit;
        }
    );
    $window->set_border_width( 3 );
    $window->set_position( 'center' );

    my $hb = Gtk3::HeaderBar->new;
    $window->set_titlebar( $hb );

    my $eb = Gtk3::EventBox->new;
    $window->add( $eb );

    $top_box = Gtk3::Box->new( vertical, 3 );
    $top_box->set_homogeneous( FALSE );
    $eb->add( $top_box );

    $hb->set_title( _( 'ClamTk Virus Scanner' ) );
    $hb->set_decoration_layout( 'menu,icon:minimize,close' );
    $hb->set_show_close_button( TRUE );

    my $separator = Gtk3::SeparatorToolItem->new;
    $separator->set_draw( FALSE );
    $separator->set_expand( TRUE );
    $hb->pack_end( $separator );

    my $button = Gtk3::Button->new_from_icon_name( 'help-about', 2 );
    $button->set_can_focus( FALSE );
    $hb->pack_end( $button );
    $button->set_tooltip_text( _( 'About' ) );
    $button->signal_connect( 'clicked', sub { about() } );

    $box = Gtk3::Box->new( vertical, 0 );
    $box->grab_focus;
    $top_box->set_homogeneous( FALSE );
    $box->set_border_width( 3 );
    $top_box->add( $box );

    $infobar = Gtk3::InfoBar->new;
    $top_box->pack_start( $infobar, FALSE, FALSE, 0 );
    $infobar->add_button( 'gtk-go-back', -5 );
    $infobar->signal_connect( 'response' => \&add_default_view );

    my $label = Gtk3::Label->new( '' );
    $label->set_use_markup( TRUE );
    $infobar->get_content_area()->add( $label );
    $infobar->grab_focus;

    # Keyboard shortcuts
    my $ui_info = ClamTk::Shortcuts->get_ui_info;
    my @entries = ClamTk::Shortcuts->get_pseudo_keys;

    my $actions = Gtk3::ActionGroup->new( 'Actions' );
    $actions->add_actions( \@entries, undef );

    my $ui = Gtk3::UIManager->new;
    $ui->insert_action_group( $actions, 0 );

    $window->add_accel_group( $ui->get_accel_group );
    $ui->add_ui_from_string( $ui_info );

    add_default_view();
    startup();

    $window->show_all;
    Gtk3->main;
}

sub startup {
    # Updates available for gui or sigs outdated?
    Gtk3::main_iteration while Gtk3::events_pending;

    my $startup_check = ClamTk::Startup->startup_check();
    my ( $message_type, $message );
    if ( $startup_check eq 'both' ) {
        $message      = _( 'Updates are available' );
        $message_type = 'other';
    } elsif ( $startup_check eq 'sigs' ) {
        $message      = _( 'The antivirus signatures are outdated' );
        $message_type = 'warning';
    } elsif ( $startup_check eq 'gui' ) {
        $message      = _( 'An update is available' );
        $message_type = 'other';
    } else {
        $message      = '';
        $message_type = 'other';
    }
    # Infobar is hidden typically, but if there
    # are updates, we need to show it
    Gtk3::main_iteration while Gtk3::events_pending;
    set_infobar_mode( $message_type, $message );
    $window->queue_draw;

    $infobar->show;
    $window->queue_draw;
}

sub set_infobar_mode {
    my ( $type, $text ) = @_;

    $infobar->set_message_type( $type );
    for my $c ( $infobar->get_content_area->get_children ) {
        if ( $c->isa( 'Gtk3::Label' ) ) {
            $c->set_text( $text );
        }
    }
}

sub set_infobar_text_remote {
    my ( $pkg, $type, $text ) = @_;

    $infobar->set_message_type( $type );
    for my $c ( $infobar->get_content_area->get_children ) {
        if ( $c->isa( 'Gtk3::Label' ) ) {
            $c->set_text( $text );
        }
    }
}

sub add_configuration {
    my $show_this = shift;

    my $label = Gtk3::Label->new;
    $label->set_markup( "<b>$show_this</b>" );
    $label->set_alignment( 0.01, 0.5 );

    return $label;
}

sub add_config_panels {
    my $liststore = Gtk3::ListStore->new(
        # Link, Description, Tooltip
        'Gtk3::Gdk::Pixbuf', 'Glib::String', 'Glib::String',
    );

    my $view = Gtk3::IconView->new_with_model( $liststore );
    $view->set_can_focus( FALSE );
    $view->set_column_spacing( 10 );
    $view->set_columns( 4 );
    $view->set_pixbuf_column( 0 );
    $view->set_row_spacing( 10 );
    $view->set_selection_mode( 'single' );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );

    # Set single-click
    my $path;
    $view->signal_connect(
        'motion-notify-event' => sub {
            my ( $widget, $event ) = @_;
            $path = $view->get_path_at_pos( $event->x, $event->y );
            if ( $path ) {
                $view->select_path( $path );
            } else {
                $view->unselect_all();
            }
        }
    );
    $view->signal_connect(
        'button-press-event' => sub {
            press( $path, $liststore );
        }
    );

    my @data = (
        {   link        => _( 'Settings' ),
            description => _( 'View and set your preferences' ),
            image       => 'preferences-system',
            button      => FALSE,
        },
        {   link        => _( 'Whitelist' ),
            description => _( 'View or update scanning whitelist' ),
            image       => 'security-high',
            button      => FALSE,
        },
        {   link        => _( 'Network' ),
            description => _( 'Edit proxy settings' ),
            image       => 'preferences-system-network',
            button      => FALSE,
        },
        {   link        => _( 'Scheduler' ),
            description => _( 'Schedule a scan or signature update' ),
            image       => 'alarm',
            button      => FALSE,
        },
    );

    #<<<
    # my $theme = Gtk3::IconTheme->new;
    for my $item ( @data ) {
        my $use_image = ClamTk::Icons->get_image($item->{image});
        my $iter = $liststore->append;
        my $pix = $theme->load_icon(
            $use_image, 24, 'use-builtin'
        );
        $liststore->set( $iter,
                0, $pix,
                1, $item->{link},
                2, $item->{description},
        );
    }
    #>>>

    return $view;
}

sub add_update_panels {
    my $liststore = Gtk3::ListStore->new(
        # Link, Description, Tooltip
        'Gtk3::Gdk::Pixbuf', 'Glib::String',
        'Glib::String',
    );

    my $view = Gtk3::IconView->new_with_model( $liststore );
    $view->set_can_focus( FALSE );
    $view->set_column_spacing( 10 );
    $view->set_columns( 3 );
    $view->set_pixbuf_column( 0 );
    $view->set_row_spacing( 10 );
    $view->set_selection_mode( 'single' );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );

    # Set single-click
    my $path;
    $view->signal_connect(
        'motion-notify-event' => sub {
            my ( $widget, $event ) = @_;
            $path = $view->get_path_at_pos( $event->x, $event->y );
            if ( $path ) {
                $view->select_path( $path );
            } else {
                $view->unselect_all();
            }
        }
    );
    $view->signal_connect(
        'button-press-event' => sub {
            press( $path, $liststore );
        }
    );

    my @data = (
        {   link        => _( 'Update' ),
            description => _( 'Update antivirus signatures' ),
            image       => 'software-update-available',
            button      => FALSE,
        },
        {   link        => _( 'Update Assistant' ),
            description => _( 'Signature update preferences' ),
            image       => 'system-help',
            button      => FALSE,
        },
    );

    #<<<
    # my $theme = Gtk3::IconTheme->new;
    for my $item ( @data ) {
        my $use_image = ClamTk::Icons->get_image($item->{image});
        my $iter = $liststore->append;
        my $pix = $theme->load_icon(
            $use_image, 24, 'use-builtin'
        );
        $liststore->set( $iter,
                0, $pix,
                1, $item->{link},
                2, $item->{description},
        );
    }
    #>>>

    return $view;
}

sub add_history_panels {
    my $liststore = Gtk3::ListStore->new(
        # Link, Description, Tooltip
        'Gtk3::Gdk::Pixbuf', 'Glib::String',
        'Glib::String',
    );

    my $view = Gtk3::IconView->new_with_model( $liststore );
    $view->set_columns( 3 );
    $view->set_column_spacing( 10 );
    $view->set_row_spacing( 10 );
    $view->set_pixbuf_column( 0 );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );
    $view->set_selection_mode( 'single' );
    $view->set_can_focus( FALSE );

    # Set single-click
    my $path;
    $view->signal_connect(
        'motion-notify-event' => sub {
            my ( $widget, $event ) = @_;
            $path = $view->get_path_at_pos( $event->x, $event->y );
            if ( $path ) {
                $view->select_path( $path );
            } else {
                $view->unselect_all();
            }
        }
    );
    $view->signal_connect(
        'button-press-event' => sub {
            press( $path, $liststore );
        }
    );

    my @data = (
        {   link        => _( 'History' ),
            description => _( 'View previous scans' ),
            image       => 'view-list',
            button      => FALSE,
        },
        {   link        => _( 'Quarantine' ),
            description => _( 'Manage quarantined files' ),
            image       => 'user-trash-full',
            button      => FALSE,
        },
    );

    #<<<
    for my $item ( @data ) {
        my $use_image = ClamTk::Icons->get_image($item->{image});
        my $iter = $liststore->append;
        my $pix = Gtk3::IconTheme::get_default->load_icon(
            $use_image, 24, 'use-builtin'
        );
        $liststore->set( $iter,
                0, $pix,
                1, $item->{link},
                2, $item->{description},
        );
    }
    #>>>

    return $view;
}

sub add_analysis_panels {
    my $liststore = Gtk3::ListStore->new(
        # Link, Description, Tooltip
        'Gtk3::Gdk::Pixbuf', 'Glib::String',
        'Glib::String',
    );

    my $view = Gtk3::IconView->new_with_model( $liststore );
    $view->set_can_focus( FALSE );
    $view->set_column_spacing( 10 );
    $view->set_columns( 3 );
    $view->set_pixbuf_column( 0 );
    $view->set_row_spacing( 10 );
    $view->set_selection_mode( 'single' );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );

    my $path;
    $view->signal_connect(
        'motion-notify-event' => sub {
            my ( $widget, $event ) = @_;
            $path = $view->get_path_at_pos( $event->x, $event->y );
            if ( $path ) {
                $view->select_path( $path );
            } else {
                $view->unselect_all();
            }
        }
    );
    $view->signal_connect(
        'button-press-event' => sub {
            press( $path, $liststore );
        }
    );

    #<<<
    my @scan_data = (
        {   link        => _( 'Scan a file' ),
            description => _( 'Scan a file' ),
            image       => 'document-new',
            button      => FALSE,
        },
        {   link        => _( 'Scan a directory' ),
            description => _( 'Scan a directory' ),
            image       => 'folder-documents',
            button      => FALSE,
        },
    );

    for my $item ( @scan_data ) {
        my $use_image = ClamTk::Icons->get_image($item->{image});
        my $iter = $liststore->append;
        my $pix = Gtk3::IconTheme::get_default->load_icon(
                $use_image, 24, 'use-builtin'
        );
        $liststore->set( $iter,
                0, $pix,
                1, $item->{link},
                2, $item->{description},
        );
    }

    my @data = (
        {   link        => _( 'Analysis' ),
            description => _( "View a file's reputation" ),
            image       => 'system-search',
            button      => FALSE,
        },
    );

    for my $item ( @data ) {
        my $use_image = ClamTk::Icons->get_image($item->{image});
        my $iter = $liststore->append;
        my $pix = Gtk3::IconTheme::get_default->load_icon(
                $use_image, 24, 'use-builtin'
        );
        $liststore->set( $iter,
                0, $pix,
                1, $item->{link},
                2, $item->{description},
        );
    }
    #>>>

    return $view;
}

sub swap_button {
    my $change_to = shift;
    if ( $change_to ) {
        $infobar->add_button( 'gtk-go-back', -5 );
        $infobar->signal_connect(
            response => sub {
                my ( $package, $filename, $line ) = caller;
                add_default_view();
                # Only do this if we're coming from
                # Update.pm - this will show the user
                # if the sigs were updated
                if ( $package eq 'ClamTk::Update' ) {
                    startup();
                }
            }
        );
    } else {
        for my $a ( $infobar->get_action_area ) {
            for my $b ( $a->get_children ) {
                #$b->set_sensitive( $change_to );
                if ( $b->isa( 'Gtk3::Button' ) ) {
                    $b->destroy;
                }
            }
        }
    }
}

sub press {
    my ( $path, $store ) = @_;
    return unless ( $path );

    my $iter  = $store->get_iter( $path );
    my $value = $store->get_value( $iter, 1 );

    iconview_react( $value );
}

sub click {
    my ( $view, $path, $model ) = @_;
    $view->unselect_all;

    my $iter  = $model->get_iter( $path );
    my $value = $model->get_value( $iter, 1 );

    iconview_react( $value );
}

sub iconview_react {
    # Receives the text of the icon clicked
    my $value = shift;

    # These are popups and don't change the main page
    if ( $value eq _( 'About' ) ) {
        about();
        return TRUE;
    } elsif ( $value eq _( 'Analysis' ) ) {
        ClamTk::Analysis->show_window;
        return TRUE;
    } elsif ( $value eq _( 'Scan a file' ) ) {
        select_file();
        return TRUE;
    } elsif ( $value eq _( 'Scan a directory' ) ) {
        select_directory();
        return TRUE;
    } elsif ( $value eq _( 'Scheduler' ) ) {
        ClamTk::Schedule->show_window( $window->get_position );
        return TRUE;
    }

    remove_box_children();
    swap_button( TRUE );

    if ( $value eq _( 'History' ) ) {
        $box->add( ClamTk::History->show_window );
    } elsif ( $value eq _( 'Settings' ) ) {
        $box->add( ClamTk::Settings->show_window );
    } elsif ( $value eq _( 'Update' ) ) {
        $box->add( ClamTk::Update->show_window );
    } elsif ( $value eq _( 'Quarantine' ) ) {
        $box->add( ClamTk::Quarantine->show_window );
    } elsif ( $value eq _( 'Network' ) ) {
        $box->add( ClamTk::Network->show_window );
    } elsif ( $value eq _( 'Whitelist' ) ) {
        $box->add( ClamTk::Whitelist->show_window );
    } elsif ( $value eq _( 'Update Assistant' ) ) {
        $box->add( ClamTk::Assistant->show_window );
    }

    $window->queue_draw;
    return TRUE;
}

sub select_file {
    my $file   = '';
    my $dialog = Gtk3::FileChooserDialog->new(
        _( 'Select a file' ), $window,
        'open',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok',
    );
    $dialog->set_select_multiple( FALSE );
    $dialog->set_position( 'center-on-parent' );

    # FALSE until there is an option to change it
    $dialog->set_show_hidden( FALSE );

    if ( 'ok' eq $dialog->run ) {
        $window->queue_draw;
        Gtk3::main_iteration while Gtk3::events_pending;
        $file = $dialog->get_filename;
        $dialog->destroy;
        $window->queue_draw;
    } else {
        $dialog->destroy;
        return FALSE;
    }

    if ( $file =~ m#^(/proc|/sys|/dev)# ) {
        ClamTk::Scan::popup(
            _( 'You do not have permissions to scan that file or directory' )
        );
        undef $file;
        select_file();
    }

    if ( -e $file ) {
        ClamTk::Scan->filter( $file, FALSE, undef );
    }
}

sub select_directory {
    my $directory = '';

    my $dialog = Gtk3::FileChooserDialog->new(
        _( 'Select a directory' ), $window,
        'select-folder',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok',
    );
    $dialog->set_position( 'center-on-parent' );
    $dialog->set_current_folder( ClamTk::App->get_path( 'directory' ) );
    $dialog->set_show_hidden( FALSE );

    if ( 'ok' eq $dialog->run ) {
        $directory = $dialog->get_filename;
        Gtk3::main_iteration while Gtk3::events_pending;
        $dialog->destroy;
        $window->queue_draw;
    } else {
        $dialog->destroy;
        return FALSE;
    }

    # May want to enable these one day.  Lots of
    # rootkits hang out under /dev.
    if ( $directory =~ m#^(/proc|/sys|/dev)# ) {
        ClamTk::Scan::popup(
            _( 'You do not have permissions to scan that file or directory' )
        );
        undef $directory;
        select_directory();
    }

    if ( -e $directory ) {
        ClamTk::Scan->filter( $directory, FALSE, undef );
    }
}

sub remove_box_children {
    for my $c ( $box->get_children ) {
        $box->remove( $c );
    }
}

sub add_default_view {
    remove_box_children();

    # Needs spacing or it's jammed against the toolbar
    $box->pack_start( add_configuration( _( 'Configuration' ) ),
        TRUE, TRUE, 2 );

    $box->pack_start( add_config_panels(), TRUE, TRUE, 0 );

    $box->pack_start( Gtk3::HSeparator->new, TRUE, TRUE, 2 );

    $box->pack_start( add_configuration( _( 'History' ) ), TRUE, TRUE, 0 );

    $box->pack_start( add_history_panels(), TRUE, TRUE, 0 );

    $box->pack_start( Gtk3::Separator->new( 'horizontal' ), TRUE, TRUE, 2 );

    $box->pack_start( add_configuration( _( 'Updates' ) ), TRUE, TRUE, 0 );

    $box->pack_start( add_update_panels(), TRUE, TRUE, 0 );

    $box->pack_start( Gtk3::Separator->new( 'horizontal' ), TRUE, TRUE, 2 );

    $box->pack_start( add_configuration( _( 'Analysis' ) ), TRUE, TRUE, 0 );

    $box->pack_start( add_analysis_panels(), TRUE, TRUE, 0 );

    $box->show_all;
    swap_button( FALSE );

    Gtk3::main_iteration while Gtk3::events_pending;
    $window->resize( 340, 400 );
    $window->queue_draw;
    Gtk3::main_iteration while Gtk3::events_pending;
}

sub about {
    my $dialog = Gtk3::AboutDialog->new;
    my $license
        = 'ClamTk is free software; you can redistribute it and/or'
        . ' modify it under the terms of either:'
        . ' a) the GNU General Public License as published by the Free'
        . ' Software Foundation; either version 1, or (at your option)'
        . ' any later version, or'
        . ' b) the "Artistic License".';
    $dialog->set_wrap_license( TRUE );
    $dialog->set_position( 'mouse' );

    my $images_dir = ClamTk::App->get_path( 'images' );
    my $icon       = "$images_dir/clamtk.png";
    my $pixbuf     = Gtk3::Gdk::Pixbuf->new_from_file( $icon );

    $dialog->set_logo( $pixbuf );
    $dialog->set_version( ClamTk::App->get_TK_version() );
    $dialog->set_license( $license );
    $dialog->set_website_label( _( 'Homepage' ) );
    $dialog->set_website( 'https://gitlab.com/dave_m/clamtk/wikis/Home' );
    $dialog->set_logo( $pixbuf );
    $dialog->set_translator_credits(
        'Please see the credits.md for full listing' );
    $dialog->set_copyright( "\x{a9} Dave M 2004 - 2023" );
    $dialog->set_program_name( 'ClamTk' );
    $dialog->set_authors( [ 'Dave M', 'dave.nerd@gmail.com' ] );
    $dialog->set_comments(
              _( 'ClamTk is a graphical front-end for Clam Antivirus' ) . "\n"
            . '(ClamAV '
            . ClamTk::App->get_AV_version()
            . ')' );

    $dialog->run;
    $dialog->destroy;
}

1;
