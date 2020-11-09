# sdm2subsurface
Perl script for processing CSV files output from very old versions of Suunto Dive Manager and generating Subsurface-format XML. You will need n installation of Perl. This is only tested with perl 5.30.0

First export your logbook from SDM using File->Export->ANSI in CSV Format, saving to 'logbook.CSV'

On the command-line:

perl sdm2subsurface.pl logbook

Output will be written to logbook.xml, which can then be opened in
Subsurface for checking.

Note the script assumes metric measurements and sensible dd/mm/yyyy format
dates. Comments in the script should provide guidance for local customisation.

Fields which the script can't map directly to Subsurface are saved at the end of the notes page. If you have used them intelligently, you might think about mapping them to tags instead.