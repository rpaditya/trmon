#!/usr/bin/perl -w

use strict;
local $| = 1;

require "/home/rpaditya/lib/v6.pl";

use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);

use diagnostics -verbose;

use Socket;
use FileHandle;

use Rcs qw(nonFatal Verbose);
# set RCS bin directory
Rcs->bindir('/usr/bin');

our($config);
$config->{'HOME'} = "/home/rpaditya";

my($query) = new CGI;
my($ver) = $query->param('v');
if (! defined $ver) {
  print "Content-type: text/html\n\n";
  print <<HTML;
<h5>Pick target IP protocol version</h5>
<form action="">
<input type="radio" name="v" value="4" />v4<br/>
<input type="radio" name="v" value="6" />v6<br/>
<input type="submit" name="proto" value="IP protocol version" />
</form>
HTML
    

} else {
  chomp($ver);
  my($topdir) = "$config->{'HOME'}/data/tr/traceroute";
  if ($ver eq "6") {
    $topdir .= "6";
  }

  my($file) = $query->param('f');

  if (!defined $file){
    opendir(IN, $topdir) || die "could not open directory ${topdir}: $!";
    my @dirlist = readdir(IN);
    closedir(IN);
    if ($#dirlist >= 1){
      print "Content-type: text/html\n\n";
      print <<HEADER;
<h5>v${ver} targets</h5>
<form action="">
<input type="hidden" name="v" value="${ver}" />
<select name="f">
HEADER
      for my $j (@dirlist){
	if ($j =~ /\.txt$/){
	  print <<FILES;
<option value="${j}">${j}</option>
FILES
	} else {
#	  print "${j}<br/>";
	}
      }
      print <<FOOTER;
</select><br/>
<input type="submit" name="target" value="pick target" />
FOOTER
    } else {
      print "Content-type: text/html\n\n";
      print "ERROR: No files found in ${topdir}\n";
    }
  } elsif (! -r "${topdir}/${file}") {
    chomp($file);
    print "Content-type: text/html\n\n";
    print "ERROR: Could not find file <code>${file}</code><hr/>";
  } else {
    chomp($file);
    my $obj = Rcs->new;
    $obj->rcsdir("${topdir}/RCS");
    $obj->workdir("${topdir}");

    my($old) = $query->param('o');
    my($new) = $query->param('n');
    chomp($new);
    chomp($old);

    $obj->file($file);

    my $head_rev = $obj->head;
    my $locker = $obj->lock;
    my $author = $obj->author;
    my @access = $obj->access;
    my @revisions = $obj->revisions;
    my $filename = $obj->file;

    my($numrevisions) = $#revisions + 1;

    $obj->quiet(1);

    if (defined $old && $old >= 0
	&& defined $new && $new >= 0) {
      my %paths;
      my(%nodes);
      my(%asns);

      # call in scalar context to see if working file has changed
      my $changed = $obj->rcsdiff;
      my(@diffs);
      if ($changed) {
	#  print "Working file has changed\n";
	@diffs = $obj->rcsdiff;
      } else {
	@diffs = $obj->rcsdiff("-bwu20", "-r${revisions[$new]}", "-r${revisions[$old]}");
      }

      my(@dpath);
      my(@dminus);
      for my $d (@diffs) {
	#  print STDERR $d . "\n";
	chomp $d;
	if ($d !~ /\|$/){
	  $d .= "|";
	}
	my($j, $ip, $asn) = split(/\|/, $d);
	if (! defined($asn) || $asn eq "" || $asn eq "*"){
	  $asn = -1;
	}
	next unless ($j =~ /^( |\+|\-)(.*)/);
	my($modifier) = $1;
	$j = $2;

	next if (!defined $ip);
	next if ($ip eq "");

	if ($ip eq "*" || $ip eq "") {
	  $ip = "unk${j}";
	  $nodes{$ip} = "*";
	  $asns{$ip} = "*";
	}

	if ($nodes{$ip}) {
	} else {
	    $nodes{$ip} = getptr($ip);
	}

	if ($asns{$ip}){
	} else {
	  $asns{$ip} = $asn;
	}
  
	if ($modifier eq " ") {
	  $dpath[$j] = $ip;
	  $dminus[$j] = $ip;
	} elsif ($modifier eq "-") {
	  $dminus[$j] = $ip;
	} elsif ($modifier eq "+") {
	  $dpath[$j] = $ip;
	}
      }

      if ($#dminus > 0) {
	shift(@dminus);
	$paths{"dminus"} = "\"" . join('" -> "', @dminus) . "\" [color=\"red\"] \;" ;
      }
      if ($#dpath > 0) {
	shift(@dpath);
	$paths{"dpath"} = "\"" . join('" -> "', @dpath) . "\"\;" ;
      }

      my($dot) =<<HEAD;
strict digraph trdiff {
        ratio= "auto";
        compound="true";
        fontsize=8;

        node [shape="oval", fontsize=6];
        edge [arrowsize="0.4", penwidth="0.5", color="black"];

HEAD

      for my $n (keys %nodes) {
	my($label) = "$nodes{$n}\\nAS${asns{$n}}";
	if ($n ne $nodes{$n}) {
	  $label = "${label}\\n${n}";
	}
	$dot .= <<NN;
"$n" [label="${label}"];
NN
      }

      for my $k (keys %paths) {
	$dot .= $paths{$k} . "\n";
      }

      $dot .= <<TAIL;
}
TAIL

      if ( keys %nodes == 0 &&  keys %paths == 0) {
	print "Content-type: text/html\n\n";
	print <<LLI;
No diffs found between versions ${new} and ${old}.
LLI
      } else {
	my($tmpfile) = "/tmp/" . $$ . "trdiff.dot";

	my($fh) = new FileHandle("> $tmpfile");
	if ($fh) {
	  print $fh $dot;
	  $fh->close;
	  print "Content-type: image/svg+xml\n\n";
	  print `/usr/local/bin/dot -Tsvg ${tmpfile}`;
	  unlink($tmpfile);
	}
      }
    } else {
      print "Content-type: text/html\n\n";
      my %DatesHash = $obj->dates;
      my($rrdfile) = $topdir . "/" . $file;
      $rrdfile =~ s/\.txt$/\.rrd/i;
      $rrdfile =~ s/data\/tr/data\/\/tr/;
      $rrdfile =~ s/\//%2F/g;
#%2Fhome%2Frpaditya%2Fdata%2F%2Ftr%2Ftraceroute6%2F2607_F018_699_FFFF__1---mu.ilab.umnet.umich.edu-2607_f018_699_ffff__1.rrd
      print <<HEAD;
<a target="trdiff" 
href="/drraw/drraw.cgi?Template=1324687476.11169&Mode=view&Base=${rrdfile}">
host traceroute path time
</a>
<form action="trdiff.cgi" target="trdiff">
<input type="hidden" name="f" value="${file}" />
<input type="hidden" name="v" value="${ver}" />
<input type="submit" name="submit" value="diff ${file}" />
<table border="1">
<tr><th>new</th><th>old</th><th>rev</th><th>date</th></tr>
HEAD
      for (my $i=0; $i<=$#revisions; $i++) {
	my($ts) = formatTimestamp(${DatesHash{$revisions[$i]}});
	print <<LLI;
<tr>
<td><input type="radio" name="o" value="${i}" /></td>
<td><input type="radio" name="n" value="${i}" /></td>
<td>$revisions[$i]</td>
<td>${ts}</td>
<td>${DatesHash{$revisions[$i]}}</td>
</tr>
LLI
      }
      print <<TAIL;
</table>
</form>
TAIL
    }
  }
}

sub formatTimestamp {
  my($ctime) = @_;
  if ($ctime) {
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ctime);
    $year += 1900;
    $mon += 1;
    return sprintf("%02d/%02d/%04d %02d:%02d:%02d", $mon, $mday,$year, $hour, $min, $sec);
  } else {
    return undef;
  }
}
