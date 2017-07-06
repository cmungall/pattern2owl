#!/usr/bin/perl
use strict;
use JSON;
my $id;
my $smap = {};

# THIS WILL BE REPLACED

while(<>) {
    chomp;
    if (m@^id: (\S+)@) {
        $id = $1;
    }
    if (m@name: (.*)@) {
        push(@{$smap->{$id}},
             {
                 synonym => $1,
                 type => 'name',
                 scope => 'name',
                 xrefs => [$id]
             });
    }
    if (m@synonym: "(.*)" *(\w+) *(.*)@) {
        my ($syn, $scope, $rest) = ($1,$2,$3);
        my $type = 'default';
        my $xrefstr;
        if ($rest =~ m@^(\S+) *\[(.*)\]$@) {
            $type = $1;
            $xrefstr = $2;
        }
        elsif ($rest =~ m@^\[(.*)\]$@) {
            $xrefstr = $1;
        }
        else {
            die $rest;
        }
        my @xrefs = split(/,\s*/,$xrefstr);
        if ($type =~ m@CURATED@) {
        }
        else {
            next if $type =~ m@smiles@i;
            next if $type =~ m@inchi@i;
            next if $type =~ m@formula@i;
            next if $syn !~ m@[a-z]@ && $id =~ m@^CHEBI:@;   # skip abbrevs and chem symbols
            next if $syn =~ m@_@;   # skip weird stuff, e.g. grouped_by_chemistry in CHEBI
            next if $syn =~ m@\@\w+$@;   # skip lang tags
        }
        $syn =~ s@\"@'@g;
        $syn =~ s@\\@@g;
        $syn = filter_unicode($syn);
        push(@{$smap->{$id}},
             {
                 synonym => $syn,
                 type => $type,
                 scope => $scope,
                 xrefs => \@xrefs
             });
    }
}
my $json = new JSON;
print $json->pretty->encode( $smap ); 
exit 0;

sub filter_unicode {

    $_ = shift @ARGV;
    tr/\200-\377//d;
    tr [\200-\377]
        [\000-\177];   # see 'man perlop', section on tr/
    # weird ascii characters should be excluded
    tr/\0-\10//d;   # remove weird characters; ascii 0-8
    # preserve \11 (9 - tab) and \12 (10-linefeed)
    tr/\13\14//d;   # remove weird characters; 11,12
    # preserve \15 (13 - carriage return)
    tr/\16-\37//d;  # remove 14-31 (all rest before space)
    tr/\177//d;     # remove DEL character
    return $_;
    
}
