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
package ClamTk::GUI;

use Gtk2 '-init';
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

sub start_gui {
    $window = Gtk2::Window->new;
    $window->signal_connect(
        destroy => sub {
            $window->destroy;
            Gtk2->main_quit;
            TRUE;
        }
    );
    $window->signal_connect(
        delete_event => sub {
            $window->destroy;
            Gtk2->main_quit;
        }
    );
    $window->set_title( _( 'Virus Scanner' ) );
    $window->set_border_width( 5 );
    #$window->set_default_size( 340, 400 );
    $window->set_position( 'center' );

    my $images_dir = ClamTk::App->get_path( 'images' );
    my $pixbuf
        = Gtk2::Gdk::Pixbuf->new_from_file_at_size( "$images_dir/clamtk.png",
        24, 24 );

    if ( -e "$images_dir/clamtk.png" ) {
        my $transparent = $pixbuf->add_alpha( TRUE, 0xff, 0xff, 0xff );
        $window->set_icon( $transparent );
    }

    my $white = Gtk2::Gdk::Color->new( 0xFFFF, 0xFFFF, 0xFFFF );
    my $eb = Gtk2::EventBox->new;
    $eb->modify_bg( 'normal', $white );
    $window->add( $eb );

    $top_box = Gtk2::VBox->new( FALSE, 5 );
    $eb->add( $top_box );

    my $toolbar = Gtk2::Toolbar->new;
    $top_box->pack_start( $toolbar, FALSE, FALSE, 0 );
    $toolbar->can_focus( FALSE );
    $toolbar->set_show_arrow( FALSE );

    my $image = Gtk2::Image->new;
    $image->set_from_pixbuf( $pixbuf );

    my $button = Gtk2::ToolButton->new( $image, '' );
    $button->set_sensitive( FALSE );
    $button->set_tooltip_text( _( 'ClamTk Virus Scanner' ) );
    $toolbar->insert( $button, -1 );

    my $separator = Gtk2::SeparatorToolItem->new;
    $separator->can_focus( TRUE );
    $separator->set_draw( FALSE );
    $separator->set_expand( TRUE );
    $toolbar->insert( $separator, -1 );

    $button = Gtk2::ToolButton->new_from_stock( 'gtk-help' );
    $button->can_focus( FALSE );
    $toolbar->insert( $button, -1 );
    $button->set_tooltip_text( _( 'Help' ) );
    $button->signal_connect( clicked => \&help );

    $button = Gtk2::ToolButton->new_from_stock( 'gtk-about' );
    $button->can_focus( FALSE );
    $toolbar->insert( $button, -1 );
    $button->set_tooltip_text( _( 'About' ) );
    $button->signal_connect( clicked => \&about );

    $toolbar->insert( Gtk2::SeparatorToolItem->new, -1 );

    $button = Gtk2::ToolButton->new_from_stock( 'gtk-quit' );
    $button->can_focus( FALSE );
    $toolbar->insert( $button, -1 );
    $button->set_tooltip_text( _( 'Quit' ) );
    $button->signal_connect(
        clicked => sub {
            Gtk2->main_quit;
        }
    );

    $box = Gtk2::VBox->new( FALSE, 0 );
    $box->set_border_width( 5 );
    $top_box->add( $box );

    $infobar = Gtk2::InfoBar->new;
    $top_box->pack_start( $infobar, FALSE, FALSE, 0 );
    $infobar->add_button( 'gtk-go-back', -5 );
    $infobar->signal_connect( 'response' => \&add_default_view );
    my $label = Gtk2::Label->new( '' );
    $label->modify_font( Pango::FontDescription->from_string( 'Monospace' ) );
    $label->set_use_markup( TRUE );
    $infobar->get_content_area()->add( $label );
    $infobar->grab_focus;

    # Keyboard shortcuts
    my $ui_info = ClamTk::Shortcuts->get_ui_info;
    my @entries = ClamTk::Shortcuts->get_pseudo_keys;

    my $actions = Gtk2::ActionGroup->new( 'Actions' );
    $actions->add_actions( \@entries, undef );

    my $ui = Gtk2::UIManager->new;
    $ui->insert_action_group( $actions, 0 );

    $window->add_accel_group( $ui->get_accel_group );
    $ui->add_ui_from_string( $ui_info );

    add_default_view();
    startup();

    $window->show_all;
    Gtk2->main;
}

sub startup {
    # Updates available for gui or sigs outdated?
    Gtk2->main_iteration while Gtk2->events_pending;
    my $startup_check = ClamTk::Startup->startup_check();
    my ( $message_type, $message );
    if ( $startup_check eq 'both' ) {
        $message      = _( 'Updates are available' );
        $message_type = 'warning';
    } elsif ( $startup_check eq 'sigs' ) {
        $message      = _( 'The antivirus signatures are outdated' );
        $message_type = 'warning';
    } elsif ( $startup_check eq 'gui' ) {
        $message      = _( 'An update is available' );
        $message_type = 'info';
    } else {
        $message      = '';
        $message_type = 'info';
    }
    # Infobar is hidden typically, but if there
    # are updates, we need to show it
    Gtk2->main_iteration while Gtk2->events_pending;
    set_infobar_mode( $message_type, $message );
    $window->queue_draw;

    # $window->resize( 340, 400 );
    $infobar->show;
    $window->queue_draw;
    Gtk2->main_iteration while Gtk2->events_pending;
}

sub set_infobar_mode {
    my ( $type, $text ) = @_;

    $infobar->set_message_type( $type );
    for my $c ( $infobar->get_content_area->get_children ) {
        if ( $c->isa( 'Gtk2::Label' ) ) {
            $c->modify_font(
                Pango::FontDescription->from_string( 'Monospace' ) );
            $c->set_text( $text );
        }
    }
}

sub set_infobar_text_remote {
    my ( $pkg, $type, $text ) = @_;

    $infobar->set_message_type( $type );
    for my $c ( $infobar->get_content_area->get_children ) {
        if ( $c->isa( 'Gtk2::Label' ) ) {
            $c->modify_font(
                Pango::FontDescription->from_string( 'Monospace' ) );
            $c->set_text( $text );
        }
    }
}

sub add_configuration {
    my $show_this = shift;

    my $label = Gtk2::Label->new;
  # $label->modify_font( Pango::FontDescription->from_string( 'Monospace' ) );
    $label->set_markup( "<b>$show_this</b>" );
    $label->set_alignment( 0.01, 0.5 );

    return $label;
}

sub add_config_panels {
    my $liststore = Gtk2::ListStore->new(
        # Link, Description, Tooltip
        'Gtk2::Gdk::Pixbuf', 'Glib::String', 'Glib::String',
    );

    my $view = Gtk2::IconView->new_with_model( $liststore );
    $view->set_columns( 4 );
    $view->set_column_spacing( 10 );
    $view->set_row_spacing( 10 );
    $view->set_pixbuf_column( 0 );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );
    $view->set_selection_mode( 'single' );
    $view->set_can_focus( FALSE );

    my $prefs = ClamTk::Prefs->get_preference( 'Clickings' );
    if ( $prefs == 2 ) {
        $view->signal_connect(
            'item-activated' => \&click,
            $liststore
        );
    } elsif ( $prefs == 1 ) {
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
    }

    my @data = (
        {   link        => _( 'Settings' ),
            description => _( 'View and set your preferences' ),
            image       => 'gtk-preferences',
            button      => FALSE,
        },
        {   link        => _( 'Whitelist' ),
            description => _( 'View or update scanning whitelist' ),
            image       => 'gtk-new',
            button      => FALSE,
        },
        {   link        => _( 'Network' ),
            description => _( 'Edit proxy settings' ),
            image       => 'gtk-network',
            button      => FALSE,
        },
        {   link        => _( 'Scheduler' ),
            description => _( 'Schedule a scan or signature update' ),
            image       => 'gtk-properties',
            button      => FALSE,
        },
    );

    #<<<
    my $theme = Gtk2::IconTheme->new;
    for my $item ( @data ) {
        my $iter = $liststore->append;
        my $pix = Gtk2::IconTheme->get_default->load_icon(
                $item->{image}, 24, 'use-builtin'
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
    my $liststore = Gtk2::ListStore->new(
        # Link, Description, Tooltip
        'Gtk2::Gdk::Pixbuf', 'Glib::String',
        'Glib::String',
    );

    my $view = Gtk2::IconView->new_with_model( $liststore );
    $view->set_columns( 3 );
    $view->set_column_spacing( 10 );
    $view->set_row_spacing( 10 );
    $view->set_pixbuf_column( 0 );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );
    $view->set_selection_mode( 'single' );
    $view->set_can_focus( FALSE );

    my $prefs = ClamTk::Prefs->get_preference( 'Clickings' );

    if ( $prefs == 2 ) {
        $view->signal_connect(
            'item-activated' => \&click,
            $liststore
        );
    } elsif ( $prefs == 1 ) {
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
    }

    my @data = (
        {   link        => _( 'Update' ),
            description => _( 'Update antivirus signatures' ),
            image       => 'gtk-goto-bottom',
            button      => FALSE,
        },
        {   link        => _( 'Update Assistant' ),
            description => _( 'Signature update preferences' ),
            image       => 'gtk-color-picker',
            button      => FALSE,
        },
    );

    #<<<
    for my $item ( @data ) {
        my $iter = $liststore->append;
        my $pix = Gtk2::IconTheme->get_default->load_icon(
                $item->{image}, 24, 'use-builtin'
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
    my $liststore = Gtk2::ListStore->new(
        # Link, Description, Tooltip
        'Gtk2::Gdk::Pixbuf', 'Glib::String',
        'Glib::String',
    );

    my $view = Gtk2::IconView->new_with_model( $liststore );
    $view->set_columns( 3 );
    $view->set_column_spacing( 10 );
    $view->set_row_spacing( 10 );
    $view->set_pixbuf_column( 0 );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );
    $view->set_selection_mode( 'single' );
    $view->set_can_focus( FALSE );

    my $prefs = ClamTk::Prefs->get_preference( 'Clickings' );

    if ( $prefs == 2 ) {
        $view->signal_connect(
            'item-activated' => \&click,
            $liststore
        );
    } elsif ( $prefs == 1 ) {
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
    }

    my @data = (
        {   link        => _( 'History' ),
            description => _( 'View previous scans' ),
            image       => 'gtk-edit',
            button      => FALSE,
        },
        {   link        => _( 'Quarantine' ),
            description => _( 'Manage quarantined files' ),
            image       => 'gtk-refresh',
            button      => FALSE,
        },
    );

    #<<<
    for my $item ( @data ) {
        my $iter = $liststore->append;
        my $pix = Gtk2::IconTheme->get_default->load_icon(
                $item->{image}, 24, 'use-builtin'
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
    my $liststore = Gtk2::ListStore->new(
        # Link, Description, Tooltip
        'Gtk2::Gdk::Pixbuf', 'Glib::String',
        'Glib::String',
    );

    my $view = Gtk2::IconView->new_with_model( $liststore );
    $view->set_columns( 3 );
    $view->set_column_spacing( 10 );
    $view->set_row_spacing( 10 );
    $view->set_pixbuf_column( 0 );
    $view->set_text_column( 1 );
    $view->set_tooltip_column( 2 );
    $view->set_selection_mode( 'single' );
    $view->set_can_focus( FALSE );

    my $prefs = ClamTk::Prefs->get_preference( 'Clickings' );

    if ( $prefs == 2 ) {
        $view->signal_connect(
            'item-activated' => \&click,
            $liststore
        );
    } elsif ( $prefs == 1 ) {
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
    }

    #<<<
    # For CentOS only:
    my @centos_data = (
        {   link        => _( 'Scan a file' ),
            description => _( 'Scan a file' ),
            image       => 'gtk-file',
            button      => FALSE,
        },
        {   link        => _( 'Scan a directory' ),
            description => _( 'Scan a directory' ),
            image       => 'gtk-directory',
            button      => FALSE,
        },
    );

    for my $item ( @centos_data ) {
        my $iter = $liststore->append;
        my $pix = Gtk2::IconTheme->get_default->load_icon(
                $item->{image}, 24, 'use-builtin'
        );
        $liststore->set( $iter,
                0, $pix,
                1, $item->{link},
                2, $item->{description},
        );
    }

    # What should have been...
    my @data = (
        {   link        => _( 'Analysis' ),
            description => _( "View a file's reputation" ),
            image       => 'gtk-find',
            button      => FALSE,
        },
    );

    for my $item ( @data ) {
        my $iter = $liststore->append;
        my $pix = Gtk2::IconTheme->get_default->load_icon(
                $item->{image}, 24, 'use-builtin'
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
        # $infobar->signal_connect( 'response' => \&add_default_view );
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
                if ( $b->isa( 'Gtk2::Button' ) ) {
                    $b->destroy;
                }
            }
        }
    }
}

sub press {
    my ( $path, $store ) = @_;
    return unless ( $path );

    my $iter = $store->get_iter( $path );
    my $value = $store->get_value( $iter, 1 );

    iconview_react( $value );
}

sub click {
    my ( $view, $path, $model ) = @_;
    $view->unselect_all;

    my $iter = $model->get_iter( $path );
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
    } elsif ( $value eq _( 'Help' ) ) {
        help();
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
    my $dialog = Gtk2::FileChooserDialog->new(
        _( 'Select a file' ), $window,
        'open',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok',
    );
    $dialog->set_select_multiple( FALSE );
    if ( ClamTk::Prefs->get_preference( 'ScanHidden' ) ) {
        $dialog->set_show_hidden( TRUE );
    }
    $dialog->set_position( 'center-on-parent' );
    if ( 'ok' eq $dialog->run ) {
        $window->queue_draw;
        Gtk2->main_iteration while ( Gtk2->events_pending );
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
    my $dialog    = Gtk2::FileChooserDialog->new(
        _( 'Select a directory' ), $window,
        'select-folder',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok',
    );
    $dialog->set_position( 'center-on-parent' );
    $dialog->set_current_folder( ClamTk::App->get_path( 'directory' ) );
    if ( ClamTk::Prefs->get_preference( 'ScanHidden' ) ) {
        $dialog->set_show_hidden( TRUE );
    }
    if ( 'ok' eq $dialog->run ) {
        $directory = $dialog->get_filename;
        Gtk2->main_iteration while ( Gtk2->events_pending );
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

    $box->pack_start( Gtk2::HSeparator->new, TRUE, TRUE, 2 );

    $box->pack_start( add_configuration( _( 'History' ) ), TRUE, TRUE, 0 );

    $box->pack_start( add_history_panels(), TRUE, TRUE, 0 );

    $box->pack_start( Gtk2::HSeparator->new, TRUE, TRUE, 2 );

    $box->pack_start( add_configuration( _( 'Updates' ) ), TRUE, TRUE, 0 );

    $box->pack_start( add_update_panels(), TRUE, TRUE, 0 );

    $box->pack_start( Gtk2::HSeparator->new, TRUE, TRUE, 2 );

    $box->pack_start( add_configuration( _( 'Analysis' ) ), TRUE, TRUE, 0 );

    $box->pack_start( add_analysis_panels(), TRUE, TRUE, 0 );

    $box->show_all;
    swap_button( FALSE );

    Gtk2->main_iteration while Gtk2->events_pending;
    $window->resize( 340, 400 );
    $window->queue_draw;
    Gtk2->main_iteration while Gtk2->events_pending;
}

sub help {
    local $ENV{ 'PATH' } = '/bin:/usr/bin:/sbin';
    delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
    my $path  = '';
    my $which = 'which';
    my $yelp  = 'yelp';
    # By default, use this:
    my $docs = 'help:clamtk/index';
    # But CentOS will choke on that, because it uses
    # /usr/share/gnome/help/blah blah blah.
    # We *could* open /etc/issue, and give it the
    # right option when it sees CentOS, but...
    # for now, I'm going to manually uncomment this
    # when building for CentOS.
    # my $docs = 'ghelp:clamtk';

    if ( open( my $c, '-|', $which, $yelp ) ) {
        while ( <$c> ) {
            chomp;
            $path = $_ if ( -e $_ );
        }
    }

    # If yelp isn't found, maybe gnome-help will be.
    # Should be the same thing.
    if ( !$path ) {
        $yelp = 'gnome-help';
        if ( open( my $c, '-|', $which, $yelp ) ) {
            while ( <$c> ) {
                chomp;
                $path = $_ if ( -e $_ );
            }
        }
    }

    if ( $path ) {
        # We can't use "system" here, because it will
        # wait for the process to end, causing a noticable lag.
        my $pid = fork();
        if ( defined( $pid ) && $pid == 0 ) {
            exec( "$yelp $docs" );
            exit;
        }
        return;
    }

    my $dialog
        = Gtk2::MessageDialog->new( undef,
        [ qw| modal destroy-with-parent | ],
        'info', 'close', _( 'Please install yelp to view documentation' ) );
    $dialog->run;
    $dialog->destroy;
}

sub about {
    my $dialog = Gtk2::AboutDialog->new;
    my $license
        = 'ClamTk is free software; you can redistribute it and/or'
        . ' modify it under the terms of either:'
        . ' a) the GNU General Public License as published by the Free'
        . ' Software Foundation; either version 1, or (at your option)'
        . ' any later version, or'
        . ' b) the "Artistic License".';
    $dialog->set_wrap_license( TRUE );
    $dialog->set_position( 'mouse' );
    $dialog->modify_font(
        Pango::FontDescription->from_string( 'Monospace' ) );

    my $images_dir = ClamTk::App->get_path( 'images' );
    my $icon       = "$images_dir/clamtk.png";
    my $pixbuf     = Gtk2::Gdk::Pixbuf->new_from_file( $icon );

    $dialog->set_logo( $pixbuf );
    $dialog->set_version( ClamTk::App->get_TK_version() );
    $dialog->set_license( $license );
    $dialog->set_website_label( _( 'Homepage' ) );
    $dialog->set_website( 'https://dave-theunsub.github.io/clamtk/' );
    $dialog->set_logo( $pixbuf );
    $dialog->set_translator_credits(
        'Please see the website for full listing' );
    $dialog->set_copyright( "\x{a9} Dave M 2004 - 2016" );
    $dialog->set_program_name( 'ClamTk' );
    #$dialog->set_authors( [ 'Dave M', 'dave.nerd@gmail.com' ] );
    $dialog->set_authors( 'Dave M <dave.nerd@gmail.com>' );
    $dialog->set_comments(
        'ClamTk is a graphical front-end for the ClamAV Antivirus' );

    $dialog->run;
    $dialog->destroy;
}

1;
