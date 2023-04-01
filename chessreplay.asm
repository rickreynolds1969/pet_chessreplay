#processor 6502
#seg code

;
; Definitions
;

BL = $20          ; code for a black square on the chessboard
WH = $A0          ; code for a white square on the chessboard

; some zero-page pointers
SQUAREPTR = $4B   ; zero page location where I'll store the screen address of a square to draw
PIECEPTR = $4D    ; zero page location where I'll store the address of the piece being drawn
CHMOVEPTR = $4F   ; zero page location where I'll store the address of the move being drawn
SOURCEPTR = $51   ; zero page pointer to the text are on the screen, for scrolling
SCREENPTR = $53   ; zero page pointer to the text are on the screen, for scrolling

; locations and constants for file operations
KERNALCLOSE = $F2E2
KERNALREADCHAR = $F215
KERNALSETINPUT = $F7AF
KERNALOPENFILE = $F563

FILENAMELENLOC = $D1
FILENUMLOC = $D2
SECONDARYADDRNUMLOC = $D3
DEVICENUMLOC = $D4
FILENAMEPTR = $DA

FILENUM = 2
SECONDARYADDRNUM = 2
DEVICENUM = 8
FILENAMELEN = 9

; Codes for the data stream loop. NOTE: in a former version these codes were used for matching
; specific tokens in the game data. Now they aren't really used as symbols as they've been replaced
; with more efficient (I think) jump tables. But these are the codes' names at this point, so I'm
; leaving the definitions here.
BR = 101      ; pieces: Black Rook, Black kNight, etc.
BN = 102
BB = 103
BQ = 104
BK = 105
BP = 106
WR = 107      ; pieces: White Rook, White kNight, etc.
WN = 108
WB = 109
WQ = 110
WK = 111
WP = 112
BS = 113      ; blank space
ZZ = 114      ; pause
DP = 115      ; draw a piece at a square
DN = 116      ; draw N pieces at N squares
CB = 117      ; clear the board
PG = 118      ; PGN string record (e.g. "e4", "e5"...)
EV = 119      ; "Event" record
DT = 120      ; "Date" record
WX = 121      ; "White player" record
BX = 122      ; "Black player" record
MX = 123      ; First move number
PX = 124      ; First player (0=White, 1=Black)
EOG = 125     ; Draw an end of game PGN: 0-1, 1-0, *, etc.
NG = 126      ; New game
EOF = 127     ; End of file
EOR = 254     ; End of record

TOPOFTEXT = $8000 + (8 * 40) + 23      ; top of text area for the PGN notation of the moves:
                                       ;   8 lines down, 24 columns over
MOVELINE = $83D8                       ; bottom line of the moves area
WHITEMOVELOC = $83DB                   ; pointer to where white moves are printed
BLACKMOVELOC = $83E2                   ; pointer to where black moves are printed
EVENTLOC = $8018                       ; pointer to the location to print the Event text
WHITELOC = $8068                       ; pointer to the location to print the White player text
VSLOC = $8097                          ; pointer to the location to print the "VS"
BLACKLOC = $80B8                       ; pointer to the location to print the Black player text
DATELOC = $8108                        ; pointer to the location to print the Date text
TITLELOC = $83C0                       ; pointer to the location to print the Title text

CHESSGAMESDATA = $0D00                 ; pointer to the location of the chess games data

; some macros for dealing with pointers
              MAC DEFINE_PTR         ;  {addr, ptr}
                  pha
                  lda #<{1}
                  sta {2}
                  lda #>{1}
                  sta {2}+1
                  pla
              ENDM

              MAC COPY_PTR           ; {srcptr, dstptr}
                  pha
                  lda {1}
                  sta {2}
                  lda {1}+1
                  sta {2}+1
                  pla
              ENDM

              MAC ADVANCE_PTR
                  inc {1}
                  bne .maclabel
                  inc {1}+1
.maclabel
              ENDM

              MAC ADVANCE_PTR_BY_N   ;  {ptr, n}
                  pha
                  clc
                  lda {1}
                  adc #{2}
                  sta {1}
                  lda {1}+1
                  adc #0
                  sta {1}+1
                  pla
              ENDM

              MAC RETREAT_PTR_BY_N   ;  {ptr, n}
                  pha
                  sec
                  lda {1}
                  sbc #{2}
                  sta {1}
                  lda {1}+1
                  sbc #0
                  sta {1}+1
                  pla
              ENDM

              MAC ADVANCE_PTR_BY_Y   ;  {ptr}
                  pha
                  sty SCRATCH2
                  clc
                  lda {1}
                  adc SCRATCH2
                  sta {1}
                  lda {1}+1
                  adc #0
                  sta {1}+1
                  pla
              ENDM
;
; Recipe to setup the code with one basic line:
;
; 10 SYS 1040
;
; These three lines put that basic one-liner into the start of basic memory
; (on the PET that's at $0400).  Memory location 1040 (decimal) is $0410 (hex).
;
              org $0401
;                  0400   01   02   03   04   05   06   07
;                        [040E is addr of next basic line, which is end of program]
;                               |  [ 10 is line number - 0010 ]
;                               |         |  [ SYS ]
;                               |         |    |  [ space ]
;                               |         |    |    |  [ "1" ]
;                               |         |    |    |    |
              .byte      $0E, $04, $0A, $00, $9E, $20, $31

;                  0408   09   0a   0b   0c   0d   0e   0f
;                   [ "0" ]
;                     |  [ "4" ]
;                     |    |  [ "0" ]
;                     |    |    |  [ end of basic statement "00" ]
;                     |    |    |    |      [ end of basic program "00 00"]
;                     |    |    |    |                   |
              .byte $30, $34, $30, $00, $00, $00, $00, $00

; --------------------------------------------------------------------------------------------------

; This label can be used after assembly to get the actual location of the end of our BASIC program
; stub above
STARTOFCODE:

              org $0410
              cld                 ; unset "decimal" mode for additions


              ; open the datafile
STARTOVER:    jsr OPENFILE

              ; read data from the file representing one complete game
NEXTGAME:     jsr READCHGAME

              ; reset the pointer to the beginning of the game data
              DEFINE_PTR CHESSGAMESDATA, CHMOVEPTR

              jsr BLANKSCREEN
              jsr BLANKBOARD
              jsr PRINTTITLE
              jsr SETDEFAULTS
              jsr RESETBOARD

              ;
              ; start of the main loop - read data and draw
              ;

TOPOFLOOP:    ldy #0
              lda (CHMOVEPTR),y   ; get byte from the data block

CONTINUE:     ; advance to next byte - usually data for whatever token this is
              ADVANCE_PTR CHMOVEPTR

              ;
              ; check against different record types
              ;

              sec
              sbc #114            ; subtract 114 from the code and get an offset into a jump table
              bcs DOJUMP

              adc #114            ; oops, we underflowed, this is a piece draw code - add the 114
              jsr DRAWCHESSMOVE   ; back and run that routine
              jmp TOPOFLOOP

              ;
              ; My plan for this section was to implement a jump table like I've read about in
              ; tutorials and books, but apparently the Indexed Indirect addressing mode (e.g.
              ; "(ADDR,X)") is only valid within the zero page on 6502s. I'm still a little unclear
              ; on what portions of zero page are available to the programmer for such things on a
              ; Commodore PET, so I decided to attempt this self-modifying-code construct. I found
              ; a reference to something similar somewhere on the net. I don't know how common this
              ; technique is - maybe it's not overly innovative and commonly used, but it was new to
              ; me. Anyway...
              ;
              ; The JMPCMD location has a jsr instruction and then a 2-byte address that I'll
              ; overwrite with the address of the proper subroutine to call. Seems to be work. It
              ; seems more elegant than a big series of tests and jumps like
              ;             cmp #TOKEN1
              ;             bne CKTOKEN2
              ;             ... DO SOMETHING...
              ;
              ; CKTOKEN2:   cmp #TOKEN2
              ;             bne CKTOKEN3
              ;             ... DO SOMETHING ELSE...
              ;
              ; and so on.
              ;

DOJUMP:       asl                 ; addresses are 16-bit, double the offset into the table
              tay
              lda JUMPTABLE,y     ; low byte of the address
              sta JMPCMD+1        ; +1 to skip over the jsr instruction itself
              iny
              lda JUMPTABLE,y     ; high byte of the address
              sta JMPCMD+2

JMPCMD:       jsr 1000            ; this address gets overwritten by the above code, simulating a jump table
              jmp TOPOFLOOP

              ; these are all the addresses of the routines to call based on the tokens
JUMPTABLE:    .word THREESECS       ; ZZ
              .word DRAWONEPIECE    ; DP
              .word DRAWNPIECES     ; DN
              .word BLANKBOARD      ; CB
              .word PRINTPGN        ; PG
              .word PRINTEVENT      ; EV
              .word PRINTDATE       ; DT
              .word PRINTWHITEP     ; WX
              .word PRINTBLACKP     ; BX
              .word STOREFIRSTMV    ; MX
              .word STOREFIRSTP     ; PX
              .word PRINTEOG        ; EOG
              .word HANDLENG        ; NG
              .word HANDLEEOF       ; EOF

; --------------------------------------------------------------------------------------------------

HANDLENG:     ; pull the address from the JSR off the stack because we want to jump out
              pla
              pla
              jmp NEXTGAME

; --------------------------------------------------------------------------------------------------

HANDLEEOF:    ; EOF means we need to close the file and then reopen to restart the data
              jsr CLOSEFILE

              ; like above, pull the address from the JSR off the stack because we want to jump out
              pla
              pla
              jmp STARTOVER


; --------------------------------------------------------------------------------------------------

OPENFILE:     lda #FILENUM
              sta FILENUMLOC

              lda #SECONDARYADDRNUM
              sta SECONDARYADDRNUMLOC

              lda #DEVICENUM
              sta DEVICENUMLOC

              lda #FILENAMELEN
              sta FILENAMELENLOC

              DEFINE_PTR FILEN, FILENAMEPTR

              jsr KERNALOPENFILE

              ldx #FILENUM
              jsr KERNALSETINPUT

              rts

FILEN:        .byte 'C, 'H, 'E, 'S, 'S, 'D, 'A, 'T, 'A

; --------------------------------------------------------------------------------------------------

CLOSEFILE:    lda #2
              jsr KERNALCLOSE
              rts

; --------------------------------------------------------------------------------------------------

READCHGAME:   DEFINE_PTR CHESSGAMESDATA, CHMOVEPTR
READCHAR:     jsr KERNALREADCHAR

              ; stick byte from the data block
              ldy #0
              sta (CHMOVEPTR),y
              ADVANCE_PTR CHMOVEPTR

              ; either new game or EOF means stop the read
              cmp #NG
              beq READRETURN
              cmp #EOF
              beq READRETURN

              jmp READCHAR
READRETURN:   rts

; --------------------------------------------------------------------------------------------------
;
;  This series of print routines is mainly just setting pointers and then calling the generic
;  print routine
;

; --------------------------------------------------------------------------------------------------
PRINTEOG:     jsr SCROLLMOVES
              DEFINE_PTR MOVELINE, SCREENPTR
              jsr PRINTSTRREC
              rts

; --------------------------------------------------------------------------------------------------
PRINTEVENT:   DEFINE_PTR EVENTLOC, SCREENPTR
              jsr PRINTSTRREC
              rts

; --------------------------------------------------------------------------------------------------
PRINTDATE:    DEFINE_PTR DATELOC, SCREENPTR
              jsr PRINTSTRREC
              rts

; --------------------------------------------------------------------------------------------------
PRINTWHITEP:  DEFINE_PTR WHITELOC, SCREENPTR
              jsr PRINTSTRREC

              ; print the "VS" also
              DEFINE_PTR VSTEXT, SOURCEPTR
              DEFINE_PTR VSLOC, SCREENPTR
              jsr PRINTSTR
              rts

VSTEXT:       .byte $16, $13, EOR

; --------------------------------------------------------------------------------------------------
PRINTBLACKP:  DEFINE_PTR BLACKLOC, SCREENPTR
              jsr PRINTSTRREC
              rts

; --------------------------------------------------------------------------------------------------
;
;  Store the numerical value of first move - for FEN setups that don't start on move 1
;
STOREFIRSTMV: ldy #0
              lda (CHMOVEPTR),y
              sta MOVENUM
              ADVANCE_PTR CHMOVEPTR
              rts

; --------------------------------------------------------------------------------------------------
;
;  Store WHITE or BLACK as first player
;
STOREFIRSTP:  ldy #0
              lda (CHMOVEPTR),y
              sta MOVECOLOR
              ADVANCE_PTR CHMOVEPTR
              rts

; --------------------------------------------------------------------------------------------------
;
;  Main piece move routine - flashes the piece at source and destination
;
DRAWCHESSMOVE:
              ; read in the three pieces of data
              ; (A already has the srcsquare number from the main loop)

              sta SRCSQUARE

              ldy #0
              lda (CHMOVEPTR),y
              sta DSTSQUARE
              ADVANCE_PTR CHMOVEPTR

              lda (CHMOVEPTR),y
              sta PIECE
              pha                            ; save the piece on the stack for later
              ADVANCE_PTR CHMOVEPTR

              ; flash the source square
              lda SRCSQUARE
              sta SQNUMBER
              jsr DEFSQUAREPTR
              jsr DEFFLASHPTR
              jsr FLASHPIECE

              ; blank the source square
              ldx #BS
              stx PIECE
              jsr BLACKORWHITESQ
              jsr DEFPIECEPTR
              ; SQUAREPTR is still set to the source square
              jsr DRAWATSQUARE

              ; flash the destination square
              lda DSTSQUARE
              sta SQNUMBER
              pla                            ; get the piece back from the stack
              sta PIECE
              jsr DEFSQUAREPTR
              jsr DEFFLASHPTR
              jsr FLASHPIECE

              ; draw the piece
              jsr BLACKORWHITESQ
              jsr DEFPIECEPTR
              ; SQUAREPTR is still set the the source square
              jsr DRAWATSQUARE
              rts

; --------------------------------------------------------------------------------------------------
;
;  Draws N pieces as defined by bytes in the input stream, CHMOVEPTR is advanced past them
;
DRAWNPIECES:
PIECESLOOP:   jsr DRAWONEPIECE
              ldy #0
              lda (CHMOVEPTR),y
              cmp #EOR
              bne PIECESLOOP

              ; advance past the end of record token before returning to main loop
              ADVANCE_PTR CHMOVEPTR
              rts

; --------------------------------------------------------------------------------------------------
;
;  Draws a piece as defined by bytes in the input stream, CHMOVEPTR is advanced past it
;
DRAWONEPIECE:
              ; get both bytes from the stream
              ldy #0
              lda (CHMOVEPTR),y
              sta SQNUMBER
              ADVANCE_PTR CHMOVEPTR

              lda (CHMOVEPTR),y
              sta PIECE
              ADVANCE_PTR CHMOVEPTR

              jsr DRAWONEPIECE1
              rts

; --------------------------------------------------------------------------------------------------
;
;  Once SQNUMBER and PIECE are populated, this routine will draw the piece on the screen
;
DRAWONEPIECE1:
              jsr DEFSQUAREPTR
              jsr BLACKORWHITESQ
              jsr DEFPIECEPTR
              jsr DRAWATSQUARE
              rts

; --------------------------------------------------------------------------------------------------
;
;  Multiply what's in the accumulator by 18
;
MULT18:
              ; 18x = 16x + 2x
              asl                ; 2A
              pha                ; 2A on the stack
              asl                ; 4A
              asl                ; 8A
              asl                ; 16A
              sta SCRATCH        ; SCRATCH = 16A
              pla                ; 2A
              clc
              adc SCRATCH        ; 16A + 2A
              rts

; --------------------------------------------------------------------------------------------------
;
;  PRE: PIECE is defined, SQCOLOR is defined
;
;  OUT: PIECEPTR is pointing to the data block containing the piece draw data
;
DEFPIECEPTR:
              lda PIECE

              sec
              sbc #101            ; subtract 101 from the piece code and get piece number for the
                                  ; table of piece definitions
              jsr MULT18          ; multiply by 18 - the width of the pairs of records

              ldx SQCOLOR         ;   0 = BLACK
              cpx #1              ;   1 = WHITE
              beq WHPIECE
              clc
              adc #9              ; black square, advance the offset by 9

WHPIECE:      DEFINE_PTR PIECESDATA, PIECEPTR
              tay                 ; Y = offset from the start of the block of pieces codes
              ADVANCE_PTR_BY_Y PIECEPTR
              rts

; --------------------------------------------------------------------------------------------------
;
;  PRE: PIECE is defined
;
;  OUT: PIECEPTR is pointing to the first of the two flash piece data blocks
;
DEFFLASHPTR:
              lda PIECE
              sec
              sbc #101            ; subtract 101 from the piece code and get piece number for the
                                  ; table of piece definitions
              sec
              sbc #6              ; subtract 6 to shift from white pieces to black in the code table
                                  ; for the piece codes (we don't have both black and white flashing blocks)
              bcs NOUNDERFLOW     ; if we didn't underflow, we're good, otherwise add that 6 back
              adc #6

NOUNDERFLOW:  jsr MULT18          ; multiply by 18 - the width of the pairs of records

              DEFINE_PTR FLASHDATA, PIECEPTR
              tay                 ; Y = offset from the start of the block of pieces codes
              ADVANCE_PTR_BY_Y PIECEPTR
              rts

; --------------------------------------------------------------------------------------------------
;
;  With SQNUMBER set, define SQUAREPTR so that it points to the proper loc in screen memory
;
DEFSQUAREPTR: ldy SQNUMBER
              ldx SQLOADDR,y
              stx SQUAREPTR
              ldx SQHIADDR,y
              stx SQUAREPTR+1
              rts

; --------------------------------------------------------------------------------------------------
;
;  PRE: PIECEPTR is set to the first data block of flash for the current piece
;       SQUAREPTR is set to the square where we draw
;
FLASHPIECE:   ldx #3
              stx SCRATCH
FLASHLOOP:
              jsr DRAWATSQUARE
              lda #1
              jsr FLASHDELAY

              ADVANCE_PTR_BY_N PIECEPTR, 9

              jsr DRAWATSQUARE
              lda #1
              jsr FLASHDELAY

              RETREAT_PTR_BY_N PIECEPTR, 9

              dec SCRATCH
              bne FLASHLOOP
              rts

; --------------------------------------------------------------------------------------------------
;
;  After PIECEPTR and SQUAREPTR are defined, this routine copies the piece data from
;  PIECEPTR to SQUAREPTR
;
DRAWATSQUARE:
              ldy #0
              lda (PIECEPTR),y
              sta (SQUAREPTR),y
              iny
              lda (PIECEPTR),y
              sta (SQUAREPTR),y
              iny
              lda (PIECEPTR),y
              sta (SQUAREPTR),y

              ldx #3
              stx PIECEOFFS
              ldx #40
              stx SCREENOFFS

              ldy PIECEOFFS
              lda (PIECEPTR),y
              ldy SCREENOFFS
              sta (SQUAREPTR),y

              iny
              sty SCREENOFFS

              ldx PIECEOFFS
              inx
              stx PIECEOFFS

              ldy PIECEOFFS
              lda (PIECEPTR),y
              ldy SCREENOFFS
              sta (SQUAREPTR),y

              iny
              sty SCREENOFFS

              ldx PIECEOFFS
              inx
              stx PIECEOFFS

              ldy PIECEOFFS
              lda (PIECEPTR),y
              ldy SCREENOFFS
              sta (SQUAREPTR),y

              ldx #6
              stx PIECEOFFS
              ldx #80
              stx SCREENOFFS

              ldy PIECEOFFS
              lda (PIECEPTR),y
              ldy SCREENOFFS
              sta (SQUAREPTR),y

              iny
              sty SCREENOFFS

              ldx PIECEOFFS
              inx
              stx PIECEOFFS

              ldy PIECEOFFS
              lda (PIECEPTR),y
              ldy SCREENOFFS
              sta (SQUAREPTR),y

              iny
              sty SCREENOFFS

              ldx PIECEOFFS
              inx
              stx PIECEOFFS

              ldy PIECEOFFS
              lda (PIECEPTR),y
              ldy SCREENOFFS
              sta (SQUAREPTR),y
              rts

; --------------------------------------------------------------------------------------------------
;
;  Draw the initial chess pieces setup
;
RESETBOARD:
              DEFINE_PTR STARTPOS, SOURCEPTR
ANOTHERRESET: ldy #0
              lda (SOURCEPTR),y
              ADVANCE_PTR SOURCEPTR
              cmp #EOR
              beq RESETDONE

              sta SQNUMBER

              lda (SOURCEPTR),y
              ADVANCE_PTR SOURCEPTR
              sta PIECE

              jsr DRAWONEPIECE1
              jmp ANOTHERRESET
RESETDONE:    rts

STARTPOS:     .byte  0, BR,  1, BN,  2, BB,  3, BQ,  4, BK,  5, BB,  6, BN,  7, BR
              .byte  8, BP,  9, BP, 10, BP, 11, BP, 12, BP, 13, BP, 14, BP, 15, BP
              .byte 48, WP, 49, WP, 50, WP, 51, WP, 52, WP, 53, WP, 54, WP, 55, WP
              .byte 56, WR, 57, WN, 58, WB, 59, WQ, 60, WK, 61, WB, 62, WN, 63, WR, EOR

; --------------------------------------------------------------------------------------------------
;
;  Setup default values - right now just who moves first and what the first move number is
;
SETDEFAULTS:  ; these are defaults - the PGN data can override these if necessary
              ; set color to move to white (0)
              ldy #0
              sty MOVECOLOR
              ; set move number to 1
              ldy #1
              sty MOVENUM
              rts

; --------------------------------------------------------------------------------------------------
;
;  Just prints "chess replayer" at the bottom of the board
;
PRINTTITLE:
              DEFINE_PTR TITLETEXT, SOURCEPTR
              DEFINE_PTR TITLELOC, SCREENPTR
              jsr PRINTSTR
              rts

TITLETEXT:    .byte 32, 32, 32, 32, 32, 3, 8, 5, 19, 19, 32, 18, 5, 16, 12, 1, 25, 5, 18, EOR

; --------------------------------------------------------------------------------------------------
;
; Copies data from SOURCEPTR to SCREENPTR until it hits an EOR byte
;
; On return, Y contains the length of the string printed
;
PRINTSTR:     ldy #0
PRINTLOOP:    lda (SOURCEPTR),y     ; get the next letter
              cmp #EOR            ; check for end of record
              beq PRINTRET

              sta (SCREENPTR),y
              iny
              jmp PRINTLOOP
PRINTRET:     rts

; --------------------------------------------------------------------------------------------------
;
;  Prints strings embedded in the input data stream, handles advancing the main CHMOVEPTR
;
PRINTSTRREC:
              COPY_PTR CHMOVEPTR, SOURCEPTR
              jsr PRINTSTR
              ADVANCE_PTR_BY_Y CHMOVEPTR
              ; moving the pointer by Y locations just advances it to the EOR byte
              ADVANCE_PTR CHMOVEPTR
              rts

; --------------------------------------------------------------------------------------------------
;
;  Scroll the area of the screen on the bottom right that shows the text PGN of the moves
;
SCROLLMOVES:
              ; scroll the text area - cols 25-40, bottom 17 rows
              DEFINE_PTR TOPOFTEXT, SOURCEPTR
              DEFINE_PTR TOPOFTEXT, SCREENPTR

              ; add 40 so pointer 2 points at the next line
              ADVANCE_PTR_BY_N SCREENPTR, 40

              ; setup number of lines to scroll
              ldx #16

ANOTHERLINE:  ldy #15
LINELOOP:     lda (SCREENPTR),y
              sta (SOURCEPTR),y
              dey
              bne LINELOOP

              ; add 40 to both pointers to move to the next line
              ADVANCE_PTR_BY_N SOURCEPTR, 40
              ADVANCE_PTR_BY_N SCREENPTR, 40

              dex
              bne ANOTHERLINE

              ; blank the bottom line
              DEFINE_PTR MOVELINE, SCREENPTR

              lda #$20
              ldy #15
LINELOOP2:    sta (SCREENPTR),y
              dey
              bne LINELOOP2
              rts

; --------------------------------------------------------------------------------------------------
;
;  Print PGN text from the input data stream
;     Handles scrolling if necessary
;
PRINTPGN:     ; should we scroll?
              ldy MOVECOLOR
              cpy #1                      ; 1=black move, skip scroll
              beq AFTERSCROLL
              jsr SCROLLMOVES

              ; black or white piece being moved?
AFTERSCROLL:  ldy MOVECOLOR
              cpy #1                      ; 1=black move, skip move number output
              beq SETUPBLMOVE

              ; this is either a white move, or a setup with first move for black

              ; write out the move number
              jsr WRITEMOVENUM
              inc MOVENUM

              ; point screen pointer at white's move area
              DEFINE_PTR WHITEMOVELOC, SCREENPTR

              ldy MOVECOLOR
              cpy #2                      ; 2=black opening move, we need to print a ".." for white
              bne SETUPWHMOVE

              ; write out two dots as a fake white move for this opening black move
              DEFINE_PTR DOTSTEXT, SOURCEPTR
              jsr PRINTSTR

              ; now print black's move
              jmp SETUPBLMOVE

SETUPWHMOVE:  ; black is next move
              ldy #1
              sty MOVECOLOR
              jmp PRINTIT

SETUPBLMOVE:  ; point screen pointer at black's move area
              DEFINE_PTR BLACKMOVELOC, SCREENPTR

              ; flip move color to white for next time
              ldy #0
              sty MOVECOLOR

PRINTIT:      ; the text area has been scrolled, pointers are setup, print the move string
              jsr PRINTSTRREC
              rts

DOTSTEXT:     .byte $2E, $2E, EOR

; --------------------------------------------------------------------------------------------------
;
;  this routine to write a value as a decimal number was adapted from code in _6502 Software Design_
;  by Leo J. Scanlon
;
WRITEMOVENUM: DEFINE_PTR MOVELINE, SCREENPTR

              lda MOVENUM
              ldx #$FF
              sec

HUNDREDS:     inx
              sbc #100
              bcs HUNDREDS

              adc #100
              ; X has the hundreds digit - we'll just consume it and move on
              ; jsr PRINTDEC

              ldx #$FF
              sec

TENS:         inx
              sbc #10
              bcs TENS

              adc #10
              ; X has the tens digit
              cpx #0
              bne PRINT1

              ; for the tens digit only, if it is a zero, make it a space, (so make it -16 here so
              ; adding 48 will wrap to 32, the code for a space)
              ldx #$F0

PRINT1:       jsr PRINTDEC

              tax
              ; X has the ones digit
              jsr PRINTDEC

              ; print the "." after the number
              lda #$2E
              ldy #0
              sta (SCREENPTR),y
              rts

; --------------------------------------------------------------------------------------------------
;
;  PRE: X contains a single decimal digit that should be printed out to the screen at SCREENPTR
;           Advances SCREENPTR
;
PRINTDEC:     pha
              txa

              clc
              adc #48

              ldy #0
              sta (SCREENPTR),y

              ADVANCE_PTR SCREENPTR

              pla
              rts

; --------------------------------------------------------------------------------------------------
;
;  Determine if the square we're about to draw on is white or black
;
;  Stores 0 or 1 into SQCOLOR
;   0 = BLACK
;   1 = WHITE
;
BLACKORWHITESQ:
              ldx SQNUMBER
              stx SCRATCH
              ldy #0
FINDSQUARE:   lda WHSQUARES,y
              cmp #EOR
              beq ITSBLACK

              cmp SCRATCH
              beq ITSWHITE
              iny
              jmp FINDSQUARE

ITSWHITE:     ldx #1
              stx SQCOLOR
              rts
ITSBLACK:     ldx #0
              stx SQCOLOR
              rts

WHSQUARES:    .byte  0,  2,  4,  6,  9, 11, 13, 15, 16, 18, 20, 22, 25, 27, 29, 31
              .byte 32, 34, 36, 38, 41, 43, 45, 47, 48, 50, 52, 54, 57, 59, 61, 63, EOR

; --------------------------------------------------------------------------------------------------
;
;  Blank the screen - actually writes 23 bytes beyond the end of the screen data area
;
BLANKSCREEN:  ldy #0
SCRLOOP:      lda #$20
              sta $8000,y
              sta $8100,y
              sta $8200,y
              sta $8300,y
              iny
              bne SCRLOOP
              rts

; --------------------------------------------------------------------------------------------------
;
;  Draw the blank chessboard, only writes to the portion of the screen containing the chessboard
;
BLANKBOARD:   ldy #0
BSCRLOOP:     lda BLANKB1,y
              sta $8000,y
              sta $8028,y
              sta $8050,y

              sta $80F0,y
              sta $8118,y
              sta $8140,y

              sta $81E0,y
              sta $8208,y
              sta $8230,y

              sta $82D0,y
              sta $82F8,y
              sta $8320,y

              lda BLANKB2,y
              sta $8078,y
              sta $80A0,y
              sta $80C8,y

              sta $8168,y
              sta $8190,y
              sta $81B8,y

              sta $8258,y
              sta $8280,y
              sta $82A8,y

              sta $8348,y
              sta $8370,y
              sta $8398,y

              iny
              cpy #24
              bne BSCRLOOP
              rts

; --------------------------------------------------------------------------------------------------
;
;  Delay routine - it can be called in two ways, via THREESECS or FLASHDELAY. Basically the main
;  loop delays enough for the flashing, and the outer loop calls that inner loop 30 times. It is
;  only approximately 3 seconds (a bit shorter actually). This routine was adapted from code
;  in _6502 Software Design_ by Leo J. Scanlon
;
THREESECS:    lda #30
FLASHDELAY:   ldx #$14
              ldy #$75
WAIT:         dex
              bne WAIT
              dey
              bne WAIT
              sec
              sbc #1
              bne FLASHDELAY
              rts

; --------------------------------------------------------------------------------------------------

; variables
PIECEOFFS:    .byte $00
SCREENOFFS:   .byte $00
SCRATCH:      .byte $00
SCRATCH2:     .byte $00
MOVENUM:      .byte $00
MOVECOLOR:    .byte $00
SRCSQUARE:    .byte $00
DSTSQUARE:    .byte $00
PIECE:        .byte $00
SQNUMBER:     .byte $00
SQCOLOR:      .byte $00

; --------------------------------------------------------------------------------------------------
;                    a    b    c    d    e    f    g    h
; these are the actual screen addresses of each square of the chess board
;                    a    b    c    d    e    f    g    h
SQHIADDR:     .byte $80, $80, $80, $80, $80, $80, $80, $80   ; 8
              .byte $80, $80, $80, $80, $80, $80, $80, $80   ; 7
              .byte $80, $80, $80, $80, $80, $80, $81, $81   ; 6
              .byte $81, $81, $81, $81, $81, $81, $81, $81   ; 5
              .byte $81, $81, $81, $81, $81, $81, $81, $81   ; 4
              .byte $82, $82, $82, $82, $82, $82, $82, $82   ; 3
              .byte $82, $82, $82, $82, $82, $82, $82, $82   ; 2
              .byte $83, $83, $83, $83, $83, $83, $83, $83   ; 1

;                    a    b    c    d    e    f    g    h
SQLOADDR:     .byte $00, $03, $06, $09, $0C, $0F, $12, $15   ; 8
              .byte $78, $7B, $7E, $81, $84, $87, $8A, $8D   ; 7
              .byte $F0, $F3, $F6, $F9, $FC, $FF, $02, $05   ; 6
              .byte $68, $6B, $6E, $71, $74, $77, $7A, $7D   ; 5
              .byte $E0, $E3, $E6, $E9, $EC, $EF, $F2, $F5   ; 4
              .byte $58, $5B, $5E, $61, $64, $67, $6A, $6D   ; 3
              .byte $D0, $D3, $D6, $D9, $DC, $DF, $E2, $E5   ; 2
              .byte $48, $4B, $4E, $51, $54, $57, $5A, $5D   ; 1

; these each represent one line across the screen of a an empty board - one starts with white
; square, one with black
;                    1   2   3   4   5   6   7   8   9  10  11  12
BLANKB1:      .byte WH, WH, WH, BL, BL, BL, WH, WH, WH, BL, BL, BL
              .byte WH, WH, WH, BL, BL, BL, WH, WH, WH, BL, BL, BL

BLANKB2:      .byte BL, BL, BL, WH, WH, WH, BL, BL, BL, WH, WH, WH
              .byte BL, BL, BL, WH, WH, WH, BL, BL, BL, WH, WH, WH

; --------------------------------------------------------------------------------------------------
;
; black pieces (on white square, then on black)
;
; Each piece CAN be addressed via a name, but the current algorithm doesn't use the names but rather
; calculates offsets into this table.
;
PIECESDATA:
BRONW:        .byte $EA, $22, $F4, $EA, $64, $F4, $FC, $62, $FE
BRONB:        .byte $59, $22, $54, $59, $64, $54, $6D, $40, $7D
BNONW:        .byte $D5, $D5, $C9, $A0, $4E, $A9, $FC, $62, $FE
BNONB:        .byte $55, $55, $49, $67, $4E, $29, $6D, $40, $7D
BBONW:        .Byte $A0, $69, $E5, $A0, $64, $E5, $FC, $62, $FE
BBONB:        .byte $20, $4E, $65, $67, $64, $65, $6D, $40, $7D
BQONW:        .byte $D5, $56, $C9, $DF, $64, $E9, $FC, $62, $FE
BQONB:        .byte $55, $D6, $49, $4D, $64, $4E, $6D, $40, $7D
BKONW:        .byte $A0, $DB, $A0, $A8, $D1, $A9, $FC, $62, $FE
BKONB:        .byte $20, $5B, $20, $28, $57, $29, $6D, $40, $7D
BPONW:        .byte $A0, $AE, $A0, $A0, $64, $A0, $FC, $62, $FE
BPONB:        .byte $20, $2E, $20, $67, $64, $65, $6D, $40, $7D

; white pieces (on white square, then on black)
WRONW:        .byte $D9, $A2, $D4, $D9, $E4, $D4, $ED, $C0, $FD
WRONB:        .byte $6A, $A2, $74, $6A, $E4, $74, $7C, $E2, $7E
WNONW:        .byte $D5, $D5, $C9, $E7, $AF, $A9, $ED, $C0, $FD
WNONB:        .byte $55, $55, $49, $20, $AF, $29, $7C, $E2, $7E
WBONW:        .byte $A0, $AF, $E5, $E7, $E4, $E5, $ED, $C0, $FD
WBONB:        .byte $20, $E9, $65, $20, $E4, $65, $7C, $E2, $7E
WQONW:        .byte $D5, $56, $C9, $CD, $E4, $CE, $ED, $C0, $FD
WQONB:        .byte $55, $D6, $49, $5F, $E4, $69, $7C, $E2, $7E
WKONW:        .byte $A0, $DB, $A0, $A8, $D7, $A9, $ED, $C0, $FD
WKONB:        .byte $20, $5B, $20, $28, $51, $29, $7C, $E2, $7E
WPONW:        .byte $A0, $AE, $A0, $E7, $E4, $E5, $ED, $C0, $FD
WPONB:        .byte $20, $2E, $20, $20, $E4, $20, $7C, $E2, $7E

; a single black and white square, for use in drawing routines
WHITESQ:      .byte WH, WH, WH, WH, WH, WH, WH, WH, WH
BLACKSQ:      .byte BL, BL, BL, BL, BL, BL, BL, BL, BL

; --------------------------------------------------------------------------------------------------
;
; flashing version of pieces
;
; Like the pieces data block above, these chunks CAN be address via names but aren't currently in
; the algorithm
;
FLASHDATA:
FLASHR1:      .byte $6A, $A2, $74, $6A, $E4, $74, $7C, $E2, $7E ; (black background)
FLASHR2:      .byte $EA, $22, $F4, $EA, $64, $F4, $FC, $62, $FE ; (white background)
FLASHN1:      .byte $55, $55, $49, $20, $AF, $29, $7C, $E2, $7E
FLASHN2:      .byte $D5, $D5, $C9, $A0, $4E, $A9, $FC, $62, $FE
FLASHB1:      .byte $20, $E9, $65, $20, $E4, $65, $7C, $E2, $7E
FLASHB2:      .byte $A0, $69, $E5, $A0, $64, $E5, $FC, $62, $FE
FLASHQ1:      .byte $55, $D6, $49, $5F, $E4, $69, $7C, $E2, $7E
FLASHQ2:      .byte $D5, $56, $C9, $DF, $64, $E9, $FC, $62, $FE
FLASHK1:      .byte $20, $5B, $20, $28, $51, $29, $7C, $E2, $7E
FLASHK2:      .byte $A0, $DB, $A0, $A8, $D1, $A9, $FC, $62, $FE
FLASHP1:      .byte $20, $2E, $20, $20, $E4, $20, $7C, $E2, $7E
FLASHP2:      .byte $A0, $AE, $A0, $A0, $64, $A0, $FC, $62, $FE

; After assembly, the address of ENDOFCODE can allow for a sanity check as to how far into BASIC
; memory space we've grown

ENDOFCODE:
