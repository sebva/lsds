set term pdf font "Helvetica, 10"

set output "../report/query_distribution.pdf"
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
set xrange [0:] # example of a range closed on one side only, the max will determined automatically

plot \
     "query-fingers-oldschool.txt.plotdata" using 1:xtic(5) title "With finger table, traditional Chord",\
     "query-fingers.txt.plotdata" using 1:xtic(5) title "With finger table, bootstrapped by T-Man",\
     "query-nofingers.txt.plotdata" using 1:xtic(5) title "Without finger table"


# $1 is column 1. You can do arithmetics on the values of the columns
