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
package ClamTk::Icons;

# use strict;
# use warnings;
# $| = 1;

sub get_image() {
    my ( $self, $wanted ) = @_;

    my $use_image = '';

    my %table;

    # These need to be scrubbed again
    # The gtk-apply in the left column is because it works and
    # the newer names (e.g., emblem-ok) don't.
    $table{ 'system-run' }                 = 'gtk-apply';
    $table{ 'alarm' }                      = 'gtk-properties';
    $table{ 'document-new' }               = 'gtk-file';
    $table{ 'document-print' }             = 'gtk-print';
    $table{ 'gtk-preferences' }        = 'gtk-preferences';
    $table{ 'document-save' }              = 'gtk-apply';
    $table{ 'document-save-as' }           = 'gtk-save-as';
    $table{ 'document-send' }              = 'gtk-index';
    $table{ 'edit-delete' }                = 'gtk-delete';
    $table{ 'edit-find' }                  = 'gtk-find';
    $table{ 'edit-select' }                = 'gtk-find';
    $table{ 'edit-undo' }                  = 'gtk-undelete';
    $table{ 'emblem-important' }           = 'gtk-no';
    $table{ 'folder-documents' }           = 'gtk-directory';
    $table{ 'go-previous' }                = 'gtk-go-back';
    $table{ 'help-about' }                 = 'gtk-about';
    $table{ 'image-missing' }              = 'gtk-missing-image';
    $table{ 'list-add' }                   = 'gtk-add';
    $table{ 'list-remove' }                = 'gtk-remove';
    $table{ 'media-playback-start' }       = 'gtk-yes';
    $table{ 'preferences-system' }         = 'gtk-preferences';
    $table{ 'preferences-system-network' } = 'gtk-network';
    $table{ 'process-stop' }               = 'gtk-cancel';
    $table{ 'security-high' }              = 'gtk-new';
    $table{ 'software-update-available' }  = 'gtk-ok';
    $table{ 'system-help' }                = 'gtk-about';
    $table{ 'system-lock-screen' }         = 'gtk-refresh';
    $table{ 'system-search' }              = 'gtk-find';
    $table{ 'text-x-preview' }             = 'gtk-select-all';
    $table{ 'user-trash-full' }            = 'gtk-refresh';
    $table{ 'view-list' }                  = 'gtk-edit';
    $table{ 'window-close' }               = 'gtk-close';

    my $theme = Gtk3::IconTheme::get_default();

    if ( exists $table{ $wanted } ) {
        if ( $theme->has_icon( $wanted ) ) {
            $use_image = $wanted;
        } elsif ( $theme->has_icon( $table{ $wanted } ) ) {
            $use_image = $table{ $wanted };
        } else {
            if ( $theme->has_icon( 'image-missing' ) ) {
                $use_image = 'image-missing';
            } else {
                $use_image = $table{ 'image-missing' };
            }
        }
    } else {
        if ( $theme->has_icon( 'image-missing' ) ) {
            $use_image = 'image-missing';
        } else {
            $use_image = $table{ 'image-missing' };
        }
    }
    return $use_image;
}

1;
