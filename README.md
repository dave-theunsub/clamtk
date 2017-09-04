This readme file was last updated on 18 February 2017

# Readme for ClamTk

**Table of contents:**

1. [About](#about)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Plugins](#plugins)
5. [Troubleshooting](#troubleshooting)
6. [Contributing](#contributing)
7. [Other](#other)
8. [Thank you](#thank-you)
9. [Contact](#contact)


## About

ClamTk is a frontend for ClamAV (Clam Antivirus). It is intended to be an easy to use, light-weight, on-demand scanner for Linux systems. It has been ported to Fedora, Debian, RedHat, openSUSE, ALT Linux, Ubuntu, CentOS, Gentoo, Archlinux, Mandriva, PCLinuxOS, Frugalware, FreeBSD, and others.

Although its earliest incarnations date to 2003, ClamTk was first uploaded for distribution in 2004 to a rootshell.be account and finally to Sourceforge.net in 2005. At the end of 2013, we moved to a Google Code page (then to github), gitlab, and Bitbucket. It's now 2017 and for some reason, it's still going.  In fact, February 2017 marks 13 years of activity (of being publically available, that is).


### Important Links

ClamTk:
* https://dave-theunsub.github.io/clamtk/
* https://gitlab.com/dave_m/clamtk
* https://github.com/dave-theunsub/clamtk/
* https://bitbucket.org/davem_/clamtk/
* https://code.google.com/p/clamtk/ (not used anymore)
* http://clamtk.sourceforge.net (not used anymore)

Launchpad ClamTk:
* https://launchpad.net/clamtk

ClamAV:
* http://www.clamav.net

Gtk2-Perl:
* http://gtk2-perl.sourceforge.net

Virustotal:
* https://virustotal.com


## Installation

### RPMs
The easiest way to install ClamTk is to use the rpms. Note: The `dnf` (which is now used by Fedora) command instructions are the same as the `yum` instructions below (just switch out `yum` for `dnf` if that's what your system is using):  
  
First, try `yum install clamtk`. If this does not work,
download it and try:  

`# yum install clamtk*.rpm`

To remove clamtk:  
  
`# yum erase clamtk`

### Source
Warning: Don't do this. It's much easier to just double-click a .deb or .rpm. Really, put down the source. The tarball contains all the sources. One way to do this on Fedora:
```
# mkdir -p /usr/share/perl5/vendor_perl/ClamTk
# cp lib/*.pm /usr/share/perl5/vendor_perl/ClamTk
# chmod +x clamtk
# cp clamtk /usr/local/bin (or /usr/bin)
```

Examples:

    $ perl clamtk

or

    $ chmod +x /path/to/clamtk
    $ /path/to/clamtk

* Note: If you have installed this program as an rpm or .deb, you do not need to take these steps.
* Note: Did you get errors with this? Check the TROUBLESHOOTING section at the end.

### DEBs

You should be able to just double-click the .deb file to install it. This assumes you have permissions to install programs, of course. Your package manager should grab any necessary dependencies.

By the commandline, you can do this:  

    # dpkg -i clamtk-*.deb

To remove clamtk:  

    # dpkg --purge clamtk

Note that the Debian/Ubuntu builds are and have always been gpg-signed.

### Integrity

It is recommended you install ClamTk from official repositories. Check your distribution first, and always install from trusted sources.

While the Debian/Ubuntu .debs have always been digitally signed, the rpms have not. Beginning with 5.22, you can once again check the rpm's signature to verify its integrity. Here's one way:

1. Get and import the key in one step: `rpm --import https://davem.fedorapeople.org/RPM-GPG-KEY-DaveM-10-Sept-2016`
2. Verify the list of gpg keys installed in RPM DB: `rpm -q gpg-pubkey --qf '%{name}-%{version}-%{release} --> %{summary}\n'`
3. Check the signature of the rpm. For this example, we'll use version 5.22: `rpm --checksig clamtk-5.22-1.fc.noarch.rpm`
4. You should see something like this: `/home/you/clamtk-5.22-1.fc.noarch.rpm: rsa sha1 (md5) pgp md5 OK`

You can also verify the tarball. Using 5.22 as the example version, ensure you have downloaded the tarball, its detached signature (.asc), and the key in step 1 above.

1. Get the key (skip if you already have it): `wget https://davem.fedorapeople.org/RPM-GPG-KEY-DaveM-10-Sept-2016`
2. Import it (skip if you have done it already): `gpg --import RPM-GPG-KEY-DaveM-10-Sept-2016`
3. Verify `gpg2 --verify clamtk-5.22.tar.gz.asc clamtk-5.22.tar.gz` or `gpg --verify clamtk-5.22.tar.gz.asc clamtk-5.22.tar.gz`
4. You should see something like this: `gpg: Signature made Sun 11 Sep 2016 06:29:41 AM CDT using RSA key ID` (snipped for brevity)


## Usage

### Running ClamTk

* Beginning with version 4.23, ClamTk will automatically search for signatures if you do not have them set already. This way ClamTk should work right out of the box, with no prompting.
* Consider the extra scanning options in Settings.
  * Select "Scan files beginning with a dot (.*)" to scan those files beginning with a ".".  These are sometimes referred to as "hidden" files.
  * Select "Scan directories recursively" to scan all files and directories within a directory.
  * The "Scan for PUAs" option enables the ability to scan for Potentially Unwanted Applications as well as broken executables.  Note that this can result in what may be false positives.
  * By default, ClamTk will avoid scanning files larger than 20MB. To force scanning of these files, check the "Scan files larger than 20 MB" box.
  * You can also check for updates upon startup.  This requires an active Internet connection.
* Information on items quarantined is available under the "Quarantine" option.  If you believe there is a false positive contained, you can easily move it back to your home directory. You may also delete this file(s). Note that there is no recycle bin - once deleted, they are gone forever.
* Scan a file or directory by right-clicking on it within the file manager (e.g., Nautilus).  This functionality requires an extra package (clamtk-gnome).
* You can STOP the scan by clicking the Cancel button. Note that due to the speed of the scanning, it may not stop immediately; it will continue scanning and displaying files it has already "read" until the stop catches up.
* View previous scans by selecting "History".
* The Update Assistant is necessary because some systems are set up to do automatic updates, while others must manually update them.
* If you require specific proxy settings, select "Network".
* As of version 5.xx, you can use the "Analysis" button to see if a particular file is considered malicious by other antivirus products. This uses results from Virustotal. If you desire, you can submit a file for further review. Please do *not* submit personal files.
* The "Whitelist" option provides the ability to skip specific directories during scan time. For example, you may wish to skip directories containing music or videos.

### Commandline

ClamTk can run from the commandline, too:

    $ clamtk file_to_be_scanned

or

    $ clamtk directory_to_be_scanned

However, the main reason for the commandline option (however basic) is to allow for right-click scanning within your file manager (e.g., Nautilus or Dolphin).  If you want more extensive commandline options, it is recommended that you use the clamscan binary itself. (Type `man clamscan` at the commandline.) Or, if you know of something useful, let me know and I can add it as an option.

### Afterwards

You can view and delete scan logs by selecting the "History" option.

You also have a few options with the files displayed. Click on the file scanned to select it, then right-click: you should have four options there.

* Quarantine this file: This drops the selected file into a "quarantined" folder with the executable bit removed. The quarantine folder is held in the user's ClamTk folder (`~/.clamtk/viruses`).
* Delete this file: Be careful: There's no recycle bin!
* Cancel: Cancels this menu.

### Quarantine/Maintenance

If you've quarantined files for later examination, you have the option to restore them to their previous location (if known), or delete them.


## Plugins

To add a right-click, context menu ability to send files and directories to the scanner, install the appropriate plugin. Links to the latest versions are available here: http://dave-theunsub.github.io/clamtk/

Here are the specific pages:
* For Gnome (Files file manager): https://github.com/dave-theunsub/clamtk-gnome
* For KDE (Dolphin file manager): https://github.com/dave-theunsub/clamtk-kde
* For XFCE (Thunar file manager): https://github.com/dave-theunsub/thunar-sendto-clamtk
* For MATE (Nemo file manager): https://github.com/dave-theunsub/nemo-sendto-clamtk


## Troubleshooting

* Are your signatures up to date, but ClamTk says they're not?

  You probably have more than one virus signature directory. See below answer for finding signatures.

* If you are getting an error that ClamTk cannot find your signatures:

  ClamTk is trying to find its virus definitions. Typically these are held under /var/lib/clamav or /var/clamav or ... If you are sure these files exist, please find their location and send it. Try the following to determine their location:

  1. `find /var -name "daily.cvd" -print`
  2. `find /var -name "daily.cld" -print`

* Are you using the source and you see something like this: Can't locate Foo/Bar.pm in @INC... (etc, etc).

  This means you are missing some of the dependencies. Try to find the dependency through your distribution's repositories, or simply go to http://search.cpan.org. Always try your distribution's repo first. It's more than likely your distribution already packages these for easy installation. Depending on your distro, you will likely use "yum" or "apt" or some "Update Manager" and the like.

* I can't right click on files/directories to scan anymore!

  That's because we no longer bundle this functionality.  Not everyone uses Gnome.  There are add-ons for XFCE, KDE, Mate, and Gnome - they're small packages, easy to install, and will bring that functionality back.

### Limitations/Bugs

Probably a lot. Let me know, please. Ranting on some bulletin board somewhere on one of dozens of Linux sites will not improve things. See the section below for contact info.


## Contributing

### Locale/Internationalization

Version 2.20 is the first ClamTk version to offer this. Have time on your hands and want to contribute? See the Launchpad page at https://launchpad.net/clamtk

Note that some builds do not account for other than English languages because they have not yet updated their build/spec files. A polite email to the respective maintainer may fix this.


## Other

As of version 3.10, ClamTk will not scan standard mail directories, such as .evolution, .mozilla or .thunderbird. This is due to parsing problems. If a smart way of doing that comes up, it will be added.

Also, please note that version numbers mean absolutely nothing. There is no rhyme or reason to odd or even numbers (i.e., an odd number does not mean "unstable"). A new version means it goes up 1 (or, rather, .01). Version 6.xx, still in development, will likely use the Gtk3 libraries.

### GUI

ClamTk started out using the Tk libraries (thus its name). In 2005, this was changed to perl-Gtk2 (or Gtk2-perl, whatever). The Tk version is still available on sourceforge.net but has not been updated for some time now and should not be used.

The plan for the 5.xx series was to use Gtk3. Unfortunately, Debian and Ubuntu do not have a recent version of libgtk3-perl, and CentOS does not have perl-Gtk3 at all and reportedly never will. So, at the last second, the 5.00 version was rewritten to use Gtk2. Again.


## Thank you

Many people have contributed their time, energy, opinions, recommendations, and expertise to this software. I cannot thank them enough. Their names are listed in the [credits.md file](credits.md)

Also a big thank you to:
* Everyone who has contributed in one way or another to ClamTk - including language files, bug notifications, and feature requests
* Dag, without whom rpms would likely not exist
* All the gtk2-perl and gtk3-perl folks for their time and effort
* Perlmonks.org for helping me learn the wonderful Perl language - and continuing to do so on a daily basis!
* Ksnapshot for making snapshot-taking very easy


## Contact

For feature requests or bugs, it's best to use one of the following:
* https://github.com/dave-theunsub/clamtk/issues
* https://launchpad.net/clamtk

While we recommend opening an official bug on the appropriate page, we'll also accept emails:

* Dave M, dave.nerd AT gmail DOT com (0x6ADA59DE)
