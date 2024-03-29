set term pdf font "Helvetica, 10"

# some line types with different colors, you can use them by using line styles in the plot command afterwards (linestyle X)
set style line 1 lt 1 lc rgb "#FF0000" lw 3 # red
set style line 2 lt 1 lc rgb "#00FF00" lw 3 # green
set style line 3 lt 1 lc rgb "#0000FF" lw 3 # blue
set style line 4 lt 1 lc rgb "#000000" lw 3 # black
set style line 5 lt 1 lc rgb "#CD00CD" lw 3 # purple
set style line 6 lt 3 lc rgb "#000000" lw 3 # black, dashed line

set output "../report/task-22.pdf"
set title "Hop-count distribution for random queries on 64 nodes"

# indicates the labels
set xlabel "Number of hops"
set ylabel "Number of queries"

# set the grid on
set grid x,y

# set the grid on
set xtics 5
#set ytics 100
#set grid xtics
#set grid xtics ytics

# set graphic as histogram
set style data histogram
set style histogram clustered gap 1
#set style data histogram
#set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 1.5

# set the key, options are top/bottom and left/right
set key top right

# indicates the ranges
set yrange [0:] # example of a closed range (points outside will not be displayed)
set xrange [-1:] # example of a range closed on one side only, the max will determined automatically

plot "task-22.txt.plotdata" using 1:xtic(5) title "Without finger table",\
     "task-25.txt.plotdata" using 1:xtic(5) title "With finger table"


# $1 is column 1. You can do arithmetics on the values of the columns
