#!/bin/perl
# Convert CSV files written out from Suunto Dive Manager 1.6 to a
# Subsurface XML logbook.
#
# First export your logbook from SDM using File->Export->ANSI in CSV Format
# saving to 'logbook.CSV'
#
# On the command-line:
# C:> perl sdm2subsurface.pl logbook
#
# Output will be written to logbook.xml, which can then be opened in Subsurface for checking.
#
use Data::Dumper;
use Time::Piece;

# Columns seen in SDM output. Fields with a lowercase first character have
# an analog in Subsurface. Fields with upper case first character are
# added at the end of the notes. To exclude a field from the notes, prepend the field
# name with a - sign. Only fields that have a value are added to the notes.
my @COLUMNS = (
	"index", "number","date","time","?1","?2","duration",
	"S.I in seconds","maxdepth","avedepth","computer","-Diver Number",
	"-Diver Name","-Sampling rate","-Alt. Mode","-Personal mode",
	"?","?","location","site","Weather","Visibility","airtemp",
	"watertemp","End of dive Temp","buddy","divemaster","Boat",
	"Cylinder Type","cylindersize","-Units(1=L 2=cuft)","wp",
	"startp","endp","sac","?","Dive Type","Light Conditions",
	"Camera Used","-Custom 4","-Custom 5","weight","mix","?","0=Air,2=Nitrox" );

# Mapping computer numbers to model names. Only the computers supported by SDM 1.6.
my %COMPUTERS = (
	3 => "Stinger",
	4 => "Mosquito",
	5 => "D3",
	10 => "Vyper",
	11 => "Vytec",
	12 => "Cobra",
	20 => "Spyder",
	251 => "Eon",
	252 => "Solution Nitrox/Vario",
	253 => "Solution Alpha"
	);

# Generic UUID handling
my %uuids;
sub new_uuid {
	my $uuid = perlhash(shift);
	while ($uuids{$uuid}) {
		$uuid = ($uuid + 1) & 0x7FFFFFFF;
	}
	$uuids->{$uuid} = 1;
	return sprintf("%x", $uuid);
}

# Generic CSV file loader
my $DQ = chr(1);
my $DC = chr(2);
my $DT = chr(3);

sub decomma {
	my $s = shift;
	$s =~ s/,/$DC/g;
	return $s;
}

sub perlhash {
	my $hash = 0;
	foreach (split //, shift) {
		$hash = ($hash * 33 + ord($_)) & 0x7FFFFFFF;
	}
	return $hash;
}

sub readCSV {
	my $file = shift;
	my $rows = [];
	my $fh;
	local $/ = "\n";
	open($fh, "<", $file) or die "Open $file failed: $?";
	while (my $line = <$fh>) {
		$line =~ s/[\r\n]+$//s;
		next if ($line eq "");
		$line =~ s/(^|,)""(,|$)/$1$2/g;
		$line =~ s/""/$DQ/g;
		$line .= $DT if $line =~ /,$/;
		$line =~ s/"([^"]*)"/decomma($1)/ge;
		my $cols = [
			map {
				$_ =~ s/$DQ/"/g;
				$_ =~ s/$DC/,/g;
				$_ =~ s/$DT//g;
				$_} split(",", $line) ];
		push(@$rows, $cols);
	}
	close($fh);
	return $rows;
} 

my $csv = $ARGV[0];

# Load the dive list
my $dives = {};
my $divedata = readCSV("$csv.CSV");
my @diveorder;
my $divesites = {};
foreach my $row (@$divedata) {
	# Map the CSV row array to a perl hash that maps column name to data value
	my $dive = {};
	for (my $i = 0; $i < scalar(@$row); $i++) {
		$dive->{$COLUMNS[$i]} = $row->[$i];
	}

	# Fix up date format - assumes dates have been recorded as dd/mm/yyyy
	my $t = Time::Piece->strptime($dive->{date}, "%d/%m/%Y");
	$dive->{date} = $t->strftime("%Y-%0m-%0d");

	# Extract location
	# TODO: combine successive dives at the same Location into a single Subsurface trip?
	my $loc = "$dive->{location}/$dive->{site}";
	my $uuid = $divesites->{$loc};
	$uuid = new_uuid($loc) if (!defined $uuid);
	$divesites->{$loc} = $uuid;
	$dive->{divesiteid} = $uuid;

	# Fix up nitrox mix - SDM means "Air" when the mix is 0
	$dive->{mix} = 21 if $dive->{mix} == 0;

	# Map computer number to model name. This won't match the model name in Subsurface, but that doesn't really matter.
	$dive->{computer} = $COMPUTERS{$dive->{computer}} if $dive->{computer};

	$dives->{$dive->{index}} = $dive;
	push(@diveorder, $dive->{index});
}

# Load the $NOT notes file. The notes are added to the dive they relate to in the order they are seen.
my @notes; # array of strings
my $notedata = readCSV("$csv\$NOT.CSV");
foreach my $row (@$notedata) {
	my $index = $row->[0];
	push(@{$dives->{$index}->{notes}}, $row->[1])
		if (exists $dives->{$index});
}

# Load the $DGE gear file. Gear is currently added to extradata, but could be added to the end of notes
my @dive_gear; # array of lists
my $dgdata = readCSV("$csv\$DGE.CSV");
foreach my $row (@$dgdata) {
	my $index = $row->[0];
	push(@{$dives->{$index}->{equipment}}, $row->[1])
		if (exists $dives->{$index});
}

# Load the $PRO profiles file.
my $prodata = readCSV("$csv\$PRO.CSV");
foreach my $row (@$prodata) {
	my $index = shift @$row;
	push(@{$dives->{$index}->{profile}}, $row)
		if (exists $dives->{$index});
}

open(FO, ">", "$csv.xml") or die "Can't open output file";

print FO <<HEAD;
<divelog program='subsurface' version='3'>
<settings>
</settings>
<divesites>
HEAD

while (my ($loc, $uuid) = each %$divesites) {
	my $v = $loc;
	$v =~ s/'/&apos;/g;	
	print FO "<site uuid='$uuid' name='$loc'></site>\n";
}
print FO "</divesites>\n<dives>\n";

foreach my $index (@diveorder) {
	my $dive = $dives->{$index};

	# Assumes duration is seconds
	print FO "<dive number='$dive->{number}' sac='$dive->{sac}' divesiteid='$dive->{divesiteid}' date='$dive->{date}' time='$dive->{time}' duration='$dive->{duration} s'>\n";
	print FO "<divemaster>$dive->{divemaster}</divemaster>\n"
		if ($dive->{divemaster});
	print FO "<buddy>$dive->{buddy}</buddy>\n"
		if ($dive->{buddy});
	
	# Mop up unmappable fields and add them to the notes.
	my $notes = $dive->{notes};
	while (my ($k, $v) = each %$dive) {
		if ($v && $v ne "" && $k =~ /^[A-Z]/) {
			$v =~ s/'/&apos;/g;
			push(@$notes, "$k: $v");
		}
	}
	$dive->{notes} = $notes;

	if ($dive->{notes}) {
		my $v = join("\n",@{$dive->{notes}});
		$v =~ s/'/&apos;/g;
		print FO "<notes>$v</notes>\n"
	}

	# Assumes cylindersize is litres and pressures are bar
	print FO "<cylinder";
	print FO " size='$dive->{cylindersize} l'" if $dive->{cylindersize};
	print FO " start='$dive->{startp} bar'" if defined $dive->{startp};
	print FO " end='$dive->{endp} bar'" if defined $dive->{endp};
	print FO " o2='$dive->{mix}%'" if defined $dive->{o2};
	print FO " workpressure='$dive->{wp} bar'" if defined $dive->{wp};
	print FO " />\n";
	
	# Assumes weights are kg
	print FO "<weightsystem weight='$dive->{weight} kg' description='belt' />\n"
		if ($dive->{weight});
	
	# Assumes temps are celcius
	print FO "<divetemperature air='$dive->{airtemp} C' water='$dive->{watertemp} C'/>\n";
	print FO "<divecomputer model='Suunto $dive->{computer}'>\n";

	# Process the profile. Assumes depths are metres. I can only work out what the first two columns
	# are - time, and depth. Subsurface also supports "temp".
	print FO "<depth max='$dive->{maxdepth} m' mean='$dive->{avedepth} m' />\n";
	foreach my $sample (@{$dive->{profile}}) {
		print FO "<sample time='$sample->[0] min' depth='$sample->[1] m' />\n";
	}
	print FO "</divecomputer>\n";

	# Process dive equipment. Currently added as extradata, could alternatively be embedded in Notes.
	if ($dive->{equipment}) {
		print FO "<extradata key='Equipment' value='";
		my $v = join("; ", @{$dive->{equipment}});
		$v =~ s/'/&apos;/g;
		print FO $v;
		print FO "' />\n";
	}
	
	print FO "</dive>\n";
}

print FO <<TAIL;
</dives>
</divelog>
TAIL

close(FO);
print scalar(keys %$dives), " dives written to $csv.xml\n";
1;
