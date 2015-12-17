#!/bin/zsh
echo 'Parsing logs'

find . -name 'bootstrap-*.txt' | while read filename;do
    ./parse_bootstrap.py $filename > $filename.plotdata
    ./parse_tman.pl $filename > $filename.tman.plotdata
done

find . -name 'query-*.txt' | while read filename;do
	grep 'hops_for_query' $filename | sed -r 's/^.*  hops_for_query (-?[0-9]{1,2})$/\1/g' | head -n `grep 'hops_for_query' query-nofingers.txt | wc -l` | sort -n | uniq -c | awk '{$1=$1};1' | sed 's/-1/Failed/' > $filename.plotdata
done


echo "Generating plots"
find . -name '*.gp' -exec gnuplot '{}' \;

echo "Done"

