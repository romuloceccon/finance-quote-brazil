#! /usr/bin/perl -w

# Syntax: getquote.pl <method> <symbol1> ... <symboln>

use strict;
use warnings;

use Finance::Quote;

my $quoter = Finance::Quote->new();
my %funds = $quoter->fetch(@ARGV);

my %symbols;

foreach my $key (keys %funds) {
  my ($a, $b) = split(/$;/, $key);
  $symbols{$a} = 1;
}

foreach my $t (sort keys %symbols) {
  if ($funds{$t, 'success'}) {
    print "$t: " . $funds{$t, 'last'} . " \@ " . $funds{$t, 'isodate'} . " (last)\n";
  }
  else {
    print "$t: [error] " . $funds{$t, 'errormsg'} . "\n";
  }
}
