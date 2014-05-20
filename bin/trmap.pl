#!/usr/bin/perl -w

use strict;
local $|= 1;

require "$ENV{'HOME'}/lib/v6.pl";

print <<HEAD;
strict digraph tr {
        ratio= "auto";
        compound="true";
        fontsize=8;

        node [shape="oval", fontsize=6];
        edge [arrowsize="0.1", penwidth="0.5", color="black", arrowshape="none", dir="both"];

HEAD

my(%nodes);
my(%paths);

my(@alpha) = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z");

my($currfile);
my($j) = 0;
my($hostname) = $ENV{'HOST'} || 'mu.ilab.umnet.umich.edu';
my(%targets);
my(%complete);
my(%asns);
while(<>){
  chomp;

  my($i, $ip, $asn) = split(/\|/);
  if (! defined($asn) || $asn eq "" || $asn eq "*"){
    $asn = -1;
  }
  if (defined $asns{$ip}){
  } else {
    $asns{$ip} = $asn;
  }

  my($trfile) = $ARGV;
  $trfile =~ /.*\/(.*)\-\-\-${hostname}\-(.*)\.txt/;
  my($targetname, $targetip) = ($1, $2);
  $targetip =~ s/\_/:/g;
#  $targetname =~ s/\_/./g;
  $nodes{$targetip} = $targetname;

  if ($ip eq "*" || $ip eq ""){
    $ip = $alpha[$i] . "unk" . $j;
    $nodes{$ip} = "*";
    $asns{$ip} = "*";
  }

  if ($currfile){
  } else {
    $currfile = $ARGV;
  }

#  print STDERR "${j}. ${currfile}\n";


  if ($currfile ne $ARGV){
    if (defined($complete{$j})){
    } else {
      $paths{$j} .= " -> \"" . $targets{$j} . "\"";
      $complete{$j} = 1;
#      print STDERR $targetip . "\n";
    }
  }

  if ($i == 1){
    $j++;
    $currfile = $ARGV;
    $targets{$j} = $targetip;
    $paths{$j} = "\"" . $ip . "\"";
  } else {
    $paths{$j} .= " -> \"" . $ip . "\"";
  }

  if ($ip eq $targetip){
    $complete{$j} = 1;
  }

  my($name);
  if ($nodes{$ip}){
  } else {
    $nodes{$ip} = getptr($ip);
  }

}

if (defined($complete{$j})){
} else {
  $paths{$j} .= " -> \"" . $targets{$j} ."\"";
}

for my $n (keys %nodes) {
  if (! defined $asns{$n}){
    $asns{$n} = -1;
  }
  my($label) = "$nodes{$n}\\nAS${asns{$n}}";
  if ($n ne $nodes{$n}) {
    $label = "${label}\\n${n}";
  }
  print <<NN;
"$n" [label="${label}"];
NN
}

for my $k (keys %paths){
  print $paths{$k} . "\;\n";
}

print <<TAIL;
}
TAIL

