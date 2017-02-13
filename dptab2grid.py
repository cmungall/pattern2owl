#!/usr/bin/env python3

__author__ = 'cjm'

import argparse
import logging
import re
import yaml
import json
import uuid
import csv
import itertools
import sys
from collections import Counter

def main():

    delimiter=','
    parser = argparse.ArgumentParser(description='DOSDB'
                                                 'fooo',
                                     formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-i', '--input', type=str, required=False,
                        help='Input metadata file')
    
    args = parser.parse_args()

    input_file = csv.reader(open(args.input), delimiter=delimiter)
    rows = [row for row in input_file]
    
    nmap = {}
    grid = {}
    colmap = {}
    
    for row in rows:
        [iri,label,x,xl,y,yl] = row
        nmap[x] = xl
        nmap[y] = yl
        colmap[y] = 1
        if x not in grid:
            grid[x] = {}
        grid[x][y] = (iri,label)

    tdel = " | "
    tstart = "| "
    tend = " |\n"
    s = tstart
    for y in colmap.keys():
        s+= tdel + hlink(y, nmap[y])
    s+= tend
    s+= tstart + "---"
    for y in colmap.keys():
        s+= tdel + "---"
    s+= tend
    
    for (x,row) in grid.items():
        s+= tstart + hlink(x, nmap[x])
        for y in colmap.keys():
            v = ""
            if y in row:
                v = hlink(*row[y])
            s+= tdel + v
        s+= tdel + tend
    print(s)
            
def hlink(id,label):
    url = id2url(id)
    return "[{}]({})".format(label,url)

def id2url(id):
    if len(id.split(":")) == 2:
        [prefix,localid] = id.split(":")
    else:
        return id
    return 'http://purl.obolibrary.org/obo/{}_{}'.format(prefix,localid)

    
if __name__ == "__main__":
    main()

