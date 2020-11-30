# sdm2subsurface
Perl script for processing CSV files output from very old versions of Suunto Dive Manager (SDM) and generating Subsurface-format XML. You will need an installation of Perl (available on pretty much all OS's - even Android!)

First export your logbook from SDM using "File->Export->ANSI in CSV Format", saving to 'logbook.CSV'

'cd' to the directory where the exported files are, and on the command-line:

perl sdm2subsurface.pl logbook

Output will be written to logbook.xml, which can then be opened in
Subsurface for checking.

Note the script assumes metric measurements and sensible dd/mm/yyyy format
dates. Comments in the script should provide guidance for local customisation.

Fields which the script can't map directly to Subsurface are saved at the end of the notes page. If you have used them intelligently, you might think about mapping them to tags instead. Equipment lists are saved in extradata fields.

Only time and depth are currently supported for the profile. Subsurface supports a lot more than that, and if you can work out what the fields saved from your dive computer are, you might add them. 

An option considered, but not implemented, was to group sequences of dives at the same "Location" under a single Subsurface "trip". However that assumes how you have used SDM, so I didn't bother.

Script is basic Perl, and should run under on any perl installation. It is tested with CSV files generated from SDM 1.6 (using data from a Suunto Gekko) and Perl 5.30.0 on Linux.
