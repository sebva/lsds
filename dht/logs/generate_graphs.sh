#!/bin/zsh
echo 'Parsing logs'
grep 'hops_for_query' task-22.txt | sed -r 's/^.*  hops_for_query ([0-9]{1,2})$/\1/g' | sort -n | uniq -c | awk '{$1=$1};1' > task-22.plotdata

echo "Generating plots"
find . -name '*.gp' -exec gnuplot '{}' \;

echo "Done"

