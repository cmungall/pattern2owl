#!/usr/bin/perl
use strict;
use JSON;
my $id;
my $smap = {};
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
        next if $type =~ m@smiles@i;
        next if $type =~ m@inchi@i;
        next if $type =~ m@formula@i;
        next if $syn !~ m@[a-z]@;   # skip abbrevs and chem symbols
        next if $syn =~ m@_@;   # skip weird stuff, e.g. grouped_by_chemistry in CHEBI
        next if $syn =~ m@\@\w+$@;   # skip lang tags
        $syn =~ s@\"@'@g;
        $syn =~ s@\\@@g;
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
