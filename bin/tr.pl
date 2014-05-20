#!/usr/bin/perl -w

use strict;
$| = 1;

use FileHandle;
use RRDs;

require '/home/rpaditya/lib/monitor.pl';

my($hostname) = `/bin/hostname`;
chomp $hostname;

our($config);
$config->{'STEP'} = 3600;
$config->{'VC'} = "RCS";

sub update {
    my($type) = shift(@_);

    my($RRD);
    my($STEP) = $config->{'STEP'};

    next if (!defined($type) || $type eq "");
    if ($type eq "tr"){
      $RRD = shift(@_);
    }
    my(@vals) = @_;

    my($t) = time;
    $t = int($t);

    if (! -e $RRD){
        my($START) = time - (2 * $STEP);

        notify('info', "Creating $RRD with step ${STEP} starting at $START");
        my($v, $msg) = RRD_create($RRD, $START, $STEP, $type);
        if ($v){
        notify('err', "couldn't create $RRD because $msg");
        return;
      }
    }

    if ($config->{'DEBUG'}){
        my($msg) = "updateRRD{${RRD}, ${t}, " . join(", ", @vals);
        notify('debug', $msg);
    } else {
        my($rv, $errmsg) = updateRRD($RRD, $t, @vals);
        if ($rv){
                notify('err', "error updating $RRD : ${errmsg}");
        }
    }
}

sub RRD_create {
    my($RRD, $START, $interval, $type) = @_;
    my(@dses);
    my(@rras) = (
                 "RRA:AVERAGE:0.5:1:3000",
                 "RRA:MAX:0.5:1:3000",
                 "RRA:AVERAGE:0.5:5:3000",
                 "RRA:MAX:0.5:5:3000",
                 "RRA:AVERAGE:0.5:10:5000",
                 "RRA:MAX:0.5:10:5000",
                 "RRA:AVERAGE:0.5:1440:732",
                 "RRA:MAX:0.5:1440:732"
                 );
    if ($type eq "tr"){
      @dses = (
	       "DS:totalhops:GAUGE:7200:U:U",
	       "DS:totalt:GAUGE:7200:U:U",
	      );
      for (my $i=1;$i<=20;$i++){
	push(@dses, "DS:hop${i}t:GAUGE:7200:U:U");
      }
    } else {
        notify('ERR', "could not create RRD of type ${type}");
        return(1, "do not recognize type ${type}");
    }

    if ($config->{'DEBUG'}){
    } else {
      RRDs::create ("$RRD", "-b", $START, "-s", $interval, @dses, @rras);

      if (my $error = RRDs::error()) {
          return(1, "Cannot create $RRD: $error");
      } else {
	return(0, "$RRD");
      }
    }
}

while (<>) {
  chomp;
  next if (/(^$)|(^#)/);

  my($tr, $target, $maxttl, $wait)= split(/\|/);

  $config->{'dataDir'} = $ENV{'HOME'} . "/data/tr/${tr}";
  my($cmd) = "/usr/sbin/${tr} -a -n -q 1 -m ${maxttl} -w ${wait} ${target}";
  notify('debug', $cmd);

  my(@out) = `${cmd} 2>&1`;
  my($rv) = $?;
  my($rows) = $#out;

  my(@val);
  for (my $i = 0; $i < $maxttl; $i++) {
    $val[$i] = "UN";
  }

  if (! $rv) {
    my($rvtxt) = "got ${rv} for ${target}";
    notify("info", $rvtxt);
    my($fh);
    my($tothops, $totalt) = (0, 0);
    if (
	$out[0] =~ /${tr} to .* \((.*)\)/
	|| $out[1] =~ /${tr} to .* \((.*)\)/
       ) {
      my($destip) = $1;
      # RRD doesn't like colons in filenames
      $destip =~ s/\:/_/g; 
      $target =~ s/\:/_/g;
      my($outf) = $config->{'dataDir'} . "/" . $target . "---" . $hostname . "-" . $destip;
      my($outfile) = $outf  . ".txt";
      my($rrdout) = $outf . ".rrd";

      if (! -e $outfile){
	vci_create_and_add($outfile);
      }

      $fh = FileHandle->new("> ${outfile}");
      if (defined $fh) {
	for my $l (@out) {
	  # 6  2001:48a8:48ff:ff01::5  45.576 ms
	  # 7  2001:504:0:4::6939:1  8.216 ms
	  # 8  2001:470:0:6e::2  13.091 ms
	  #...
	  #11  [AS1200] 2001:7f8:1::a500:3333:2  108.791 ms
	  if ($l =~ /^\s*\d+\s+/) {
	    chomp($l);
	    $l =~ s/^\s+//g;
	    $l =~ s/\s+ms$//g;
	    my(@flds) = split(/\s+/, $l);
	    my($j, $asn, @t) = @flds;
	    if (
		($asn eq "*"
		 || $asn =~ /\!.*/)
	       ) {
	      $t[0] = $asn;
	      notify('err', "${target} miss: " . $t[0]);
	      $asn = -1;
	    } elsif (defined $t[1] && $t[1] ne "" && $t[1] * 1 == $t[1]) {
	      my($index) = $j - 1;
	      $val[$index] = $t[1];
	      $tothops++;
	      $totalt += $t[1];
	      $asn =~ /\[AS(\d+)\]/i;
	      $asn = $1 || 0;
	    }
#	    print STDERR "${j}|${asn}|" . join(':', @t);
	    print $fh "${j}|$t[0]|${asn}\n";
	  }
	}

	unshift(@val, $totalt);
	unshift(@val, $tothops);
	unshift(@val, $rrdout);
	unshift(@val, "tr");
	notify('debug', join('|', @val));
	if (defined $fh) {
	  $fh->close;
	}
	if (-e $outfile){
	  my($msg) = "tr path changed";
	  vci_commit_if_diff($outfile, $msg);
	}
	update(@val);
      } else {
	notify('crit', "could not write to ${outfile}: $!");
      }
    } else {
      notify('crit', "can't tell IP address of destination: ${target}");
    }
  } else {
    notify('crit', "${tr} returned ${rv} for ${target}");
  }
}

my($git) = "/usr/local/bin/git";
sub vci_create_and_add {
  my($outfile) = @_;
  my($rv) = $config->{'VC'} . " touch ${outfile}: " . `/usr/bin/touch ${outfile}`;
  if ($config->{'VC'} eq "Git"){
    chdir($config->{'dataDir'});
    $rv .= "add ${outfile}: " . `${git} add ${outfile}`;
    $rv .= " initial commit ${outfile}: " . `${git} commit -n -q --message="initial" ${outfile}`;
  } elsif ($config->{'VC'} eq "RCS"){
    $rv .= " add ${outfile}: " . `/usr/bin/ci -q -u -t-initial ${outfile}`;
    $rv .= " co-l ${outfile}: " . `/usr/bin/co -l -q ${outfile}`;
  }
  notify("info", $rv);
}

sub vci_commit_if_diff {
  my($outfile, $commit_msg) = @_;
  my($rv) = $config->{'VC'};
  if ($config->{'VC'} eq "Git"){
    chdir($config->{'dataDir'});
    my($msg) = `${git} diff ${outfile}`;
    if ($msg && $msg ne ""){
      chomp $msg;
      $rv .= `${git} commit -n -q --message="${commit_msg}"`;
    }
  } elsif ($config->{'VC'} eq "RCS"){
    my($msg) = `/usr/bin/rcsdiff -q -bw ${outfile}`;
    if ($msg && $msg ne ""){
      chomp $msg;
      $rv .= " update ${outfile}: " . `/usr/bin/ci -q -u -m"path changed" ${outfile}`;
      $rv .= " co-l ${outfile}: " . `/usr/bin/co -l -q ${outfile}`;
    }
  }
  if ($rv ne $config->{'VC'}){
    notify("info", $rv);
  }
}
