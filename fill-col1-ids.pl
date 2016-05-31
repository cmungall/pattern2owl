#!/usr/bin/perl
use strict;

my $dry_run = 0;
my $max = 999999999;
my $min = 0;
while ($ARGV[0] =~ m@^\-@) {
    my $opt = shift @ARGV;
    if ($opt eq '-n' || $opt eq '--dry-run') {
        $dry_run = 1;
    }
    elsif ($opt eq '-m' || $opt eq '--max') {
        $max = shift @ARGV;
    }
    elsif ($opt eq '--min') {
        $min = shift @ARGV;
    }
    else {
        die $opt;
    }
}

my @files = @ARGV;
my %pfxh = ();
my %minmap = ();
my %lenmap = ();


foreach my $f (@files) {
    print STDERR "T: $f\n";

    open(F,$f);
    while(<F>) {
        my ($id) = split(/[\t,]/,$_);
        if ($id) {
            if ($id =~ m@http://purl.obolibrary.org/obo/(\S+)_(\S+)@) {
                add_id($1,$2);
            }
            elsif ($id =~ m@^(\S+):(\S+)@) {
                add_id($1,$2);
            }
            elsif ($id =~ m@^(\S+)_(\S+)@) {
                add_id($1,$2);
            }
            elsif ($id eq 'iri') {
                # ok
            }
            else {
                die "INVALID ID: $id in: $_ in $f";
            }
        }
    }
    close(F);
}

my %done=();
my %done_in=();
my $total=0;
foreach my $f (@files) {
    print STDERR "F: $f\n";
    open(F,$f);
    my @lines = <F>;
    close(F);

    my $n=0;
    
    open(F,">$f.tmp") || die "writing to $f";
    foreach (@lines) {
        my ($id,$lbl,@rest) = split(/[\t,]/,$_);
        my $val = join(",",@rest);
        if ($done{$val} && $id ne 'iri') {
            print STDERR "DUPLICATION: ($id $f), ($done{$val} $done_in{$val}) => $val\n";
            if (!$id) {
                die "DUPE";
            }
        }
        $done{$val} = $id;
        $done_in{$val} = $f;
        if (!$id) {
            $n++;
            $id = next_id();
            print STDERR "NEWID: $id $lbl\n";
            $_ = "$id$_";
        }
        print F $_;
    }
    close(F);
    if ($n) {
        print STDERR "$f ADDED: $total\n";
        print `mv $f.tmp $f` unless $dry_run;
        $total += $n;
    }
    else {
        `rm $f.tmp`;
    }
}
print STDERR "ADDED: $total\n";
exit 0;


sub add_id {
    my ($prefix,$frag) = @_;
    #print STDERR "REGISTER: $prefix $frag\n";
    $pfxh{$prefix}++;
    my $len = length($frag);
    if ($len > $lenmap{$prefix}) {
        $lenmap{$prefix} = $len;
    }
    if (!$minmap{$prefix}) {
        $minmap{$prefix} = $min;
    }
    if ($frag > $minmap{$prefix} && $frag < $max) {
        $minmap{$prefix} = $frag;
    }
}

sub next_id {
    my @pfxs = keys %pfxh;
    if (@pfxs > 1) {
        die "@pfxs";
    }
    my $prefix = shift @pfxs;
    my $frag = $minmap{$prefix};
    #print STDERR "INC: $frag\n";
    $frag++;
    if ($frag >= $max) {
        die "$frag >= $max";
    }
    
    $minmap{$prefix} = $frag;
    my $PAD = $lenmap{$prefix};
    my $FMT = "$prefix:%0".$PAD."d";
    my $next_id = sprintf $FMT, $frag;
    return $next_id;
}
