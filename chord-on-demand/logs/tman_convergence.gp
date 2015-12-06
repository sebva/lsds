set term pdf font "Helvetica, 10"

# some line types with different colors, you can use them by using line styles in the plot command afterwards (linestyle X)
set style line 1 lt 1 lc rgb "#FF0000" lw 3 # red
set style line 2 lt 1 lc rgb "#00FF00" lw 3 # green
set style line 3 lt 1 lc rgb "#0000FF" lw 3 # blue
set style line 4 lt 1 lc rgb "#000000" lw 3 # black
set style line 5 lt 1 lc rgb "#CD00CD" lw 3 # purple
set style line 6 lt 3 lc rgb "#ffa500" lw 3 # orange

set output "../report/tman_convergence.pdf"
set title "Convergence with T-Man"

# indicates the labels
set xlabel "Time (s)"
set ylabel "Avg. distance between nodes"

# set the grid on
set grid x,y

# set the key, options are top/bottom and left/right
set key off

# indicates the ranges
set yrange [0:] # example of a closed range (points outside will not be displayed)
set xrange [0:] # example of a range closed on one side only, the max will determined automatically

plot\
"tman_convergence.plotdata" u ($1):($2) with lines linestyle 1 title "T-Man"

# $1 is column 1. You can do arithmetics on the values of the columns
