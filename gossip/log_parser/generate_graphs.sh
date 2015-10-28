#!/bin/zsh
echo 'Parsing logs'
find . \( -name 'rm_*.txt' -o -name 'pss_*.txt' \) -exec perl parse_log.pl '{}' \;
find . -name 'pss_h*.txt' | while read filename;do
	tac $filename > $filename.rev
done

echo 'Checking PSS partition'
find . -name 'pss_h*.txt' | while read filename;do
	echo "\n$filename"
	echo -n 'At t0: '
	ruby pss_check_partition.rb $filename | grep connected
	echo -n 'At t_end: '
	ruby pss_check_partition.rb $filename.rev | grep connected
done

echo "\nGenerating plots"
find . -name 'pss_h*.txt.rev' | while read filename;do
	ruby pss_check_indegrees.rb $filename | grep -v Warning > $filename.indegrees.plotdata
	ruby pss_check_clustering.rb $filename | grep -v Warning > $filename.clustering.plotdata
done
find . -name '*.gp' -exec gnuplot '{}' \;

