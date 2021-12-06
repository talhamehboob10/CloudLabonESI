if (@ARGV != 2) {
    print STDERR "runpairs pairs-file num-at-once\n";
    exit(1);
}
my $file = $ARGV[0];
if (! -e "$file") {
    print STDERR "file does not exist\n";
    exit(1);
}
my $atonce = $ARGV[1];
if ($atonce !~ /^(\d+)$/) {
    print STDERR "must be a number\n";
    exit(1);
}

# Groups the pairs in the file into a non-conflicting schedule
if (!open(FD, "<$file")) {
    print STDERR "$file: cannot open\n";
    exit(1);
}

my $ix = 0;
my @groups = ();
while (my $pair = <FD>) {
    my %hosts = ();

}
