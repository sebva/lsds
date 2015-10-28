set term pdf font "Helvetica, 10"

# some line types with different colors, you can use them by using line styles in the plot command afterwards (linestyle X)
set style line 1 lt 1 lc rgb "#FF0000" lw 3 # red
set style line 2 lt 1 lc rgb "#00FF00" lw 3 # green
set style line 3 lt 1 lc rgb "#0000FF" lw 3 # blue
set style line 4 lt 1 lc rgb "#000000" lw 3 # black
set style line 5 lt 1 lc rgb "#CD00CD" lw 3 # purple
set style line 6 lt 3 lc rgb "#000000" lw 3 # black, dashed line

set output "../report/indegrees.pdf"
set title "Peer-sampling service in-degree"

# indicates the labels
set xlabel "Cumulative in-degree"
set ylabel "Percentage of nodes"

# set the grid on
set grid x,y

# set the key, options are top/bottom and left/right
set key top left

# indicates the ranges
set yrange [0:100] # example of a closed range (points outside will not be displayed)
set xrange [0:] # example of a range closed on one side only, the max will determined automatically

plot\
"pss_h0_s0.txt.rev.indegrees.plotdata" u ($1):($3*2.5) with lines linestyle 1 title "H=0 S=0",\
"pss_h0_s0_rand.txt.rev.indegrees.plotdata" u ($1):($3*2.5) with lines linestyle 2 title "H=0 S=0, with rand select",\
"pss_h0_s4.txt.rev.indegrees.plotdata" u ($1):($3*2.5) with lines linestyle 3 title "H=0 S=4",\
"pss_h4_s0.txt.rev.indegrees.plotdata" u ($1):($3*2.5) with lines linestyle 4 title "H=4 S=0",\
"pss_h2_s2.txt.rev.indegrees.plotdata" u ($1):($3*2.5) with lines linestyle 5 title "H=2 S=2",\

# $1 is column 1. You can do arithmetics on the values of the columns
