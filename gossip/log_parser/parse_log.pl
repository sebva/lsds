#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $filepath = $ARGV[0];

my $first = 1;
my $start_time;
my @to_write = ();
my @duplicates = ();
my $total_nodes = 40;

open(my $input_file, '<', $filepath);
my $infected_nodes = 0;
while(my $line = <$input_file>) {
    if($line =~ /^(\d+):(\d+):(\d+)\.(\d+) \((\d+)\)  (1 |i_am_infected)/) {
        my ($hour, $min, $sec, $msec, $node_id) = ($1, $2, $3, $4, $5);
        $infected_nodes++;
        if($first) {
            $first = 0;
            $start_time = convert_time_to_msec($hour, $min, $sec, $msec);
        }
        push @to_write, convert_time_to_msec($hour, $min, $sec, $msec) - $start_time;
    }
	if($line =~ /^(\d+):(\d+):(\d+)\.(\d+) \((\d+)\)  duplicate_received/) {
        my ($hour, $min, $sec, $msec, $node_id) = ($1, $2, $3, $4, $5);
        push @duplicates, [convert_time_to_msec($hour, $min, $sec, $msec) - $start_time, $infected_nodes];
    }
}
close($input_file);

open(my $output_file, '>', $filepath . '.plotdata');
$infected_nodes = 1;
foreach my $elapsed (@to_write) {
    print $output_file "$elapsed\t$infected_nodes\t" . ($infected_nodes / $total_nodes) . "\n";
    $infected_nodes++;
}
close($output_file);

open($output_file, '>', $filepath . '.dup.plotdata');
open(my $output_file_2, '>', $filepath . '.dupnodes.plotdata');
my $duplicate_received = 1;
print $output_file "0\t0\n";
print $output_file_2 "0\t0\n";
foreach my $duplicate (@duplicates) {
	my ($elapsed, $nodes_infected) = ($duplicate->[0], $duplicate->[1]);
    print $output_file "$elapsed\t$duplicate_received\n";
    print $output_file_2 "$duplicate_received\t$nodes_infected\n";
    $duplicate_received++;
}
close($output_file);
close($output_file_2);

sub convert_time_to_msec {
    my ($hour, $min, $sec, $msec) = @_;
    # return $msec + $sec * 1000 + $min * 1000 * 60 + $hour * 1000 * 3600;
    return $sec + $min * 60 + $hour * 3600;
}