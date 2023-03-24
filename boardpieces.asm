#processor 6502
#seg code

;
; Recipe to setup the code with one basic line:
; 10 SYS 1040
;
; These three lines put that basic one-liner into the start of basic memory
; (on the PET that's at $0400).  Memory location 1040 (decimal) is $0410 (hex).
;
              org $0401
;                  0400   01   02   03   04   05   06   07
;                        [040e is addr of next basic line, which is end of program]
;                               |  [ 10 is line number - 0010 ]
;                               |         |  [ SYS ]
;                               |         |    |  [ space ]
;                               |         |    |    |  [ "1" ]
;                               |         |    |    |    |
              .byte      $0e, $04, $0a, $00, $9e, $20, $31

;                  0408   09   0a   0b   0c   0d   0e   0f
;                   [ "0" ]
;                     |  [ "4" ]
;                     |    |  [ "0" ]
;                     |    |    |  [ end of basic statement "00" ]
;                     |    |    |    |      [ end of basic program "00 00"]
;                     |    |    |    |                   |
              .byte $30, $34, $30, $00, $00, $00, $00, $00

              org $0410
              ldy #0
SCRLOOP:      lda SCREEN1,y
              sta $8000,y
              lda SCREEN1+$100,y
              sta $8100,y
              lda SCREEN1+$200,y
              sta $8200,y
              lda SCREEN1+$300,y
              sta $8300,y
              iny
              bne SCRLOOP
SPIN:         jmp SPIN
;             rts


;                     1    2    3    4    5    6    7    8    9   10   11   12   13   14   15   16   17   18   19   20
SCREEN1:      .byte $ea, $22, $f4, $55, $55, $49, $a0, $69, $e5, $55, $d6, $49, $a0, $db, $a0, $20, $4e, $65, $d5, $d5
              .byte $c9, $59, $22, $54, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $ea, $64, $f4, $67, $4e, $29, $a0, $64, $e5, $4d, $64, $4e, $a8, $d1, $a9, $67, $64, $65, $a0, $4e
              .byte $a9, $59, $64, $54, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $fc, $62, $fe, $6d, $40, $7d, $fc, $62, $fe, $6d, $40, $7d, $fc, $62, $fe, $6d, $40, $7d, $fc, $62
              .byte $fe, $6d, $40, $7d, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $20, $2e, $20, $a0, $ae, $a0, $20, $2e, $20, $a0, $ae, $a0, $20, $2e, $20, $a0, $ae, $a0, $20, $2e
              .byte $20, $a0, $ae, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $67, $64, $65, $a0, $64, $a0, $67, $64, $65, $a0, $64, $a0, $67, $64, $65, $a0, $64, $a0, $67, $64
              .byte $65, $a0, $64, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
; 5
              .byte $6d, $40, $7d, $fc, $62, $fe, $6d, $40, $7d, $fc, $62, $fe, $6d, $40, $7d, $fc, $62, $fe, $6d, $40
              .byte $7d, $fc, $62, $fe, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0
              .byte $a0, $20, $20, $65, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0
              .byte $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0
              .byte $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $d5, $56, $c9, $20, $5b, $20, $a0, $a0, $a0, $20, $20
              .byte $20, $a0, $a0, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
; 10
              .byte $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $df, $64, $e9, $28, $57, $29, $a0, $a0, $a0, $20, $20
              .byte $20, $a0, $a0, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $fc, $62, $fe, $6d, $40, $7d, $a0, $a0, $a0, $20, $20
              .byte $20, $a0, $a0, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $55, $d6, $49, $a0, $db, $a0, $20, $20, $20, $a0, $a0
              .byte $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $5f, $e4, $69, $a8, $d7, $a9, $20, $20, $20, $a0, $a0
              .byte $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $7c, $e2, $7e, $ed, $c0, $fd, $20, $20, $20, $a0, $a0
              .byte $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
; 15
              .byte $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20
              .byte $20, $a0, $a0, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20
              .byte $20, $a0, $a0, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20, $20, $a0, $a0, $a0, $20, $20
              .byte $20, $a0, $a0, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $a0, $ae, $a0, $20, $2e, $20, $a0, $ae, $a0, $20, $2e, $20, $a0, $ae, $a0, $20, $2e, $20, $a0, $ae
              .byte $a0, $20, $2e, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $e7, $e4, $e5, $20, $e4, $20, $e7, $e4, $e5, $20, $e4, $20, $e7, $e4, $e5, $20, $e4, $20, $e7, $e4
              .byte $e5, $20, $e4, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
; 20
              .byte $ed, $c0, $fd, $7c, $e2, $7e, $ed, $c0, $fd, $7c, $e2, $7e, $ed, $c0, $fd, $7c, $e2, $7e, $ed, $c0
              .byte $fd, $7c, $e2, $7e, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $6a, $a2, $74, $d5, $d5, $c9, $20, $e9, $65, $d5, $56, $c9, $20, $5b, $20, $a0, $af, $e5, $55, $55
              .byte $49, $d9, $a2, $d4, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $6a, $e4, $74, $e7, $af, $a9, $20, $e4, $65, $cd, $e4, $ce, $28, $51, $29, $e7, $e4, $e5, $20, $af
              .byte $29, $d9, $e4, $d4, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $7c, $e2, $7e, $ed, $c0, $fd, $7c, $e2, $7e, $ed, $c0, $fd, $7c, $e2, $7e, $ed, $c0, $fd, $7c, $e2
              .byte $7e, $ed, $c0, $fd, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

              .byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
              .byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20