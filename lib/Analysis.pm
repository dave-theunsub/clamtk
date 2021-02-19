# ClamTk, copyright (C) 2004-2021 Dave M
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
package ClamTk::Analysis;

use Glib 'TRUE', 'FALSE';

# use strict;
# use warnings;
$| = 1;

use LWP::UserAgent;
use LWP::Protocol::https;
use MIME::Base64 'decode_base64';
use Digest::SHA 'sha256_hex';
use File::Basename 'basename';
use File::Copy 'move';
use Text::CSV;
use JSON;
use Encode 'encode';

use POSIX 'locale_h';
use Locale::gettext;

binmode STDIN, ":encoding(UTF-8)";

my $store;            # Liststore results
my $model;            # ListStore for combobox
my $combobox;         # ComboBox for previous analysis
my $nb;               # Notebook
my $filename = '';    # name of file analyzed
my $bar;              # InfoBar
my $window;           # Dialog; global for queue_draw;
my $submitted = 0;    # Boolean value to keep track if file
                      # has been submitted or not
my $from_scan;

sub show_window {
    ( undef, $from_scan, $parent ) = @_;
    $window
        = Gtk3::Dialog->new( undef, $parent,
        [ qw| modal destroy-with-parent use-header-bar | ],
        );
    $window->signal_connect(
        destroy => sub {
            $window->destroy;
            1;
        }
    );
    $window->set_border_width( 5 );
    $window->set_default_size( 450, 250 );
    $window->set_position( 'mouse' );

    my $hb = Gtk3::HeaderBar->new;
    $hb->set_title( _( 'Analysis' ) );
    $hb->set_show_close_button( TRUE );
    $hb->set_decoration_layout( 'menu:close' );

    my $images_dir = ClamTk::App->get_path( 'images' );
    my $pixbuf
        = Gtk3::Gdk::Pixbuf->new_from_file_at_size( "$images_dir/clamtk.png",
        24, 24 );
    my $image = Gtk3::Image->new;
    $image->set_from_pixbuf( $pixbuf );
    my $button = Gtk3::ToolButton->new( $image, '' );
    $button->set_sensitive( FALSE );
    $button->set_tooltip_text( _( 'ClamTk Virus Scanner' ) );
    $hb->pack_start( $button );
    $window->set_titlebar( $hb );

    my $help_message = _(
        "This section allows you to check the status of a file from Virustotal. If a file has been previously submitted, you will see the results of the scans from dozens of antivirus and security vendors. This allows you to make a more informed decision about the safety of a file.

If the file has never been submitted to Virustotal, you can submit it yourself. When you resubmit the file minutes later, you should see the results.

Please note you should never submit sensitive files to Virustotal.  Any uploaded file can be viewed by Virustotal customers. Do not submit anything with personal information or passwords.

https://www.virustotal.com/gui/home/search"
    );

    my $help_btn  = Gtk3::ToolButton->new();
    my $use_image = ClamTk::Icons->get_image( 'system-help' );
    $help_btn->set_label( _( 'Help' ) );
    $help_btn->set_icon_name( $use_image );
    $help_btn->set_is_important( TRUE );
    $help_btn->set_tooltip_text( _( 'What is this?' ) );
    $help_btn->signal_connect( clicked => sub { popup( $help_message ) } );
    $hb->pack_start( $help_btn );

    my $box = Gtk3::Box->new( 'vertical', 5 );
    $box->set_homogeneous( FALSE );
    $window->get_content_area->add( $box );

    $nb = Gtk3::Notebook->new;
    $box->pack_start( $nb, TRUE, TRUE, 0 );

    #<<<
    # Add initial page (select file, etc)
    $nb->insert_page(
        page_one(),
        Gtk3::Label->new( _( 'File Analysis' ) ),
        0,
    );

    # Add results page
    $nb->insert_page(
        page_two(),
        Gtk3::Label->new( _( 'Results' ) ),
        1,
    );
    #>>>

    $bar = Gtk3::InfoBar->new;
    $box->pack_start( $bar, FALSE, FALSE, 0 );
    $bar->set_message_type( 'other' );
    # $bar->add_button( 'gtk-close', -7 );
    $bar->add_button( _( 'Close' ), -7 );
    $bar->signal_connect(
        response => sub {
            $submitted = 0;
            $window->destroy;
        }
    );

    $window->show_all;
    $window->run;
    $window->destroy;
    1;
}

sub page_one {
    # Analysis page
    my $box = Gtk3::Box->new( 'vertical', 5 );
    $box->set_homogeneous( FALSE );

    my $separator = Gtk3::Separator->new( 'horizontal' );

    $box->pack_start( analysis_frame_one(), FALSE, FALSE, 5 );
    $box->pack_start( $separator,           FALSE, FALSE, 5 );
    $box->pack_start( analysis_frame_two(), FALSE, FALSE, 5 );

    return $box;
}

sub page_two {
    # Results page
    my $box = Gtk3::VBox->new( FALSE, 0 );

    my $sw = Gtk3::ScrolledWindow->new( undef, undef );
    $sw->set_policy( 'never', 'automatic' );
    $box->pack_start( $sw, TRUE, TRUE, 0 );

    use constant VENDOR => 0;
    use constant RESULT => 1;
    use constant DATE   => 2;

    #<<<
    $store = Gtk3::ListStore->new(
            # VENDOR
            'Glib::String',
            # RESULT
            'Glib::String',
            # DATE
            'Glib::String',
    );

    my $tree = Gtk3::TreeView->new_with_model( $store );
    $tree->set_rules_hint( TRUE );
    $sw->add( $tree );

    my $renderer = Gtk3::CellRendererText->new;
    my $column
        = Gtk3::TreeViewColumn->new_with_attributes(
                _( 'Vendor' ),
                $renderer,
                text => VENDOR,
    );
    $column->set_expand( TRUE );
    $column->set_sort_column_id( VENDOR );
    $tree->append_column( $column );

    $column = Gtk3::TreeViewColumn->new_with_attributes(
                _( 'Date' ),
                $renderer,
                text => DATE,
    );
    $column->set_sort_column_id( DATE );
    $column->set_expand( TRUE );
    $tree->append_column( $column );

    $column = Gtk3::TreeViewColumn->new_with_attributes(
                _( 'Result' ),
                $renderer,
                text => RESULT,
    );
    $column->set_expand( TRUE );
    $column->set_sort_column_id( RESULT );
    $tree->append_column( $column );
    #>>>

    my $toolbar = Gtk3::Toolbar->new;
    $box->pack_start( $toolbar, FALSE, FALSE, 3 );
    $toolbar->set_style( 'both-horiz' );

    my $separator = Gtk3::SeparatorToolItem->new;
    $separator->set_draw( FALSE );
    $separator->set_expand( TRUE );
    $toolbar->insert( $separator, -1 );

    my $button = Gtk3::ToolButton->new();
    $button->set_icon_name( 'document-save-as' );
    $button->set_label( _( 'Save results' ) );
    # $button->set_tooltip_text( _( 'Save results' ) );
    $toolbar->insert( $button, -1 );
    $button->signal_connect(
        clicked => sub {
            return unless ( $store->iter_n_children );
            save_file();
        }
    );

    return $box;
}

sub analysis_frame_one {
    my $box = Gtk3::Box->new( 'vertical', 5 );
    $box->set_homogeneous( FALSE );

    my $label
        = Gtk3::Label->new( _( "Check or recheck a file's reputation" ) );
    $label->set_alignment( 0.0, 0.5 );
    $box->pack_start( $label, FALSE, FALSE, 5 );

    my $grid = Gtk3::Grid->new();
    $box->pack_start( $grid, FALSE, FALSE, 5 );
    $grid->set_column_spacing( 10 );
    $grid->set_column_homogeneous( FALSE );
    $grid->set_row_spacing( 10 );
    $grid->set_row_homogeneous( TRUE );

    #<<<
    # Declaring this now for setting sensitive/insensitive
    my $button = Gtk3::ToolButton->new();
    my $use_image = ClamTk::Icons->get_image('edit-select');
    $button->set_icon_name($use_image);

    my $select_button
        = Gtk3::FileChooserButton->new(
                _( 'Select a file' ),
                'open',
    );

    # If we've arrived from scanning results, set the file:
    if( $from_scan ) {
            $select_button->set_filename( $from_scan );
    }
    $button->set_sensitive( TRUE );
    $select_button->set_hexpand(TRUE);

    $select_button->set_current_folder(
        ClamTk::App->get_path( 'directory' )
    );
    $grid->attach( $select_button, 0, 0, 1, 1 );
    #>>>

    my $separator = Gtk3::SeparatorToolItem->new;
    $separator->set_draw( FALSE );
    $grid->attach( $separator, 1, 0, 1, 1 );

    $grid->attach( $button, 2, 0, 1, 1 );
    $button->set_tooltip_text( _( 'Submit file for analysis' ) );

    $button->signal_connect(
        clicked => sub {
            $filename = $select_button->get_filename;
            return unless -e $filename;

            $submitted++;

            # VT size limit using the API is 32MB
            # https://www.virustotal.com/en/faq/
            my $size = -s $filename;
            my $mb   = $size / ( 1024 * 1024 );
            if ( $mb > 32 ) {
                warn "filesize too large - must be smaller than 32MB\n";
                popup( _( 'Uploaded files must be smaller than 32MB' ) );
                return;
            }

            # Gtk3::main_iteration while Gtk3::events_pending;
            my ( $vt_results, $new_window, $is_error )
                = check_for_existing( $filename );

            # Information exists on this file; show results
            if ( $new_window ) {
                $nb->show_all;
                $nb->set_current_page( 1 );
                #} elsif ( $new_window && !$is_error ) {
            } elsif ( $vt_results == 0 ) {
                # No information exists; offer to submit file
                my $confirm = popup(
                    _(        'No information exists for this file.' . ' '
                            . 'Press OK to submit this file for analysis.'
                    ),
                    1
                );
                if ( $confirm ) {
                    $submitted++;
                    submit_new();
                    return;
                }
            } else {
                popup( _( 'Unable to submit file: try again later' ) );
                return;
            }
        }
    );

    return $box;
}

sub analysis_frame_two {
    my $box = Gtk3::Box->new( 'vertical', 5 );
    $box->set_homogeneous( FALSE );

    my $label = Gtk3::Label->new( _( 'View or delete previous results' ) );
    $label->set_alignment( 0.0, 0.5 );
    $box->pack_start( $label, FALSE, FALSE, 0 );

    my $grid = Gtk3::Grid->new();
    $box->pack_start( $grid, FALSE, FALSE, 5 );
    $grid->set_column_spacing( 10 );
    $grid->set_column_homogeneous( FALSE );
    $grid->set_row_spacing( 10 );
    $grid->set_row_homogeneous( TRUE );

    $model = Gtk3::ListStore->new( 'Glib::String' );

    $combobox = Gtk3::ComboBox->new_with_model( $model );
    $combobox->set_hexpand( TRUE );
    $grid->attach( $combobox, 0, 0, 1, 1 );
    my $render = Gtk3::CellRendererText->new;
    $combobox->pack_start( $render, TRUE );
    $combobox->add_attribute( $render, text => 0 );
    read_files();

    my $separator = Gtk3::SeparatorToolItem->new;
    $separator->set_draw( FALSE );
    $grid->attach( $separator, 1, 0, 1, 1 );

    my $button = Gtk3::ToolButton->new();
    $button->set_icon_name( 'text-x-preview' );
    $button->set_tooltip_text( _( 'View file results' ) );
    $grid->attach( $button, 2, 0, 1, 1 );
    $button->signal_connect(
        clicked => sub {
            # my $file = $combobox->get_active_text;
            my $iter = $combobox->get_active_iter();
            return unless ( $model->iter_is_valid( $iter ) );
            my $file = $model->get_value( $iter, 0 );
            return unless ( $file );
            my $file_to_use = '';
            my $files       = read_files();

            # Written so as to not choke older Perls
            for my $key ( sort @$files ) {
                if ( $key->{ basefilepath } eq $file ) {
                    $file_to_use = $key->{ readpath };
                }
            }

            # For some reason, we'll use csv files
            my $csv = Text::CSV->new( { binary => 1, eol => "\n" } )
                or do {
                warn "Unable to begin Text::CSV: $!\n";
                return;
                };

            open( my $f, '<:encoding(utf8)', $file_to_use ) or do {
                warn "Unable to opening VT CSV file: $!\n";
                # popup( _( 'Error opening VT CSV file' ) );
                return;
            };
            # File, Hash, Date
            my $fields;
            my $counter = 0;
            while ( my $row = <$f> ) {
                chomp( $row );
                next if ( $row =~ /^#/ );
                next if ( $row =~ /^\s*$/ );
                if ( $csv->parse( $row ) ) {
                    $fields->[ $counter ] = [ $csv->fields() ];
                    $counter++;
                }
            }
            close( $f );
            $store->clear;

            #<<<
            # Written so as to not choke older Perls
            for my $v ( sort @{ $fields } ) {
                my $iter = $store->append;
                $store->set(
                    $iter,
                    VENDOR, $v->[0],
                    RESULT, $v->[1],
                    DATE, $v->[2],
            );
            #>>>
            }
            $nb->show_all;
            $nb->set_current_page( 1 );
        }
    );

    $button = Gtk3::ToolButton->new();
    $button->set_icon_name( 'edit-delete' );
    $button->set_tooltip_text( _( 'Delete file results' ) );
    $grid->attach( $button, 3, 0, 1, 1 );
    $button->signal_connect(
        clicked => sub {
            my $file = $combobox->get_active_text;
            return unless ( $file );
            my $file_to_use = '';
            my $active_text = $combobox->get_active_text;
            my $active_iter = $combobox->get_active;
            my $files       = read_files();

            # This has to be written a certain way so
            # that older Perls don't $choke
            for my $key ( sort @{ $files } ) {
                if ( $key->{ basefilepath } eq $file ) {
                    $file_to_use = $key->{ readpath };
                    if ( -e $file_to_use ) {
                        unlink( $file_to_use ) or do {
                            warn "Unable to delete VT $file_to_use: $!\n";
                            return;
                        };
                        $combobox->set_active( -1 );
                    }
                    read_files();
                    # we're done!
                    last;
                }
            }
        }
    );

    return $box;
}

sub read_files {
    my $submit_dir = ClamTk::App->get_path( 'submit' );
    my $results;

    $model->clear;

    my $arr_count = 0;
    # Grab all files
    for my $f ( glob "$submit_dir/*" ) {
        my $basename = basename( $f );
        # Might be other garbage in the folder; just
        # look for ones that look like hashes
        next unless ( length $basename == 64 );
        $results->[ $arr_count ]->{ readpath } = $f;
        $results->[ $arr_count ]->{ hash }     = basename( $f );
        open( my $t, '<:encoding(utf8)', $f ) or do {
            warn "Unable to open analysis file >$f<: $!\n";
            next;
        };
        while ( <$t> ) {
            chomp;
            if ( /^# File (.*?)$/ ) {
                $results->[ $arr_count ]->{ filepath } = $1;
                $results->[ $arr_count ]->{ basefilepath }
                    = basename( $1 );
                $model->set( $model->append, 0,
                    basename( $results->[ $arr_count ]->{ filepath } ) );
                last;
            }
        }
        close( $t );
        $arr_count++;
    }
    return $results;
}

sub check_for_existing {
    # First, set the infobar so the
    # user knows something is happening:
    set_infobar_mode( _( 'Please wait...' ) );
    $window->queue_draw;

    my $file = shift;
    my $url  = 'https://www.virustotal.com/vtapi/v2/file/report';

    my $local_tk_version = ClamTk::App->get_TK_version();

    my $hash = get_hash( $file );

    my $ua = add_ua_proxy();

    #<<<
    my @req = (
        $url,
        [
            resource => $hash,
            apikey   => getapi(),
        ]
    );
    #>>>

    set_infobar_mode( ' ' );
    # $new_window = switch to results tab
    my $new_window = TRUE;
    # $is_error = connection (or other) issue
    my $is_error = FALSE;

    my $response = $ua->post( @req );
    # warn "is_err = >", $response->is_error, "<\n";

    my $data;
    if ( $response->is_success ) {
        my $json = JSON->new->utf8->allow_nonref;
        eval { $data = $json->decode( $response->decoded_content ); };
        if ( $@ ) {
            warn "error reading/decoding json: $@\n";
            $new_window              = FALSE;
            $is_error                = TRUE;
            $data->{ response_code } = -4;
            return ( $data->{ response_code }, $new_window, $is_error );
        }
        # warn "response_code from submission >", $data->{ response_code },
        #    "<\n";
        # Response codes:
        # 0 = not present in dataset
        # -2 = queued for analysis
        # 1 = present and can be retrieved
        if ( $data->{ response_code } == 1 ) {
            # $return = $data->{ positives } . ' / ' . $data->{ total };
            for my $mark ( $data->{ scans } ) {
                while ( my ( $vendor, $v ) = each %$mark ) {
                    my $iter = $store->append;
                    #<<<
                    $store->set(
                        $iter,
                        VENDOR, $vendor,
                        RESULT,
                        ( $v->{ result } )
                        ? $v->{ result }
                        : '---',
                        DATE, $v->{ update },
                    );
                    #>>>
                }
            }
        } elsif ( $data->{ response_code } == 0 ) {
            # $return     = _( 'No information on this file' );
            $new_window = FALSE;
            $is_error   = FALSE;
        } elsif ( $data->{ response_code } == -2 ) {
            # $return     = _( 'File is pending analysis' );
            $new_window = FALSE;
            $is_error   = FALSE;
        } else {
            # $return     = _( 'An unknown error occurred' );
            $data->{ response_code } = -4;
            $new_window              = FALSE;
            $is_error                = TRUE;
        }
    } else {
        $data->{ response_code } = -4;
        $new_window              = FALSE;
        $is_error                = TRUE;
        warn "Unable to connect in submission: ", $response->status_line,
            "\n";
    }
    set_infobar_mode( ' ' );
    return ( $data->{ response_code }, $new_window, $is_error );
}

sub submit_new {
    # First, set the infobar so the user knows
    # something is happening:
    set_infobar_mode( _( 'Please wait...' ) );
    $window->queue_draw;
    my $url = 'https://www.virustotal.com/vtapi/v2/file/scan';

    my $ua               = add_ua_proxy();
    my $local_tk_version = ClamTk::App->get_TK_version();

    my $u_filename = encode( 'UTF-8', $filename );

    #<<<
    my $response = $ua->post(
        $url,
            Content_Type => 'multipart/form-data',
            Content => [
                    apikey   => getapi(),
                    file     => [ $u_filename ]
                    #file     => [ $filename ]
            ],
    );
    #>>>

    set_infobar_mode( ' ' );
    $bar->show_all;
    $window->queue_draw;

    if ( $response->is_success ) {
        # Save off the results; might use them later
        my $file = ClamTk::App->get_path( 'virustotal_links' );
        my $hash = get_hash( $filename );

        my $json_text = $response->decoded_content;
        my $data      = $response->as_string;
        my $json_hash = decode_json( $json_text );

        open( my $f, '>>:encoding(UTF-8)', $file );
        # or warn "Unable to save virustotal results: $!\n";
        my $csv = Text::CSV->new( { binary => 1, eol => "\n" } );
        my $ref;
        $ref->[ 0 ] = [ $filename, $hash, $json_hash->{ permalink } ];
        $csv->print( $f, $_ ) for ( @$ref );
        close( $f );

        popup( _( 'File successfully submitted for analysis.' ) );
    } else {
        popup( _( 'Unable to submit file: try again later' ) );
    }
}

sub getapi {
    #<<<
    return decode_base64(
              'MDMwNmU3MT'
            . 'ZjYjQxNTMz'
            . 'OWFkZDQ5ND'
            . 'JkOTg4ZWVm'
            . 'MDU3MjlmND'
            . 'AxYmM0NjIw'
            . 'MjZmNDQ2OD'
            . 'gzYjcxNmIy'
            . 'NTAxZg=='
    );
    #>>>
}

sub get_hash {
    my ( $file ) = shift;

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

sub save_file {
    # VENDOR, RESULT, DATE
    # temporary filename
    my $hash = get_hash( $filename );
    my $file = ClamTk::App->get_path( 'submit' ) . '/' . $hash;

    my $ref;
    my $count = 0;

    $store->foreach(
        sub {
            my ( $liststore, $path, $iter ) = @_;
            my ( $vendor, $result, $date )
                = $liststore->get( $iter, 0, 1, 2 );
            $ref->[ $count ] = [ $vendor, $result, $date ];
            $count++;
            return FALSE;
        }
    );

    # For some reason, we'll use csv files
    my $csv = Text::CSV->new( { binary => 1, eol => "\n" } )
        or do {
        popup( _( 'Unable to save file' ) );
        return;
        };

    open( my $f, '>:encoding(utf8)', $file ) or do {
        popup( _( 'Unable to save file' ) );
        return;
    };
    print $f '# File', ' ', $filename, "\n";
    print $f '# Hash', ' ', $hash,     "\n";
    print $f '# Date', ' ', scalar localtime, "\n\n";
    $csv->print( $f, $_ ) for ( @$ref );
    close( $f );

    popup( _( 'File has been saved' ) );
    read_files();

    return TRUE;
}

sub popup {
    my ( $message, $option ) = @_;

    my $dialog = Gtk3::MessageDialog->new(
        undef,    # no parent
        [ qw| modal destroy-with-parent | ],
        'info',
        $option ? 'ok-cancel' : 'close',
        $message,
    );

    if ( 'ok' eq $dialog->run ) {
        $dialog->destroy;
        return TRUE;
    }
    $dialog->destroy;

    return FALSE;
}

sub set_infobar_mode {
    my $text = shift;

    for my $c ( $bar->get_content_area->get_children ) {
        if ( $c->isa( 'Gtk3::Label' ) ) {
            $c->set_text( $text );
            $bar->show_all;
            $window->queue_draw;
            return;
        }
    }

    # We don't have a Label, so make one:
    my $label = Gtk3::Label->new( $text );
    $label->set_use_markup( TRUE );
    $bar->get_content_area->add( $label );
    $bar->show_all;
    $window->queue_draw;

    return;
}

sub add_ua_proxy {
    my $agent = LWP::UserAgent->new( ssl_opts => { verify_hostname => 1 } );

    my $local_tk_version = ClamTk::App->get_TK_version();
    $agent->agent( "ClamTk/$local_tk_version" );
    $agent->timeout( 60 );

    $agent->protocols_allowed( [ 'http', 'https' ] );

    if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) ) {
        if ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 1 ) {
            $agent->env_proxy;
        } elsif ( ClamTk::Prefs->get_preference( 'HTTPProxy' ) == 2 ) {
            my $path = ClamTk::App->get_path( 'db' );
            $path .= '/local.conf';
            my ( $url, $port );
            if ( -e $path ) {
                if ( open( my $FH, '<', $path ) ) {
                    while ( <$FH> ) {
                        if ( /HTTPProxyServer\s+(.*?)$/ ) {
                            $url = $1;
                        }
                        last if ( !$url );
                        if ( /HTTPProxyPort\s+(\d+)$/ ) {
                            $port = $1;
                        }
                    }
                    close( $FH );
                    $agent->proxy( http  => "$url:$port" );
                    $agent->proxy( https => "$url:$port" );
                    $ENV{ HTTPS_PROXY }                  = "$url:$port";
                    $ENV{ HTTP_PROXY }                   = "$url:$port";
                    $ENV{ PERL_LWP_SSL_VERIFY_HOSTNAME } = 0;
                    $ENV{ HTTPS_DEBUG }                  = 1;
                }
            }
        }
    }

    return $agent;
}

sub button_test {
    # So, this is a test to determine if set_filename works,
    # which is tested by seeing if we can get_filename.
    # Return TRUE if it succeeds so we can add the Analysis
    # button to the Results window.
    # Otherwise return FALSE, and don't draw it.
    my $fcb = Gtk3::FileChooserButton->new( 'just a test', 'open', );
    $fcb->set_filename( '/usr/bin/clamtk' );
    if ( $fcb->get_filename ) {
        return TRUE;
    } else {
        return FALSE;
    }
}

1;
