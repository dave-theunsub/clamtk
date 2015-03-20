# Ubuntu 12.04 is supported - as of version 5.04 #

From my research, the perl-Gtk2 version needs to be at least 1.241.

If you are using an old Ubuntu - like 12.xx - use the legacy deb.

# I'm using Kubuntu (or KDE), and ClamTk won't start. There is an error message "Icon 'gtk-new' not present" #

That's because unlike Ubuntu, Kubuntu does not have all the "built-in" gnome icons.  This should fix the problem:

```
sudo apt-get install gnome-icon-theme-full
```

I'll put this package in as a requirement for 5.02.

Contact me for assistance.