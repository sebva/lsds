#!/usr/bin/env perl

use strict;
use warnings;

my $stale_sum_for_period = 0;
my $non_nil_sum_for_period = 0;
my $ref_time = -1;
my $period_counter = 1;
my $CHECK_STALE_PERIOD = 20; # Adapt to value in the lua script
my $active_nodes = 0;

open(my $handle, '<', $ARGV[0]);
while (my $line = <$handle>) {
    if ($line =~ /^(.+) \(.+nb_stale ([0-9]+) ([0-9]+)$/) {
        my $unixtime = `date -d $1 +%s`;
        $ref_time = $unixtime if $ref_time == -1;
        
        if ($unixtime > $ref_time + $CHECK_STALE_PERIOD) {
            my $percent = 0;
            $percent = ($stale_sum_for_period / $non_nil_sum_for_period) * 100.0 if $non_nil_sum_for_period > 0;
            print "$period_counter\t$percent\t$active_nodes\t$stale_sum_for_period\t$non_nil_sum_for_period\n";
            
            $period_counter += $CHECK_STALE_PERIOD;
            $ref_time = $unixtime;
            $stale_sum_for_period = 0;
            $non_nil_sum_for_period = 0;
        }
        $stale_sum_for_period += $2;
        $non_nil_sum_for_period += $3;
    }
    elsif ($line =~ /END_LOG/) {
        $active_nodes--;
    }
    elsif ($line =~ /START_LOG/) {
        $active_nodes++;
    }
}

