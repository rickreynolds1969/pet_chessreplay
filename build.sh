#!/bin/bash

DASM=~/dasm_bin/dasm

[ -n "$1" ] || { echo "Build what, exactly?" ; exit 1 ; }

basenm=$(echo $1 | rev | cut -f 2- -d '.' | rev)
srcfile="${basenm}.asm"
outfile="${basenm}.prg"
[ -f "$srcfile" ] || { echo "I don't see a $srcfile file here..." ; exit 1 ; }

cmd="$DASM $srcfile -v5 -f1 -o${outfile}"
echo $cmd
$cmd
