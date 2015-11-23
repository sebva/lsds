#!/bin/zsh
echo 'Parsing logs'
find . -name 'task-*.txt' | while read filename;do
	grep 'hops_for_query' $filename | sed -r 's/^.*  hops_for_query ([0-9]{1,2})$/\1/g' | sort -n | uniq -c | awk '{$1=$1};1' > $filename.plotdata
done

echo "Generating plots"
find . -name '*.gp' -exec gnuplot '{}' \;

echo "Done"

