set term pdf font "Helvetica, 10"

# some line types with different colors, you can use them by using line styles in the plot command afterwards (linestyle X)
set style line 1 lt 1 lc rgb "#FF0000" lw 3 # red
set style line 2 lt 1 lc rgb "#00FF00" lw 3 # green
set style line 3 lt 1 lc rgb "#0000FF" lw 3 # blue
set style line 4 lt 1 lc rgb "#000000" lw 3 # black
set style line 5 lt 1 lc rgb "#CD00CD" lw 3 # purple
set style line 6 lt 3 lc rgb "#ffa500" lw 3 # orange

set output "../report/task-34-successes.pdf"
set title "Random queries while sustaining churn"

# indicates the labels
set xlabel "Time (s)"
set ylabel "Failed queries (%)\nActive nodes"
set y2label "Hop-count"

# set the grid on
set grid x,y

# set the key, options are top/bottom and left/right
set key top left

# indicates the ranges
set yrange [0:100] # example of a closed range (points outside will not be displayed)
set y2range [0:5]
set y2tics 1
set xrange [0:] # example of a range closed on one side only, the max will determined automatically

plot\
"task-34-queries.plotdata" u ($1):($2) with lines linestyle 1 title "Failed queries", \
"task-34-queries.plotdata" u ($1):($4) with lines linestyle 2 title "Average hop-count" axes x1y2, \
"task-34-queries.plotdata" u ($1):($3) with lines linestyle 4 title "Number of active nodes"

# $1 is column 1. You can do arithmetics on the values of the columns
