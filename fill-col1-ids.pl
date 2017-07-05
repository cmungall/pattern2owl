#!/usr/bin/perl
use strict;

my $dry_run = 0;
my $max = 999999999;
my $min = 0;
my $skip_dupes = 0;
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
    elsif ($opt eq '--skip-dupes') {
        $skip_dupes = 1;
    }
    else {
        die $opt;
    }
}


my @files = @ARGV;
my %pfxh = ();
my %minmap = ();
my %lenmap = ();

my $n_uuids = 0;
foreach my $f (@files) {
    print STDERR "Pre-processing: $f\n";

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
            elsif (is_uuid($id)) {
                $n_uuids++;
            }
            else {
                die "INVALID ID: $id in: $_ in $f";
            }
        }
    }
    close(F);
}
if ($n_uuids) {
    print STDERR " * UUIDS: $n_uuids\n\n"
}

my %done=();
my %done_in=();
my $total=0;
foreach my $f (@files) {
    print STDERR "Processing: $f\n";
    open(F,$f);
    my @lines = <F>;
    close(F);

    my $n=0;

    my $line_num = 0;
    open(F,">$f.tmp") || die "writing to $f";
    my $N_COLS;
    foreach (@lines) {
        $line_num++;
        if (m@  @) {
            die "DOUBLE SPACE: $_";
        }
        my ($id,$lbl,@rest) = split_csvline($_);
        if ($N_COLS) {
            if (scalar(@rest) != $N_COLS) {
                die "wrong number of cols: $_\n";
            }
        }
        $N_COLS = scalar(@rest);
        my $val = "";
        for (my $i=0; $i<@rest; $i+=2) {
            $val .= $rest[$i];
        }
        if (grep {m@ \! @} @rest) {
            die "UH OH: $_";
        }

        # first check for duplicated IDs (always fatal)
        if ($done{$id} && $id ne 'iri' && $id) {
            print STDERR "DUPLICATED ID: (ID:$id FILE:$f), ($done{$id} $done_in{$id}) => $val in: $_";
            die "FATAL: Duplicated primary ID";
        }

        # next check for duplicate slotval tuples
        # (may be valid)
        if ($done{$val} && $id ne 'iri') {
            print STDERR "DUPLICATED SLOT VALS: (ID:$id FILE:$f), ($done{$val} $done_in{$val}) => $val in: $_";
            if ($skip_dupes) {
                $n++;
                # don't actually skip
                #next;
            }
            else {
                die "DUPE";
            }
        }
        $done{$val} = $id;
        $done{$id} = $val;
        $done_in{$val} = "$line_num: $f";
        $done_in{$id} = "$line_num: $f";
        if (!$id || is_uuid($id)) {
            $n++;
            if (is_uuid($id)) {
                # remove UUID
                s@^[a-zA-Z0-9\-]+@@;
            }
            $id = next_id();
            print STDERR "NEWID: $id $lbl\n";
            $_ = "$id$_";
        }
        #print STDERR $_;
        print F $_;
    }
    close(F);
    if ($n) {
        print STDERR "FILE: $f ADDED: $total\n";
        print `mv $f.tmp $f` unless $dry_run;
        $total += $n;
    }
    else {
        print STDERR "NO CHANGE: will not write\n";
        `rm $f.tmp`;
    }
}
print STDERR "TOTAL CHANGED: $total\n";
exit 0;

sub is_uuid {
    my $s = shift;
    if ($s =~ m@^[0-9a-f\-]+$@ && $s =~ m@\-@) {
        return 1;
    }
    else {
        return 0;
    }
}

sub add_id {
    my ($prefix,$frag) = @_;

    if ($frag =~ m@a-z@i) {
        warn "IGNORING: $prefix:$frag";
        return;
    }
    
    #print STDERR "REGISTER: $prefix $frag\n";
    $pfxh{$prefix}++;
    my $len = length($frag);
    if ($len > $lenmap{$prefix}) {
        if ($len > 7) {
            warn "LEN: $len for $prefix in $frag";
        }
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
        die "multiple prefixes: @pfxs";
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

sub split_csvline {
    my $line = shift;
    chomp $line;
    if ($line =~ m@\t@) {
        return split(/\t/,$_);
    }
    my @vals = split(/,/,$_);
    my @rvals = ();
    while (@vals) {
        my $v = shift @vals;
        chomp $v;
        while ($v =~ m@^\"@ && $v !~ m@\"\s*$@) {
            if (@vals) {
                $v .= shift @vals;
            }
            else {
                die "unclosed: '$v'\n";
            }
        }
        push(@rvals, $v);
    }
    return @rvals;
}
