#!/usr/bin/perl -w

use strict;
local $| = 1;

use Rcs qw(nonFatal Verbose);
# set RCS bin directory
Rcs->bindir('/usr/bin');

my($afile) = @ARGV;

my($file, $path) = fileparse($afile);

use File::Basename;
my($topdir) = $path;

my $obj = Rcs->new;
$obj->rcsdir("${topdir}/RCS");
$obj->workdir("${topdir}");

$obj->file($file);

my $head_rev = $obj->head;
my $locker = $obj->lock;
my $author = $obj->author;
my @access = $obj->access;
my @revisions = $obj->revisions;
my $filename = $obj->file;

my($numrevisions) = $#revisions + 1;

$obj->quiet(1);

my %DatesHash = $obj->dates;
for (my $i=$#revisions; $i>=1; $i--) {
  print <<EVT;
${DatesHash{$revisions[$i]}} $revisions[$i]
EVT
}



