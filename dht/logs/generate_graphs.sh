#!/bin/zsh
echo 'Parsing logs'
find . -name 'task-*.txt' | while read filename;do
	grep 'hops_for_query' $filename | sed -r 's/^.*  hops_for_query (-?[0-9]{1,2})$/\1/g' | sort -n | uniq -c | awk '{$1=$1};1' | sed 's/-1/Failed/' > $filename.plotdata
done
find . -name 'stale-*.txt' | while read filename;do
    ./parse_stale.pl $filename > $filename.plotdata
done
./parse_task-34.pl task-34.txt > task-34-queries.plotdata
echo "Generating plots"
find . -name '*.gp' -exec gnuplot '{}' \;

echo "Done"

