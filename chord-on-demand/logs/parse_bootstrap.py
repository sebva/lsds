import os
import re
from subprocess import check_output

tman_iterations = 20



def parse_check_ring_line(x):
    m = re.search(r'.*check_ring [0-9]{1,2} ([0-9 ]+)', x)
    return [int(x) for x in m.group(1).split(' ')]


def ring_plot(file_handle, ideal_ring):
    for i in range(1, tman_iterations + 1):
        file_handle.seek(0)
        check_ring_lines = sorted([parse_check_ring_line(x) for x in file_handle if re.match(".*check_ring %d .*" % i, x)], key=lambda a: a[0])
        success = sum([1 for i in range(len(check_ring_lines)) if check_ring_lines[i][1] == ideal_ring[(i+1) % len(ideal_ring)]])

        print(success)


def compute_ideal_ring():
    all_nodes = check_output(r"grep 'check_ring 1 ' bootstrap.txt | sed -r 's/.*check_ring 1 ([0-9]+).*/\1/g' | sort -n | uniq", shell=True)
    return [int(x) for x in all_nodes.decode('utf-8').split("\n") if x]


if __name__ == '__main__':
    with open('bootstrap.txt') as file_handle:
        ring_plot(file_handle, compute_ideal_ring())