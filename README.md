This README was last updated on 18 October 2020.

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

ClamTk is a frontend for ClamAV (Clam Antivirus). It is intended to be an easy to use, light-weight, on-demand scanner for Linux systems.

Although its earliest incarnations date to 2003, ClamTk was first uploaded for distribution in 2004 to a rootshell.be account and finally to Sourceforge.net in 2005. At the end of 2013, it was moved to a Google Code page (then to Github), then Gitlab and Bitbucket. It is now 2020 and for some reason, development is still going. In fact, February 2020 marks 16 years of activity (of being publicly available, that is).


## Plans

Version 7 will likely have a new design, and will almost certainly use a different language.  

### Important Links

ClamTk:  
https://gitlab.com/dave_m/clamtk-gtk3/  
https://bitbucket.org/davem_/clamtk-gtk3/  
https://gitlab.com/dave_m/clamtk/wikis/home  
https://launchpad.net/clamtk  
https://code.google.com/p/clamtk/ (deprecated)  
http://clamtk.sourceforge.net (deprecated)  
https://dave-theunsub.github.io/clamtk/ (deprecated)  
https://github.com/dave-theunsub/clamtk/ (deprecated)  

[ClamAV](https://www.clamav.net)  
[Gtk2-Perl](http://gtk2-perl.sourceforge.net)  
[Gtk3](https://developer.gnome.org/gtk3/stable/index.html)  
[Virustotal](https://virustotal.com)  


## Installation  

### RPMs  
The easiest way to install ClamTk is to use the rpms. The commands `dnf` and `yum` will pull in requirements.   

First, start with the official repositories.

`sudo yum install clamtk` or `sudo dnf install clamtk`.  

If this does not work, download the file from [the official site](https://gitlab.com/dave_m/clamtk/-/wikis/Home). You should be able to just double click the file for installation or upgrade.

For these examples, we will use version 6.06. The name of the file may differ based on your distribution.

To install using a terminal window:  

`sudo yum install clamtk-6.06-1.el8.noarch.rpm` or `sudo dnf install clamtk-6.06-1.fc.noarch.rpm`

To remove clamtk:  

`sudo yum erase clamtk` or `sudo dnf erase clamtk`.

### Source  
**Warning**: Don't do this. It's much easier to just double click a .deb or .rpm. Really, put down the source. 

The tarball contains all the sources. One way to do this, as tested on Fedora, is to run the following commands:  

```
tar xzf clamtk-6.06.tar.xz  
sudo mkdir -p /usr/share/perl5/vendor_perl/ClamTk  
sudo cp lib/*.pm /usr/share/perl5/vendor_perl/ClamTk  
sudo chmod +x clamtk  
sudo cp clamtk /usr/local/bin (or /usr/bin)  
```

Examples:

    $ perl clamtk

or

    $ chmod +x /path/to/clamtk
    $ /path/to/clamtk

* Note: If you have installed this program as an rpm or .deb, you do not need to take these steps.
* Note: Did you get errors with this? Check the TROUBLESHOOTING section at the end.

### DEBs

You should be able to just double click the .deb file to install it. Your package manager should retrieve any necessary dependencies.

From the commandline, you can do this:  

    sudo apt install clamtk

If you downloaded the file, then use this:

    sudo apt install clamtk_6.06-1_all.deb

To remove clamtk:  

    sudo dpkg --purge clamtk

Note that the Debian/Ubuntu builds are and always have been gpg-signed.

### Integrity

It is recommended you install ClamTk from official repositories. Check your distribution first, and always install from trusted sources.

While the Debian/Ubuntu .debs have always been digitally signed, the rpms have not. Beginning with 5.22, you can once again check the rpm's signature to verify its integrity. Here's one way:

1. Get and import the key in one step:  
`rpm --import https://davem.fedorapeople.org/RPM-GPG-KEY-DaveM-21-June-2018`  
2. Verify the list of gpg keys installed in RPM DB:  
`rpm -q gpg-pubkey --qf '%{name}-%{version}-%{release} --> %{summary}\n'`  
3. Check the signature of the rpm. For this example, we'll use version 6.06:  
`rpm --checksig clamtk-6.06-1.fc.noarch.rpm`  
4. You should see something like this:  
`/home/you/clamtk-6.06-1.fc.noarch.rpm: rsa sha1 (md5) pgp md5 OK`

You can also verify the tarball. Using 6.06 as the example version, ensure you have downloaded the tarball, its detached signature (.asc), and the key in step 1 above.

1. Get the key (skip this step if you already have it):  
`wget https://davem.fedorapeople.org/RPM-GPG-KEY-DaveM-21-June-2018`  
2. Import it (skip this step if you have done it already):  
`gpg --import RPM-GPG-KEY-DaveM-21-June-2018`  
3. Verify like so:  
`gpg2 --verify clamtk-6.06.tar.xz.asc clamtk-6.06.tar.gz` or  
`gpg --verify clamtk-6.06.tar.xz.asc clamtk-6.06.tar.xz`  
4. You should see something like this:  
`gpg: Signature made Sun 11 Sep 2016 06:29:41 AM CDT using RSA key ID` (snipped for brevity).  

You can now use minisign, too!  
[Minisign](https://jedisct1.github.io/minisign/)  

First, you will need my public minisign key:  
[Public minisign key](https://davem.fedorapeople.org/davemminisign.pub)  

Then, you will need the minisig file for the program you are verifying.  

A link to it will be with the rest of the downloads. 

For this example:  
https://bitbucket.org/davem_/clamtk-gtk3/downloads/clamtk-6.06.tar.xz.minisig

Now, you verify like so:  
```
minisign -V -x clamtk-6.06.tar.xz.minisig -p davemminisign.pub -m clamtk-6.06.tar.xz
```


## Usage

### Running ClamTk

* Beginning with version 4.23, ClamTk will automatically search for signatures if you do not have them set already. This way ClamTk should work right out of the box, with no prompting.  
* Consider the extra scanning options in Settings.
  * Select "Scan files beginning with a dot (.*)" to scan those files beginning with a ".".  These are sometimes referred to as "hidden" files.  
  * Select "Scan directories recursively" to scan all files and directories within a directory.  
  * The "Scan for PUAs" option enables the ability to scan for Potentially Unwanted Applications as well as broken executables.  Note that this can result in what may be false positives.  
  * By default, ClamTk will avoid scanning files larger than 20MB. To force scanning of these files, check the "Scan files larger than 20 MB" box.  
  * You can also check for updates upon startup.  This requires an active Internet connection.  
* Information on items quarantined is available under the "Quarantine" option.  If you believe there is a false positive contained, you can easily move it back to your home directory. You may also delete this file(s). *Note that there is no recycle bin - once deleted, they are gone forever.*    
* Scan a file or directory by right-clicking on it within the file manager (e.g., Nautilus).  This functionality requires an extra package (clamtk-gnome).
* You can STOP the scan by clicking the Cancel button. Note that due to the speed of the scanning, it may not stop immediately; it will continue scanning and displaying files it has already "read" until the stop catches up.  
* View previous scans by selecting "History".  
* The Update Assistant is necessary because some systems are set up to do automatic updates, while others must manually update them.  
* If you require specific proxy settings, select "Network".  
* As of version 5.xx, you can use the "Analysis" button to see if a particular file is considered malicious by other antivirus products. This uses results from Virustotal. If you desire, you can submit a file for further review. Please do *not* submit personal files.  
* The "Whitelist" option provides the ability to skip specific directories during scan time. For example, you may wish to skip directories containing music or videos.  

### Commandline

ClamTk can run from the commandline, too:  
```  
clamtk file_to_be_scanned  
```
or  
```
clamtk directory_to_be_scanned  
```

The main reason for the commandline option (however basic) is to allow for right-click scanning within your file manager (e.g., Files, Caja, or Dolphin).  If you require more extensive commandline options, it is recommended that you use the clamscan executable itself. (Type `man clamscan` at the commandline.)  

### Afterwards

You can view and delete scan logs by selecting the "History" option.  

You also have a few options with the files displayed. Click on the file scanned to select it, then right-click: you should have four options there.  

* Quarantine this file: This drops the selected file into a "quarantined" folder with the executable bit removed. The quarantine folder is held in the user's ClamTk folder (`~/.clamtk/viruses`).  
* Delete this file: Be careful: There is no recycle bin!  
* Cancel: Cancels this menu.  

### Quarantine/Maintenance

If you've quarantined files for later examination, you have the option to restore them to their previous location (if known), or delete them.


## Plugins

To add a right-click, context menu ability to send files and directories to the scanner, install the appropriate plugin. Links to the latest versions are available here:  

https://gitlab.com/dave_m/clamtk/wikis/Downloads  

Here are the specific pages:  

For Gnome (Files file manager):  
https://gitlab.com/dave_m/clamtk-gnome  

For KDE (Dolphin file manager):  
https://gitlab.com/dave_m/clamtk-kde  

For XFCE (Thunar file manager):  
https://gitlab.com/dave_m/thunar-sendto-clamtk  

For Mate (Nemo file manager):  
https://gitlab.com/dave_m/nemo-sendto-clamtk  


## Troubleshooting

* Are your signatures up to date, but ClamTk says they're not?

  You probably have more than one virus signature directory. See below answer for finding signatures.

* If you are getting an error that ClamTk cannot find your signatures:

  ClamTk is trying to find its virus definitions. Typically these are held under /var/lib/clamav or /var/clamav or ... If you are sure these files exist, please find their location and send it. Try the following to determine their location:

  1. `find /var -name "daily.cvd" -print`
  2. `find /var -name "daily.cld" -print`

* Are you using the source and you see something like this: Can't locate Foo/Bar.pm in @INC... (etc, etc).

  This means you are missing some of the dependencies. Try to find the dependency through your distribution's repositories, or simply go to [CPAN](https://metacpan.org/). Always try your distribution's repository first. It is more than likely your distribution already packages these for easy installation. Depending on your distro, you will likely use `yum`, `dnf`, `apt` or some "Update Manager" and the like.

* I can't right click on files/directories to scan anymore!

  That's because we no longer bundle this functionality.  Not everyone uses Gnome.  There are add-ons for XFCE, KDE, Mate, and Gnome - they're small packages, easy to install, and contain that functionality.

### Limitations/Bugs

Probably a lot. Let me know, please. Ranting on some bulletin board somewhere on one of dozens of Linux sites will not fix bugs or improve the program. See the section below for contact info.


## Contributing

### Locale/Internationalization

ClamTk has supported multiple languages for many years now. Have time on your hands and want to contribute? See the [Launchpad page](https://launchpad.net/clamtk).

Note that some builds do not account for other than English languages because they have not yet updated their build/spec files. A polite email to the respective maintainer may fix this.


## Other

As of version 3.10, ClamTk will not scan standard mail directories, such as .evolution, .mozilla or .thunderbird. This is due to parsing problems. If a smart way of doing that comes up, it will be added.

Also, please note that version numbers mean absolutely nothing. There is no rhyme or reason to odd or even numbers (i.e., an odd number does not mean "unstable"). A new version means it goes up 1 (or, rather, .01).  

### GUI

ClamTk started out using the Tk libraries (thus its name). In 2005, this was changed to perl-Gtk2 (or Gtk2-perl, whatever). The Tk version is still available on sourceforge.net but has not been updated for some time now and should not be used.

The plan for the 5.xx series was to use Gtk3. Unfortunately, Debian and Ubuntu did not have a recent version of libgtk3-perl, and CentOS did not have perl-Gtk3. So, at the last second, the 5.00 version was rewritten to use Gtk2. Again.

Version 6.xx has been written to use Gtk3, as Gtk2 is deprecated. There's no new design this time, as this was an effort to ensure the Gtk3 version could be included in upcoming distribution releases (such as with Debian). The 6.xx series is in its own git repository (usually clamtk-gtk3), so that the older 5.xx series will still be there for distributions that do not have Gtk3.

Version 7.xx will likely have a new design, and may be written in a different language as well.

And there's also a Gtk4 in the works...


## Thank you

Many people have contributed their time, energy, opinions, recommendations, and expertise to this software. I cannot thank them enough. Their names are listed in the credits file.

Also a big thank you to:
* Everyone who has contributed in one way or another to ClamTk - including language files, bug notifications, and feature requests
* Dag, without whom rpms would likely not exist
* All the gtk2-perl and gtk3-perl folks for their time and effort
* [Perlmonks](https://perlmonks.org)


## Contact

For feature requests or bugs, it is best to use one of the following:  

[https://gitlab.com/dave_m/clamtk/issues](https://gitlab.com/dave_m/clamtk/issues)  
https://launchpad.net/clamtk  

While we recommend opening an official bug on the appropriate page, we will also accept email.   

* Dave M, dave.nerd @gmail.com [0xF51D19546ADA59DE](https://pgp.circl.lu/pks/lookup?op=get&search=0xF51D19546ADA59DE)  
* Tord D, tord.dellsen @gmail.com  