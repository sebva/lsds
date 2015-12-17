#!/usr/bin/env perl

use strict;
use warnings;
use List::Util qw(min);

my $distance_sum_for_period = 0;
my $amount_for_period = 0;
my $ref_time = -1;
my $period_counter = 1;
my $CHECK_STALE_PERIOD = 15; # Adapt to value in the lua script
my $m = 28;


open(my $handle, '<', $ARGV[0]);
while (my $line = <$handle>) {
    if ($line =~ /^(.+) \(.+TMAN ([0-9]+)(( [0-9]+)+)$/g) {
        my $unixtime = `date -d $1 +%s`;
        $ref_time = $unixtime if $ref_time == -1;
        
        my @neighbors = split / /, substr($3, 1);
        foreach my $neighbor (@neighbors) {
            $distance_sum_for_period += dist($2, $neighbor);
            $amount_for_period ++;
        }
        
        if ($unixtime > $ref_time + $CHECK_STALE_PERIOD) {
            print "$period_counter ", ($distance_sum_for_period / $amount_for_period), "\n";
        
            $distance_sum_for_period = 0;
            $amount_for_period = 0;
            
            $period_counter += $CHECK_STALE_PERIOD;
            $ref_time = $unixtime;
        }

    }
}

sub circ {
    my ($idx, $len) = @_;
    $idx % $len;
}

sub dist {
    my ($a, $b) = @_;
    
    min abs($a - $b), (2 ** $m -1) - abs($a - $b);
}

