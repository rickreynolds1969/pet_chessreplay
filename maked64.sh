#!/bin/bash

# C1541=/usr/bin/c1541
C1541=/Applications/vice-gtk3-3.5/bin/c1541
d=$(pwd)

$C1541 -format chessreplay,rr d64 $d/chessreplay.d64 -attach $d/chessreplay.d64 -write $d/chessreplay.prg chessreplay
$C1541 -attach $d/chessreplay.d64 -write $d/chessdata
