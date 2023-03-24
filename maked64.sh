#!/usr/bin/bash

c1541 -format chessreplay,rr d64 chessreplay.d64 -attach chessreplay.d64 -write chessreplay.prg chessreplay
c1541 -attach chessreplay.d64 -write chessdata
