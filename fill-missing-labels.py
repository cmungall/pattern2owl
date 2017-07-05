#!/usr/bin/env python3

__author__ = 'cjm'

import argparse
import logging
import requests
import sys
import os
from contextlib import closing
import csv
from cachier import cachier
import datetime

SHELF_LIFE = datetime.timedelta(days=7)

#from yaml import load, dump
#from yaml import Loader, Dumper
import yaml



def main():
    logging.basicConfig(level=logging.INFO)
    logging.info("WELCOME!")
    parser = argparse.ArgumentParser(description='CSV filler'
                                                 'Helper utils for CSVs',
                                     formatter_class=argparse.RawTextHelpFormatter)


    parser.add_argument('-r', '--replace', dest='replace', action='store_true',
                        help='If true, write in place')

    parser.add_argument('files',nargs='*')


    args = parser.parse_args()

    for f in args.files:
        fill_file(f, args)

def fill_file(fn, args):
    outfn = fn + '.tmp'
    outstream = open(outfn, 'w')
    input_file = csv.DictReader(open(fn), delimiter=',')
    w = csv.DictWriter(outstream, None)
    for row in input_file:
        for (k,v) in row.items():
            if k.find(" label") > -1:
               sk = k.replace(" label", "")
               if (v is None or v == "") and sk != 'iri':
                   id = row[sk]
                   label = get_label(id)
                   if label is not None:
                       row[k] = label
                       logging.info("Got label: {} = {}".format(id, label))
                   else:
                       logging.warn("No label for "+id)
        if w.fieldnames is None:
            dh = dict((h, h) for h in input_file.fieldnames)
            w.fieldnames = input_file.fieldnames
            w.writerow(dh)
        w.writerow(row)
    outstream.close()
    if (args.replace):
        logging.info("Moving {} -> {}".format(outfn,fn))
        os.rename(outfn, fn)

@cachier(stale_after=SHELF_LIFE)
def get_label(id):
    url = 'http://localhost:5000/api/ontol/labeler/'
    with closing(requests.get(url, data={'id':id}, stream=False)) as resp:
        ok = resp.status_code == 200
        if not ok:
            logging.warn("UH OH")
        json = resp.json()
        return json[id]
    
if __name__ == "__main__":
    main()

    
    
