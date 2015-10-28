for /f %%f in ('dir /b .\rm_*.txt') do perl parse_log.pl %%f
for /f %%f in ('dir /b .\gnuplot_*.gp') do gnuplot %%f
