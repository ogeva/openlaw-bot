#!/usr/bin/perl -w

use v5.14;
use strict;
no strict 'refs';
use English;
use utf8;
use Data::Dumper;
binmode STDOUT, "utf8";
binmode STDERR, "utf8";

use constant { true => 1, false => 0 };

#    TODO List
# 
#  * EOF with remaining text.
#  * subb w/o sub
#  * Rewrite context mechanism
#  * Add TABLE
#  * Add TOFES
#  * TOUCH file according to source
#  * Use indexing for filenames
#  * Handle text without context better
#  * Supplementals with chapters - fix LOCALs
#  * Add file directives:
#      Name, Section ref type, title, location...
#  * Add UNFORMATTED, HTML tags
#  * Problems having sssub without sub

my $FIN;

if ($#ARGV>=0) {
	my $fin = $ARGV[0];
	my $fout = $fin;
	$fout =~ s/(.*)\.[^.]*/$1.wiki/;
	$fout =~ s/(\s|[:|,])+/_/g;
	$fout =~ s/(.*)\///;
	
	open($FIN,$fin) || die "Cannot open file \"$fin\"!\n";
	open(STDOUT, ">".$fout) || die "Cannot open file \"$fout\"!\n";
} else {
	$FIN = \*STDIN;
}
binmode $FIN, "utf8";


## Define the markup language we are using
my %markup = (
	"" => {
		done => "printText",
	},
	document => {
		context => 0,
		done => "printFooter",
	},
	"שם" => {
		context => 1,
		done => "printHeader",
	},
	"מקור" => {
		context => 1,
		done => "printBibiolography",
	},
	"ביבליוגרפיה" => {
		context => 1,
		done => "printBibiolography",
	},
	"הקדמה" => {
		context => 1,
		done => "printIntro",
	},
	"הקדמהערה" => {
		context => 1,
		done => "printIntro2",
	},
	"מפריד" => {
		context => 2,
		init => "flushSeperator",
	},
	"קטע" => {
		context => 1,
		init => "initSECT",
		done => "printSection",
	},
	"חלק" => {
		context => 1,
		init => "initPART",
		done => "printSection",
	},
	"פרק" => {
		context => 1,
		init => "initSECTION",
		done => "printSection",
	},
	"סימן" => {
		context => 1,
		init => "initSUBSECTION",
		done => "printSection",
	},
	"תתפרק" => {
		context => 1,
		init => "initSUBSECTION",
		done => "printSection",
	},

	"סעיף" => {
		context => 1,
		init => "initCHAPTER",
		done => "printChapter"
	},
	"סעיף*" => {
		context => 1,
		init => "initCHAPTER2",
		done => "printChapter"
	},
	"תוספת" => {
		context => 1,
		init => "initAPPENDIX",
		done => "printAppendix"
	},
	"לוח" => {
		context => 1,
		init => "initAPPENDIX",
		done => "printAppendix"
	},
	"עוגן" => {
		init => "gotANKOR",
	},
	"תאור" => {
		init => "gotDESC",
	},
	"תיאור" => {
		init => "gotDESC",
	},
	"תיקון" => {
		init => "gotFIX",
	},
	"תיקון*" => {
		init => "gotFIX2",
	},
	"אחר" => {
		init => "gotOTHER",
	},
	"ת" => {
		context => 2,
		init => "initPARA",
		done => "flushText",
	},
	"תת" => {
		context => 2,
		init => "initSUB",
		done => "flushText",
	},
	"תת*" => {
		context => 2,
		init => "initSUB2",
		done => "flushText",
	},
	"תתת" => {
		context => 2,
		init => "initSSUB",
		done => "flushText",
	},
	"תתת*" => {
		context => 2,
		init => "initSSUB2",
		done => "flushText",
	},
	"תתתת" => {
		context => 2,
		init => "initSSSUB",
		done => "flushText",
	},
	"תתתתת" => {
		context => 2,
		init => "initSSSSUB",
		done => "flushText",
	},
	"יציאה" => {
		context => 2,
		init => "removeIndent",
		done => "flushText",
	},
	"פסקה" => {
		context => 2,
		init => "initPARAGRAPH",
		done => "flushText",
	},
	"הגדרה" => {
		context => 2,
		init => "initDEFINITION",
		done => "flushText",
	},
	"הגדרהערה" => {
		context => 2,
		init => "initDEFNOTE",
		done => "flushText",
	},
	"פסקהערה" => {
		context => 2,
		init => "initPARANOTE",
		done => "flushText",
	},

	"חתימות" => {
		context => 1,
		init => "nop",
		done => "printSignatures",
	},
	"פרסום" => {
		context => 1,
		init => "nop",
		done => "printPubDate",
	},

	"לוח_השוואה" => {
		context => 2,
		init => "initCompareTable",
		done => "flushCompareTable",
	},
		

	"פנימי" => {
		context => -1,
		init => "open_A_LOCAL",
		done => "close_A_LOCAL",
	},
	"חיצוני" => {
		context => -1,
		init => "open_A_EXTERNAL",
		done => "close_A_EXTERNAL",
	},
	"קישור" => {
		context => -1,
		init => "open_A_GENERIC",
		done => "close_A_GENERIC",
	},
	"הערה" => {
		context => -1,
		init => "open_SPAN_NOTE",
		done => "close_SPAN",
	},
	"מודגש" => {
		context => -1,
		init => "open_B",
		done => "close_B",
	},
	"סימון" => {
		context => -1,
		init => "open_TITLE",
		done => "close_TITLE",
	},
	"ויקי" => {
		context => 1,
		init => "open_WIKI",
		done => "close_WIKI",
	},
	"/" => {
		context => -2,
	},

);


my @context = ("");
my @localcontext = ();
my $command = "";
my $curr = "";
my $param;

my $sectype = 0;  # 1 - Part restarts sections numbering
my $part = "";
my $section = "";
my $subsection = "";
my $supplemental = "";


my %href = (
	type => 0,		# 0=none, 1=gotit, 2=guess, 3=ext*, 4=ext**, 
	text => "", 	# href text
	mark => undef, 	# External marked (*)
	marks => undef,	# External marked (**), Global.
	curr => undef,	# current global mark
);

my %object = ();
my @table = ();
my @text = ();
my @text2 = ();
my $textline;

my %global = ();
@{$global{footer}} = ();
$global{date} = '';


while (my $line = <$FIN>) {
	$textline = "";
	chomp($line);
	#print STDERR "#### $line \n";
	while ($line =~ s/<([א-ת|_|*|0-9]+|\/)\s*(("[^"]*")?[^>]*)>//) {
		# Got a <COMMAND>
		($command, $param) = ($1, $2);
		$textline = $textline . $PREMATCH;
		$href{text} = $href{text} . $PREMATCH if ($href{type}>0);
		$line = $POSTMATCH;
		$param =~ s/^"(.*)"$/$1/;
		# print STDERR "%% Got $command |$param|\n";
		
		if (!defined $markup{$command}) {
			print STDERR "ERROR: Unknown command (" . $command .").\n";
			printError('פקודה לא מוכרת (' . $command . ')');
			next;
		}
		
		# Have we changed the context?
		my $level = $markup{$command}->{context};
		if (!defined $level) { }
		elsif ($level>0) {
			# Push current line
			if ($textline =~ /\S/) {
				$textline =~ s/^\s*(.*?)\s*$/$1/;
				push @text, $textline;
			}

			while (@localcontext) {
				print STDERR "ERROR: Local context not closed (" . pop(@localcontext) . ").\n";
			}
			# Flush previous context...
			while (@context >= $level) {
				$curr = pop @context;
				$markup{$curr}->{done}() if ($markup{$curr}->{done});
			}
			push @context, $command;
			$curr = $command;
			if ($level==1) { 
				printText() if (scalar(@text));
				%object = ();
				@text = ();
			}
		} elsif ($level==-1) {
			push @localcontext, $command;
		} elsif ($level==-2) {
			$curr = pop @localcontext;
			$curr = pop @context if (!$curr);
			if ($curr) {
				$markup{$curr}->{done}();
			}
		};
		
		if ($markup{$command}->{init}) {
			$markup{$command}->{init}($param);
		}
	}
	
	
	$textline .= $line;
	$href{text} .= $line if ($href{type}>0);
	if ($textline =~ /\S/) { 
		# Push textline
		$textline =~ s/^\s*(.*?)\s*$/$1/;
		push @text, $textline;
	}
}

while (@context > 0) {
	$curr = pop @context;
	$markup{$curr}->{done}();
}
printFooter();

# print "\n";

1;

###################################################################################################

sub nop {
	print STDERR "date = $object{date}\n" if (defined $object{date});
	return;
}

## PART SECTION SUBSECTION ############

sub initSECT {
	my ($level, $type, $num) = split(' ',shift,3);
	$num = get_numeral($num);
	$object{class} = "קטע$level";
	$object{name} = $type;
	if (defined $num) {
		$object{number} = "$type $num";
		$object{number} = "פרק $section $object{number}" if ($type eq 'סימן' && defined $section);
	}
	$object{number} = "תוספת $supplemental $object{number}" if ($supplemental && !($type =~ /תוספת|טופס/));
	
	$part = $num if ($type =~ /חלק/);
	$section = $num if ($type =~ /פרק/);
	$subsection = $num if ($type =~ /סימן/);
	$supplemental = $num if ($type =~ /תוספת|טופס/);
}

sub initPART {
	$object{class} = "חלק";
	$object{name} = "part";
	$object{name} = "sup_${supplemental}_".$object{name} if ($supplemental);
	$object{number} = $part = shift;
}
sub initSECTION {
	$object{class} = "פרק";
	$object{name} = "sec";
	$object{name} = "sup_${supplemental}_".$object{name} if ($supplemental);
	$object{number} = $section = shift;
	if ($sectype) {
		$object{number} = $part . "_" . $section;
	}
}
sub initSUBSECTION {
	$object{class} = "סימן";
	$object{name} = "sec";
	$object{name} = "sup_${supplemental}_".$object{name} if ($supplemental);
	$subsection = shift;
	$object{number} = $section . "_" . $subsection;
	if ($sectype) {
		$object{number} = $part . "_" . $object{number};
	}
}

## CHAPTER ############################

sub initCHAPTER {
	$_ = shift;
	s/-/ - /;
	$object{number} = $_;
	$object{lines} = [];
	$object{sub} = undef;
	$object{ssub} = undef;
	$object{sssub} = undef;
	$object{ssssub} = undef;
	$object{indent} = 0;
	$object{class} = "";
	
	push @context, "פסקה";
}
sub initCHAPTER2 {
	initCHAPTER(@_);
	$object{noankor} = 1;
	$object{name} = "סעיף*";
}
sub initAPPENDIX {
	$_ = shift;
	$supplemental = $_;
	initCHAPTER($_);
}

sub gotDESC {
	$_ = shift;
	s/<קישור\s*(.*?)>(.*?)<\/\>/&inline_HREF($2,$1)/egm;
	$object{"desc"} = $_;
}
sub gotFIX {
	$_ = shift;
	if ($object{fix}) {
		$object{fix} .= ", " . $_;
	} else {
		$object{fix} = $_;
	}
}
sub gotFIX2 {
	$_ = shift;
	if ($object{fix2}) {
		$object{fix2} .= ", " . $_;
	} else {
		$object{fix2} = $_;
	}
}
sub gotOTHER {
	$_ = shift;
	if ($object{other}) {
		$object{other} .= " " . $_;
	} else {
		$object{other} = $_;
	}
}

sub gotANKOR {
	$_ = shift;
	print STDERR "## ANKOR |$_|\n";
	$object{ankor_str} = $_;
	
# 	if ($object{sptr}) {
# 		push @{$object{ankors2}}, $_;
# 		print STDERR "  got $#{$object{ankors2}}.\n";
# 	} else {
# 		push @{$object{ankors}}, $_;
# 	}
}

sub initSUB {
	$object{sptr} = scalar(@{$object{lines}});
	$object{ssptr} = undef;
	$object{sssptr} = undef;
	$object{ssssptr} = undef;
	$object{sub} = shift;
	$object{ssub} = undef;
	$object{sssub} = undef;
	$object{ssssub} = undef;
	$object{indent} = 1;
	$object{class} = "";
	$object{ankor} = 1;
}
sub initSUB2 {
	initSUB(@_);
	$object{ankor} = 0;
}

sub initSSUB {
	$object{ssptr} = scalar(@{$object{lines}});
	$object{sssptr} = undef;
	$object{ssssptr} = undef;
	$object{ssub} = shift;
	$object{sssub} = undef;
	$object{ssssub} = undef;
	$object{indent} = 2;
	$object{class} = "";
}
sub initSSSUB {
	$object{sssptr} = scalar(@{$object{lines}});
	$object{ssssptr} = undef;
	$object{sssub} = shift;
	$object{ssssub} = undef;
	$object{indent} = 3;
	$object{class} = "";
}
sub initSSSSUB {
	$object{ssssptr} = scalar(@{$object{lines}});
	$object{ssssub} = shift;
	$object{indent} = 4;
	$object{class} = "";
}
sub initSSUB2 {
	initSSUB(@_);
	$object{ankor} = 0;
}

sub flushText {
	if (! @text) { return; }
	my %line = (
		indent => $object{indent},
		sub => $object{sub},
		ssub => $object{ssub},
		sssub => $object{sssub},
		ssssub => $object{ssssub},
		class => $object{class},
		ankor => $object{ankor},
		scnt => 0,
		sscnt => 0,
		ssscnt => 0,
		sssscnt => 0,
	);
	replaceAll("?EXT?",$href{mark}) if ($href{mark});
	@{$line{text}} = @text;
	@{$line{ankors}} = @{$object{ankors2}} if (defined $object{ankors2});
	push @{$object{lines}}, {%line};
	if (defined $object{sptr}) { $object{lines}[$object{sptr}]->{scnt}++; }
	if (defined $object{ssptr}) { $object{lines}[$object{ssptr}]->{sscnt}++; }
	if (defined $object{sssptr}) { $object{lines}[$object{sssptr}]->{ssscnt}++; }
	if (defined $object{ssssptr}) { $object{lines}[$object{ssssptr}]->{sssscnt}++; }
	$object{sub} = undef;
	$object{ssub} = undef;
	$object{sssub} = undef;
	$object{ssssub} = undef;
	@text = ();
	# $href{mark} = undef;
	$object{ankors2} = undef;
}

sub removePointers {
	if ($object{indent}<4) {
		$object{ssssptr} = undef;
		$object{ssssub} = undef;
	}
	if ($object{indent}<3) {
		$object{sssptr} = undef;
		$object{sssub} = undef;
	}
	if ($object{indent}<2) {
		$object{ssptr} = undef;
		$object{ssub} = undef;
	}
	if ($object{indent}<1) {
		$object{sptr} = undef;
		$object{sub} = undef;
	}
}

sub removeIndent {
	if ($object{indent}==0) { return; }
	$object{indent}--;
	removePointers();
}

sub initPARAGRAPH {
	$object{class} = "";
	removePointers();
}
sub initDEFINITION {
	$object{class} = "ח:הגדרה";
	removePointers();
}
sub initDEFNOTE {
	$object{class} = "ח:הערה";
	removePointers();
}
sub initPARANOTE {
	$object{class} = "ח:הערה";
	removePointers();
}
sub initPARA {
	$object{sub} = undef;
	$object{indent} = 0;
	$object{class} = "";
}


## A ##################################

#	$href{type} is:  0=none, 1=gotit, 2=guess, 3=ext*, 4=ext**, 5=ext+, 6=ext-

sub open_A_LOCAL {
	my $text = shift;
	if ($href{type}>0) {
		# ERROR...
		printError('סגירת קישור פתוח');
		close_A();
	}
	$href{text} = "";
	if ($text) {
		$href{type} = 1;
		$text = findHREF($text);
	} else {
		$href{type} = 2;
		$text = "?HREF?";
	}
	$textline = $textline . "{{ח:פנימי|$text|";
}

sub close_A_LOCAL {
	if ($href{type}==0) {
		# ERROR...
		printError('סוגר קישור ללא פותח');
		return;
	}
	# $textline = $textline . "<\/a>";
	$textline = $textline . "}}";
	if ($href{type}==2) {
		my $text = $href{text};
		$text = findHREF($text);
		if (!replaceAll('?HREF?', $text, 1)) {
			printError('לא נמצא קישור');
			print STDERR "ERROR: HREF not found...\n";
		}
	}
	$href{type} = 0;
}

sub open_A_EXTERNAL {
	my $text = join("#", @_);
	$text =~ tr/\?//;
	my $hassep = $text =~ /#/;
	my ($ext, $part) = $text =~ /([^#]*)#?(.*)/;

	if ($href{type}>0) {
		# ERROR...
		printError('סגירת קישור פתוח');
		close_A();
	}

	$href{class} = 0;
	$href{text} = "";
	$href{mark} = "?EXT?" if (!$href{mark});

	if ($ext eq "*") {
		$href{class} = 2;
		$href{type} = 3;
		$text = "?EXT?";
		$hassep = 0;
	} elsif ($ext =~ /^\*(.*)/) {
		$ext = $1;
		$href{class} = 0;
		$href{type} = 4;
		$href{curr} = $ext;
		$text = "?EXT-" . $ext . "?";
		$hassep = 0;
	} elsif ($ext =~ /^[+-]$/) {
		$hassep = ($ext eq "+");
		$href{class} = 0;
		$href{type} = 1;
		$href{mark} = "?EXT?" if (!$href{mark});
		$text = $ext = "?EXT?";
	} elsif ($ext =~ /^([+-])(.*)/) {
		$hassep = ($1 eq "+");
		$ext = $2;
		$href{type} = 1;
		$href{marks}{$ext} = "?EXT-$ext?" if (!$href{marks}{$ext});
		$text = $ext = $href{marks}{$ext};
		if ($1 eq "-") {
			replaceAll('?EXT?',$ext);
		}
	} elsif ($ext) {
		$href{type} = 1;
		$text = $ext = findExtRef($ext);
	} else {
		$ext = "?EXT?";
		$hassep = 1;
	}
	
	if ($hassep) { 
		if ($part) {
			$href{type} = 1;
			# print STDERR "HERE!\n";
			$text = $ext . "#" . findHREF($part);
		} else {
			$href{type} = 2;
			$text = $ext . "#?HREF?";
		}
	}
	# print STDERR "##  |$ext|" . ($hassep ? " #" : "") . " |$part|  |$text|\n";
	$textline = $textline . "{{ח:חיצוני|$text|";
}

sub close_A_EXTERNAL {
	# print STDERR "##  TYPE = $href{type}\n";
	# print STDERR "##  TEXT = $href{text}\n";
	if ($href{type}==2) {
		my $text = $href{text};
		if ($text =~ /^[בוהל]?(חוק|פקוד[הת]|תקנה|תקנות|צו|החלטה|תקנון|דבר[ -]המלך)/) {
			$text = findExtRef($text);
			if (!replaceAll('?HREF?', $text, 1)) {
				print STDERR "ERROR: HREF not found...\n";
				printError('לא נמצא קישור');
			}
			$href{type} = 3;
		} else {
			$text = findHREF($text);
			if (!replaceAll('?HREF?', $text, 1)) {
				print STDERR "ERROR: HREF not found...\n";
				printError('לא נמצא קישור');
			}
		}
	}
	
	if ($href{type}==3) {
		my $text = $href{text};
		$href{mark} = $text = findExtRef($text);
		replaceAll('?EXT?',$text);
	}

	if ($href{type}==4) {
		my $text = $href{text};
		my $ext = $href{curr};
		$href{marks}{$ext} = $text = findExtRef($text);
		replaceAll("?EXT-".$ext."?", $text);
	}

	if ($href{type}==5) {
		my $text = $href{text};
		$text = findHREF($text);
		if (!replaceAll("?HREF?", $text, 1)) {
			print STDERR "ERROR: HREF not found...\n";
			printError('לא נמצא קישור');
		}
	}
	
	$textline = $textline . "}}";
	$href{type} = 0;
}

sub close_A {
	$textline = $textline . "}}";
}

sub inline_HREF {
	my $local = $textline;
	my $text = shift;
	my $helper = shift;
	$textline = '';
	open_A_GENERIC($helper);
	$textline .= $text;
	$href{text} = $text;
	close_A_GENERIC();
	$text = $textline;
	$textline = $local;
	return $text;
}

sub open_A_GENERIC {
	if ($href{type}>0) {
		# ERROR...
		printError('סגירת קישור פתוח');
		close_A();
	}
	
	my $helper = shift;
	$helper =~ tr/\?//;
	$href{helper} = $helper;
	$href{type} = 10;
	$textline .= "{{?TYPE?|?HREF?|";
}

sub close_A_GENERIC {
	$href{text} =~ tr/\?//;
	$textline .= "}}";
	
	my $type = processHREF();
	$type = ($type==1) ? 'ח:פנימי' : 'ח:חיצוני';
	if (!replaceOnce('?TYPE?', $type)) {
		print STDERR "ERROR: TYPE not found...\n";
		printError('לא נמצא קישור-סוג');
	}
	
	$href{type} = 0;
	$href{text} = '';
	$href{helper} = '';
}

sub processHREF {
	my ($text,$ext) = findHREF($href{text});
	my $helper = $href{helper};
	my $marker = '';
	my $found = false;
	
	# my $ext = findExtRef($text);
	# my $type = typeHREF($text);
	my $type = ($ext) ? 2 : 1;
	
	$ext = '' if ($type == 1);
	
	if ($helper =~ /^(.*?) *# *(.*)/) {
		$type = 2;
		$helper = $1;
		($text, undef) = findHREF($2);
		$ext = '' if ($1);
		$found = true;
	}
	
	# print STDERR "## X |$href{text}| X |$ext|$text| X |$helper|\n";
	
	if ($helper =~ /^=\s*(.*)/) {
		$type = 2;
		$helper = $1;
		$href{marks}{$helper} = $ext;
	} elsif ($helper eq '+' || $ext eq '+') {
		$type = 2;
		replaceOnce('?HREF?','?EXT?#?HREF?');
		$ext = '';
	} elsif ($helper eq '-' || $ext eq '-') {
		$type = 2;
		if ($text) {
			replaceOnce('?HREF?',$href{mark}.'#?HREF?');
		} else {
			replaceOnce('?HREF?',$href{mark});
		}
		$ext = '';
	} elsif ($helper) {
		if ($found) {
			(undef,$ext) = findHREF($helper);
		} else {
			($text,$ext) = findHREF($helper);
		}
		$type = ($ext) ? 2 : 1;
	} else {
	}
	
	# if (($type==2) && ($ext)) {
	if ($ext) {
		$ext = $href{marks}{$ext} if ($href{marks}{$ext});
		replaceOnce('?HREF?',$ext . ($text ? "#$text" : ""));
		replaceAll('?EXT?',$ext);
		$href{mark} = $ext;
	} else {
		replaceOnce('?HREF?',$text);
	}
	
	# print STDERR "## X |$href{text}| X |$ext|$text| X |$helper|\n";
	
	return $type;
}


## SPAN B #############################

sub open_SPAN_NOTE {
	$textline = $textline . "{{ח:הערה|";
}
sub open_TITLE {
	$_ = shift;
	# if (/[\)\]\}]\s*$/) { $_ = $_ . "\xFE"; }
	s|&|&amp;|g;
	s|"|&quot;|g;
	$object{title} = $_;
	$textline = $textline . "{{ח:טיפ|";
}
sub close_TITLE {
	my $title = $object{title};
	$textline = $textline . "|$title}}";
}
sub close_SPAN {
	$textline = $textline . "}}";
}

sub open_B {
	$textline = $textline . "'''";
}
sub close_B {
	$textline = $textline . "'''";
}

sub open_WIKI {
	my $param = shift;
	push @context, "ויקי";
	$object{class} = $param;
}

sub close_WIKI {
	if ($object{class} =~ /קטגוריה/) {
		$textline = chomp($textline);
		$textline = "[[קטגוריה:$textline]]\n";
	} 
	elsif ($object{class} =~ /תבנית/) {
		$textline = chomp($textline);
		$textline = "{{$textline}}\n";
	}
	push @{$global{footer}}, @text;
	push @{$global{footer}}, $textline;
	$textline = '';
	@text = ();
}

###################################################################################################

sub fixFormat {
	$_ = shift;
	if (!$_) { return ""; }

	# -- --> &ndash;
	# s/--/&ndash;/g;
	s/--/–/g;
	
	# Fix עברית-1234 with LTR marker
	# s/([א-ת])-([0-9])/$1-\xFD$2/g;
	
	return $_;
}


sub typeHREF {
	shift;
	return (/(\bו?[בהל]?(חוק|פקוד[הת]|תקנה|תקנות|צו|החלטה|תקנון|דבר[ -]המלך)\b)|#/ ? 2 : 1);
}


sub findHREF {
	my $_ = shift;
	if (!$_) { return $_; }
	
	my $ext = '';
	
	if (/^(.*?)\s*(\bו?[בהל]?(חוק|פקוד[הת]|תקנות|צו|החלטה|תקנון|דבר[ -]המלך)\b.*)$/) {
		$_ = $1;
		$ext = findExtRef($2);
	}
	
	if (/^(.*)#(.*)$/) {
		$_ = $2;
		$ext = findExtRef($1);
	}
	
	s/[\(_]/ ( /g;
	s/[\"\']//g;
	s/\bו-//g;
	s/\bאו\b/ /g;
	s/^ *(.*?) *$/$1/;
	s/טבלת השוואה/טבלת_השוואה/;
	
	my @parts = split /[ ,.\-\)]+/;
	my $class = "chap";
	my $num;
	my %elm = ();
	
	foreach $_ (@parts) {
		$num = undef;
		given ($_) {
			when (/^ו?[בהל]?(חלק|חלקים)/) { $class = "part"; }
			when (/^ו?[בהל]?(פרק|פרקים)/) { $class = "section"; }
			when (/^ו?[בהל]?(סימן|סימנים)/) { $class = "subsect"; }
			when (/^ו?[בהל]?(תוספת)/) { $class = "sup"; $num = ""; }
			when (/^ו?[בהל]?(טופס|טפסים)/) { $class = "template"; }
			when (/טבלת_השוואה/) { $class = "table"; $num = ""; }
			when (/^ו?[בהל]?(סעיף|סעיפים|תקנה|תקנות)/) { $class = "chap"; }
			when (/^קט[נן]|פסקה|פסקאות|משנה|פריט|פרט/) { $class = "small"; }
			when ("(") { $class = "small"; }
			when (/^ה?(זה|זו|זאת)/) {
				given ($class) {
					when ("sup") { $num = $supplemental; }
					when ("part") { $num = $part; }
					when ("section") { $num = $section; }
					when ("subsect") { 
						$elm{subsect} = $subsection unless defined $elm{subsect};
						$elm{section} = $section unless defined $elm{section};
					}
					when ("chap") { $num = $object{number}; }
				}
			}
			default {
				$num = get_numeral($_);
			}
		}
		
		if (defined($num) && !$elm{$class}) {
			$elm{$class} = $num;
		}
	}
	
	my $href;
	if (defined $elm{table}) {
		$href = "טבלת השוואה";
	} elsif (defined $elm{sup}) {
		$href = "תוספת $elm{sup}";
		$href .= " חלק $elm{part}" if (defined $elm{part});
	} elsif (defined $elm{template}) {
		$href = "טופס $elm{template}";
	} elsif (defined $elm{part}) {
		$href = "חלק $elm{part}";
		$href .= " פרק $elm{section}" if defined $elm{section};
		$href .= " סימן $elm{subsect}" if defined $elm{subsect};
	} elsif (defined $elm{section}) {
		$href = "פרק $elm{section}";
		$href .= " סימן $elm{subsect}" if defined $elm{subsect};
	} elsif (defined $elm{subsect}) {
		$href = "סימן $elm{subsect}";
		$href = "פרק $section $href" if defined $section && ($ext eq '');
	} elsif (defined $elm{chap}) {
		$href = "סעיף $elm{chap}";
	} else {
		$href = "";
	}
	
	$href =~ s/  / /g;
	$href =~ s/^ *(.*?) *$/$1/;
	# print STDERR "GOT |$_|$ext|\n";
	return ($href,$ext);
}	


sub findExtRef {
	my $_ = shift;
	return $_ if (/^https?:\/\//);
	tr/"'`//;
	s/\(נוסח (חדש|משולב)\)//g;
	s/\[נוסח (חדש|משולב)\]//g;
#	s/(^[^\,\.]*).*/$1/;
	s/#.*$//;
	s/\.[^\.]*$//;
	s/\, *[^ ]*\d+$//;
	s/\[.*?\]//g;
	s/^\s*(.*?)\s*$/$1/;
	if (/^ו?[בהל]?(חוק|פקודה|פקודת|תקנה|תקנות|צו|החלטה|תקנון|דבר[ -]המלך)\b(.*)$/) {
		$_ = "$1$2";
		return '' if ($2 eq 'זאת');
		return '-' if ($2 =~ /\b(האמורה?|אותו|אותה)\b/);
	}
	s/\s[-——]+\s/_XX_/g;
	s/[-]+/ /g;
	s/_XX_/ - /g;
	s/[ _\:.]+/ /g;
#	print STDERR "$prev -> $_\n";
	return $_;
}

sub replaceAll {
	# It's not really a bug, but the replaceAll works forwards and not backwards.
	# For count==1, might give wierd results if there are previous errors...
	my $src = shift;
	my $dst = shift;
	if (!$src || !$dst) {
		return;
	}
	
	$src =~ s/\\?\?/\\\?/g;
	$dst =~ s/\\?\?/\?/g;
	
	my $count = my $total = shift;
	$count = -1 unless ($count);
	# print STDERR "replaceAll: |$src| --> |$dst|\n";

	while ($textline =~ s/$src/$dst/) {
		last if (--$count==0);
	}
		
	COUNT: for (my $i = $#text; $i>=0; $i--) {
		while ($text[$i] =~ s/$src/$dst/) {
			last COUNT if (--$count==0);
		}
	}
	
	return ($total-$count) if (defined $total);
}

sub replaceOnce {
	my $src = shift;
	my $dst = shift;
	return replaceAll($src,$dst,1);
#	return replaceAll(shift,shift,1);
}


sub unquote {
	my $_ = shift;
	s/^ *(.*?) *$/$1/;
	s/^(["'])(.*?)\1$/$2/;
	s/^ *(.*?) *$/$1/;
	return $_;
}

sub unparent {
	my $_ = unquote(shift);
	s/^\((.*?)\)$/$1/;
	s/^\[(.*?)\]$/$1/;
	s/^\{(.*?)\}$/$1/;
	s/^ *(.*?) *$/$1/;
	return $_;
}

sub get_numeral {
	my $_ = shift;
	my $num = undef;
	s/[.,'"]//g;
	$_ = unparent($_);
	given ($_) {
		$num = $1 when /\b(\d+(([א-י]|טו|טז|[כלמנ][א-ט]?|)\d*|))\b/;
		$num = $1 when /\b(([א-י]|טו|טז|[כלמנ][א-ט]?)(\d+[א-י]*|))\b/;
		$num = "1" when /\b(ה?ראשו(ן|נה)|אח[דת])\b/;
		$num = "2" when /\b(ה?שניי?ה?|ש[תנ]יי?ם)\b/;
		$num = "3" when /\b(ה?שלישית?|שלושה?)\b/;
		$num = "4" when /\b(ה?רביעית?|ארבעה?)\b/;
		$num = "5" when /\b(ה?חמי?שית?|חמש|חמישה)\b/;
		$num = "6" when /\b(ה?שי?שית?|שש|שי?שה)\b/;
		$num = "7" when /\b(ה?שביעית?|שבעה?)\b/;
		$num = "8" when /\b(ה?שמינית?|שמונה)\b/;
		$num = "9" when /\b(ה?תשיעית?|תשעה?)\b/;
		$num = "10" when /\b(ה?עשירית?|עשרה?)\b/;
	}
	return $num;
}


###################################################################################################

## Error ##############################

sub printError {
	my $text = shift;
	$textline = $textline . " <span class=\"ERROR\">&nbsp;$text&nbsp;</span> ";
}

## HEADER & FOOTER ####################

sub printHeader {
	my $title = fixFormat(shift @text);
	
	print "{{ח:התחלה}}\n";
	print "{{ח:כותרת|$title}}\n\n";
}

sub printFooter {
	print "\n{{ח:סוף}}\n";
	if (@{$global{footer}}) {
		print "\n";
		print join("\n", @{$global{footer}});
	}
}

## BIBLIOGRAPHY & INTRO ###############

sub flushSeperator {
	push @text, "{{ח:מפריד}}";
}

sub printBibiolography {
	my $bib = join("\n", @text);
	$bib = fixFormat($bib);
	@text = ();
	print "{{ח:פתיח-התחלה}}\n";
	print "$bib\n";
	print "{{ח:סוגר}}\n";
	print "{{ח:מפריד}}\n\n";
}

sub printIntro {
	my $text = join("\n\n", @text);
	$text = fixFormat($text);
	@text = ();
	print "{{ח:מבוא}}\n";
	print "$text\n";
	print "{{ח:סוגר}}\n";
	print "{{ח:מפריד}}\n\n";
}

sub printIntro2 {
	my $text = join("<br>\n  ", @text);
	$text = fixFormat($text);
	@text = ();
	print <<EOF;
<tr><td colspan="7" class="PARGRAPH NOTE">
  $text
  <hr class="SEPERATOR">
</td></tr>

EOF
}

## SECTION ############################

sub printSection {
	my $fix;
	$fix = "תיקון: " . $object{fix} if (defined $object{fix});
	$fix = "[" . $object{fix2} . "] " . $fix if (defined $object{fix2});
	my $text = fixFormat(shift @text);
	# my $number = makeENG($object{number});
	my $number = $object{number};
	# print "<tr><td colspan=\"7\" class=\"$object{class}\">\n";
	# print "  <a name=\"$object{name}_$number\"></a>\n" if ($number);
	# print "  $text\n";
	# print "  <span class=\"NOTE3\">$fix</span>\n" if ($fix);
	# print "</td></tr>\n";
	
	$number = $object{ankor_str} if (defined $object{ankor_str});

	print "{{ח:$object{class}|$number|$text";
	print "|$fix" if (defined $fix);
	print "}}\n\n";
#	printText() if (scalar(@text));
}

sub printText {
	my $text = join("\n", @text);
	@text = ();
	return if ($text !~ /\S/);
	return if (scalar(@text));
	# print "<tr><td></td>\n";
	# print "<td colspan=\"7\" class=\"PARAGRAPH\">\n";
	$text = fixFormat($text);
	print $text . "\n";
	# print "</td></tr>\n\n";
}

## CHAPTER ############################

sub printChapter {
	my @lines = @{$object{lines}};
	my $desc = fixFormat($object{desc});
	my $number = $object{number};
	my $fix; 
	$fix = "תיקון: $object{fix}" if (defined $object{fix});
	
	print "{{ח:סעיף";
	print "*" if ($supplemental);
	print "|$number|$desc";
	print "|תיקון: $object{fix}" if (defined $object{fix});
	print "|אחר=$object{other}" if (defined $object{other});
	print "}}\n";

	my $first = 1;
	my $line;
	for $line (@lines) {
		if ($line->{indent}==0 && !$first) { 
			print "{{ח:ת}} ";
		}
		$first = 0;
		print "{{ח:תת|$line->{sub}}} " if (defined $line->{sub});
		print "{{ח:תתת|$line->{ssub}}} " if (defined $line->{ssub});
		print "{{ח:תתתת|$line->{sssub}}} " if (defined $line->{sssub});
		print "{{ח:תתתתת|$line->{ssssub}}} " if (defined $line->{ssssub});
		my $text = join("\n", @{$line->{text}});
		$text = fixFormat($text);
		if ($line->{class}) {
			print "{{$line->{class}|$text}}\n"; 
		} else {
			print "$text\n";
		}
	}
	
	print "\n";
}

sub printAppendix {
	my @lines = @{$object{lines}};
	my $rows = scalar(@{$object{lines}})-1;
	# my $number = "תוספת " . makeENG($object{number});
	my $number = "תוספת " . $object{number};
	my $fix;
	$fix = "תיקון: " . $object{fix} . "" if (defined $object{fix});
	# $fix = "[" . $object{fix2} . "] " . $fix if (defined $object{fix2});
	
	my $line = shift @lines;
	my $desc = fixFormat(shift @{$line->{text}});
	my $other = fixFormat(join("\n  ", @{$line->{text}}));
	
	$number = $object{ankor_str} if (defined $object{ankor_str});
	
	print "{{ח:פרק|$number|$desc";
	print "|$fix" if ($fix);
	print "}}\n";
	
	for $line (@lines) {
		if (defined $line->{sub}) {
			print "{{ח:תת|$line->{sub}}}\n";
		}
		if (defined $line->{ssub}) {
			print "{{ח:תתת|$line->{ssub}}}\n";
		}
		if (defined $line->{sssub}) {
			print "{{ח:תתתת|$line->{sssub}}}\n";
		}
		if (defined $line->{ssssub}) {
			print "{{ח:תתתתת|$line->{ssssub}}}\n";
		}
		my $text = join("\n", @{$line->{text}});
		$text = fixFormat($text);
		if ($line->{class}) {
			print "{{$line->{class}|$text}}\n"; 
		} else {
			print $text . "\n";
		}
	}
	print "\n";
}


## SIGNATURES #########################

sub printSignatures {
	print "{{ח:חתימות";
	print "|$global{date}" if (defined $global{date});
	print "}}\n";
	my $line;
	foreach $line (@text) {
		last unless ($line =~ /^ *\*/);
		if ($line =~ /^ *\* *(.*?) *\| *(.*?) *$/) {
			print "* '''$1'''<br>$2\n";
		} elsif ($line =~ /^ *\* *(.*?) *$/) {
			print "* '''$1'''\n";
		}
	}
	print "{{ח:סוגר}}\n";
	@text = ();
}

sub printPubDate {
	my $text = join("\n", @text);
	@text = ();
	return if ($text !~ /\S/);
	return if (scalar(@text));
	$global{date} = $text;
	# print "{{ח:ת}}<small>$text</small>{{ח:סוגר}}\n";
}

sub initCompareTable {
	@text2 = @text;
	@text = ();
};

sub flushCompareTable {
	my $line;
	my $col = 0;
	for $line (@text) {
		if ($line =~ /^ *(.*?) *\| *(.*?) *$/) {
			$table[$col][0] = $1;
			$table[$col][1] = $2;
			$col++;
		}
	}

	@text = @text2;
	@text2 = ();
	push @text, '' if (scalar(@text));
	
	$col = int(($col+1)/2);
	
	push @text, '<table border="0" cellpadding="1" cellspacing="0" dir="rtl" align="center" class="NOTE2">';
    push @text, '  <tr><th width="120">הסעיף הקודם</th>';
    push @text, '  <th width="120">הסעיף החדש</th>';
    push @text, '  <th width="120">הסעיף הקודם</th>';
    push @text, '  <th width="120">הסעיף החדש</th></tr>';
    push @text, '  <tr><td colspan="4"><hr noshade width="100%"></td></tr>';

	for (my $i=0; $i<$col; $i++) {
		push @text, "  <tr><td>" . ($table[$i][0]?$table[$i][0]:"&nbsp;") . "</td>" . 
			"<td>" . ($table[$i][1]?$table[$i][1]:"&nbsp;") . "</td>" . 
			"<td>" . ($table[$i+$col][0]?$table[$i+$col][0]:"&nbsp;") . "</td>" . 
			"<td>" . ($table[$i+$col][1]?$table[$i+$col][1]:"&nbsp;") . "</td></tr>";
	}

	push @text, '</table>';
	@table = ();
}
