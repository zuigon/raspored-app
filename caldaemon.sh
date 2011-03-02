#!/bin/bash
# $1 - interval (sec.)

T=300
if [[ $1 != "" ]]; then T=$1; fi

while [ 1 ]; do
  ./get-cal.sh > /dev/null
  sleep $T
done
