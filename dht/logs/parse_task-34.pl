#!/usr/bin/env perl

use strict;
use warnings;

my $failed_queries_for_period = 0;
my $total_queries_for_period = 0;
my $total_hops_for_period = 0;
my $ref_time = -1;
my $period_counter = 1;
my $CHECK_STALE_PERIOD = 10; # Adapt to value in the lua script
my $active_nodes = 0;

open(my $handle, '<', $ARGV[0]);
while (my $line = <$handle>) {
    if ($line =~ /^(.+) \(.+hops_for_query (-?[0-9]+)$/) {
        my $unixtime = `date -d $1 +%s`;
        $ref_time = $unixtime if $ref_time == -1;
        
        if ($unixtime > $ref_time + $CHECK_STALE_PERIOD) {
            my $percent = 0;
            $percent = ($failed_queries_for_period / $total_queries_for_period) * 100.0 if $total_queries_for_period > 0;
            
            my $successful_queries_for_period = $total_queries_for_period - $failed_queries_for_period;
            my $avg_hops = 0;
            $avg_hops = $total_hops_for_period / $successful_queries_for_period unless $successful_queries_for_period == 0;
            
            print "$period_counter\t$percent\t$active_nodes\t$avg_hops\t$total_queries_for_period\t$failed_queries_for_period\n";
            
            $period_counter += $CHECK_STALE_PERIOD;
            $ref_time = $unixtime;
            $total_queries_for_period = 0;
            $failed_queries_for_period = 0;
            $total_hops_for_period = 0;
        }

        $total_queries_for_period ++;
        $total_hops_for_period += $2 unless $2 eq '-1';
        $failed_queries_for_period ++ if $2 eq '-1';
    }
    elsif ($line =~ /END_LOG/) {
        $active_nodes--;
    }
    elsif ($line =~ /START_LOG/) {
        $active_nodes++;
    }
}

