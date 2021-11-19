#!/usr/bin/perl -w

use strict;

sub rlog {
    for (@_) {
	print STDERR $_;
    }
    print STDERR "\n";
}

sub rlogts {
    rlog(scalar(localtime()),": ",@_);
}

#mkdir("/var");
#mkdir("/var/log");
#open my $debuglog_fh ">>/var/log/entrypoint-debug.log";
#*STDOUT = $debuglog_fh;
#*STDERR = $debuglog_fh;

select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;

rlogts("run.pl starting emulation");

my $PREFIX = "/etc/emulab/docker";
my ($epI,$epR,$cmdI,$cmdR);
my %fmap = (
    "$PREFIX/entrypoint.image" => \$epI,
    "$PREFIX/entrypoint.runtime" => \$epR,
    "$PREFIX/cmd.image" => \$cmdI,
    "$PREFIX/cmd.runtime" => \$cmdR );
for my $fname (keys(%fmap)) {
    next
	if (! -e "$fname");
    my $size = (stat($fname))[7];
    next
	if ($size <= 0);
    my $vref = $fmap{$fname};
    open(FD,"$fname");
    if ($?) {
	rlog("ERROR: open($fname): $!");
	next;
    }
    my $line = <FD>;
    close(FD);
    if ($line =~ /^string:(.*)$/) {
	$$vref = pack("H*",$1);
    }
    elsif ($line =~ /^array:(.*)$/) {
	my @a = split(/,/,$1);
	@a = map { pack("H*",$_) } @a;
	$$vref = \@a;
    }
    else {
	rlog("ERROR: invalid line '$line' in $fname; skipping!");
	next;
    }
}

my @cmd = ();
# Prepend the helper to whatever we run.
for (my $i = 0; $i < @ARGV; ++$i) {
    push(@cmd,$ARGV[$i]);
}

# Add the entrypoint/cmd goo.
if (defined($epR) && ref($epR) ne 'ARRAY') {
    push(@cmd,"/bin/sh","-c",$epR);
}
elsif (defined($epI) && ref($epI) ne 'ARRAY') {
    push(@cmd,"/bin/sh","-c",$epI);
}
else {
    my $ep;
    if (defined($epR)) {
	$ep = $epR;
	push(@cmd,@{$epR})
    }
    elsif (defined($epI)) {
	$ep = $epI;
	push(@cmd,@{$epI})
    }
    for my $c ($cmdR,$cmdI) {
	if (defined($c) && ref($c) eq '') {
	    push(@cmd,"/bin/sh","-c",$c);
	    last;
	}
	elsif (defined($c) && ref($c) eq 'ARRAY') {
	    push(@cmd,@{$c});
	    last;
	}
    }
}

rlogts("Will exec '".join(" ",@cmd));

close(STDOUT);
close(STDERR);
open(STDOUT,">>","/var/log/entrypoint.log");
open(STDERR,'>&STDOUT');

exec(@cmd);
if ($?) {
    open(STDOUT,">>","/var/log/entrypoint-debug.log");
    open(STDERR,'>&STDOUT');
    rlogts("exec failed: $! ($?)");
    exit 999;
}
