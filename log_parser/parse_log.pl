#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $filepath = 'e70f1e15a52eb9ddc6ccc578b0d19b14.txt';

my $first = 1;
my $start_time;
my @to_write = ();
my $total_nodes = 0;

open(my $input_file, '<', $filepath);
while(my $line = <$input_file>) {
    if($line =~ /^(\d+):(\d+):(\d+)\.(\d+) \((\d+)\)  i_am_infected/) {
        my ($hour, $min, $sec, $msec, $node_id) = ($1, $2, $3, $4, $5);
        $total_nodes++;
        if($first) {
            $first = 0;
            $start_time = convert_time_to_msec($hour, $min, $sec, $msec);
        }
        push @to_write, convert_time_to_msec($hour, $min, $sec, $msec) - $start_time;
    }
}
close($input_file);

open(my $output_file, '>', 'data.txt');
my $infected_nodes = 1;
foreach my $elapsed (@to_write) {
    print $output_file "$elapsed\t$infected_nodes\t" . ($infected_nodes / $total_nodes) . "\n";
    $infected_nodes++;
}
close($output_file);

sub convert_time_to_msec {
    my ($hour, $min, $sec, $msec) = @_;
    # return $msec + $sec * 1000 + $min * 1000 * 60 + $hour * 1000 * 3600;
    return $sec + $min * 60 + $hour * 3600;
}