# Workplan for Chord-on-demand

1. Implement the T-Man algorithm
2. Integrate Chord jump-starting using T-Man
3. Add fingers management
4. Implement and test failure-resilience (list of k successors, regular maintenance by testing nodes aliveness, ...)

# Notes

For each ideal finger id: select 1 node from the view at each iteration
Basically, have one T-man operating on m T-man views of 1 node.