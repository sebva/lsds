#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $filepath = 'e70f1e15a52eb9ddc6ccc578b0d19b14.txt';

open(my $file_handle, '<', $filepath);

my $first = 1;
my $start_time;
while(my $line = <$file_handle>) {
    if($line =~ /^(\d+):(\d+):(\d+)\.(\d+) \((\d+)\)  i_am_infected/) {
        my ($hour, $min, $sec, $msec, $node_id) = ($1, $2, $3, $4, $5);
        if($first) {
            $first = 0;

        }
    }
}
close($file_handle);