#!/bin/zsh
echo 'Parsing logs'
./parse_tman.pl tman.txt > tman_convergence.plotdata
echo "Generating plots"
find . -name '*.gp' -exec gnuplot '{}' \;

echo "Done"

