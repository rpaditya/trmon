#
# modified from http://www.sixxs.net/archive/tools/ip6_arpa.pl
#
use Socket;
use Socket6;
use Net::DNS;

sub getptr {
  my $v6;
  my($origip) = @_;
  my($ip) = $origip;

  if (($v6 = ($ip =~ m;^([0-9a-fA-f:]+)(?::(\d+\.\d+\.\d+\.\d+))?(?:/(\d+))?$;))
      || $ip =~ m;^(\d+\.\d+\.\d+\.\d+)(?:/(\d+))?$;) {
    my $valid = 1;
    if ($v6) {
      my (@chunk) = split(/:/, $1, 99);
      my $mask = $3;
      if ($2) {
	my (@v4) = split(/\./, $2);
	$valid = ($v4[0] <= 255 && $v4[1] <= 255 &&
		  $v4[2] <= 255 && $v4[3] <= 255);
	if ($valid) {
	  push(@chunk, sprintf("%x%02x", $v4[0], $v4[1]));
	  push(@chunk, sprintf("%x%02x", $v4[2], $v4[3]));
	}
      }
      my $pattern = "";
      if ($valid) {
	foreach (@chunk) {
	  $pattern .= /^$/ ? 'b' : 'c';
	}
	if ($pattern =~ /^bbc+$/) {
	  @chunk = (0, 0, @chunk[2..$#chunk]);
	  @chunk = (0, @chunk) while ($#chunk < 7);
	} elsif ($pattern =~ /^c+bb$/) {
	  @chunk = (@chunk[0..$#chunk-2], 0, 0);
	  push(@chunk, 0) while ($#chunk < 7);
	} elsif ($pattern =~ /^c+bc+$/) {
	  my @left;
	  push(@left, shift(@chunk)) while ($chunk[0] ne "");
	  shift(@chunk);
	  push(@left, 0);
	  push(@left, 0) while (($#left + $#chunk) < 6);
	  @chunk = (@left, @chunk);
	}
	$valid = $#chunk == 7;
      }
      my $ip6arpa = "ip6.arpa";
      my $i;
      if ($valid) {
	foreach (@chunk) {
	  $i = hex($_);
	  if ($i > 65535) {
	    $valid = 0;
	  } else {
	    $ip6arpa = sprintf("%x.%x.%x.%x.",
			       ($i) & 0xf,
			       ($i >> 4) & 0xf,
			       ($i >> 8) & 0xf,
			       ($i >> 12) & 0xf)
	      . $ip6arpa;
	  }
	}
      }
      if ($valid && defined($mask)) {
	$valid = ($mask =~ /^\d+$/ && $mask <= 128);
	if ($valid) {
	  $ip6arpa = substr($ip6arpa, int((128-$mask)/4)*2);
	  if ($mask &= 3) {
	    $i = hex(substr($ip6arpa, 0, 1));
	    $i >>= (4-$mask);
	    substr($ip6arpa, 0, 1) = sprintf("%x", $i);
	  }
	}
      }
      $ip = $ip6arpa if ($valid);
    } else {
      # v4
      my (@v4) = split(/\./, $1);
      my $mask = $2;
      $valid = ($v4[0] <= 255 && $v4[1] <= 255 &&
		$v4[2] <= 255 && $v4[3] <= 255);
      my $v4 = hex(sprintf("%02X%02X%02X%02X", @v4));
      if ($valid && defined($mask)) {
	$valid = ($mask =~ /^\d+$/ && $mask <= 32);
	if ($valid) {
	  $v4 = $v4 & ((~0) << (32-$mask));
	  $v4[0] = ($v4 >> 24) & 255;
	  $v4[1] = ($v4 >> 16) & 255;
	  $v4[2] = ($v4 >> 8) & 255;
	  $v4[3] = $v4 & 255;
	}
      } else {
	$mask = 32;
      }
      if ($valid) {
	my $i = 4 - int(($mask+7) / 8);
	pop(@v4) while ($i--);
	$ip = join('.', reverse(@v4));
	$ip .= '.' if ($ip ne "");
	$ip .= 'in-addr.arpa';
      }
    }
  }

  my($name) = $origip;
  my($n) =  $ip . "." ;
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->query($n, "PTR");
  if ($query) {
    foreach my $rr ($query->answer) {
      #	print $rr->rdatastr;
      $name =  $rr->rdatastr;
      #	$name =~ s/\-/_/g;
    }
  } else {
    #	warn "query failed (${name}): ", $res->errorstring, "\n";
  }

  return $name;
}

1;
