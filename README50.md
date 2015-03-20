README 5.00

This README deals with the changes from the 4.xx series to 5.xx.

Note that I am expecting a quick 5.01 release.  I'm assuming there will be bugs reported and new language updates pretty soon.  Don't be afraid to let me know about them.  Thank you in advance.

Big Changes

1. Interact with Virustotal

> Now, you can check a file's reputation from the view of dozens of security vendors.

> Here's how it works:  first, by selecting a file and submitting it, ClamTk sends a sha256sum of the file.  This saves bandwidth - after all, if it's already known, we might as well use that information.  If it has already been submitted and analyzed, you'll get the results right away.  If not, you will have the option to submit the entire file for analysis.  Just submit it again later for the results.

> WARNING:  Do **NOT** submit personal files or anything you would not want made public.  Files you would want to submit are (e.g.) file attachments you may have received or downloaded.

2. Right-click context menu support

> For Gnome users, ClamTk uses the magic of nautilus python to present an option to right-click on files or folders to scan for threats.  Note that this is not enabled for CentOS.

> We didn't leave KDE users out.  Download the clamtk-kde package, and you'll have the same kind of context menu action within Dolphin.

> And my favorite - XFCE - has a package of its own, with thunar-sendto-clamtk.

> Typically these are just desktop files that need to be plugged into a specific directory.  This means they're lightweight and easy to maintain.

3. Built-in documentation

> For 5.00, the documentation is solely in English.  I am eager to add other languages.

What didn't change

> One of the big changes was going to be upgrading to Gtk3.  This didn't happen because currently only Fedora (out of the major distros) had a usable version of perl-Gtk3.  Debian (and thus Ubuntu) has an old and not so usable version, and CentOS doesn't have it at all (yet?).

> I plan to upgrade to perl-Gtk3 anyway in the near future.

For packagers

> If you're packaging ClamTk for another distro or operating system, please take note of the dependency changes.  This includes - but is not limited to - the addition of LWP::Protocol::https, perl-JSON, and nautilus-python (unless you leave the nautilus portion out).  Feel free to contact me for any questions.

Dave M <dave dot nerd @ gmail dot com>, 09 Nov 2013