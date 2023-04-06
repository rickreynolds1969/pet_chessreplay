CHESSREPLAYER V2.0 FOR COMMODORE PET

Watch your PET play historical chess games!  A chess-related demo program for
your PET!


NOTE

As distributed, the Chess Replayer should run on any sized PET that has BASIC
4.0 ROMs.  The program is just under 2K in size, and it reads chess game data
one game at a time from the disk.  In my experience, even long chess games tend
to be under 1K in length after being encoded by the pgn_to_pet.py tool.

It requires a disk drive connected as device 8 as it requires an external data
file containing the chess data.  Unfortunately, device 8 is hard-coded into the
program.


BACKGROUND

I have had a weird love affair with the Commodore PET over the years.  A couple
of years ago, I finally managed to get hold of one and restored it to working
condition.  I applied a couple of upgrades to it to allow easier loading of
software pulled from the internet and updated it to a full 32KB of memory.  But
then it mostly sits there in my office doing nothing.

I looked around for some interesting demos that might be able to run to give it
something interesting to do.  Most demos that I found seemed to be about showing
off interesting screen draw or sound techniques.  I just wanted something that
could run for many hours showing interesting screens.  Like the Christmas Demos
on the C64.

I have also had a smoldering desire to learn to code in assembly on 8-bit
Commodore machines.  When I had my C64 it seemed like the people who could write
in assembly could do magical things with the machine, while my BASIC programs
seemed lackluster.  Clearly assembly programming was where the power was.

Today I earn a living programming infrastructure for a high-tech company, mainly
in Python, Groovy, Terraform, and bash.  But the allure of assembly programming
was still in the back of my mind.

I also really like the game of chess...


THE CHESSREPLAYER

There are at least a couple of chess programs available for the PET.  But I
never found one that would play itself - as an adhoc chess demo of sorts.  So I
thought about a program that wouldn't actually play chess against a player, but
would instead replay chess games on the screen.  There are LOTS of historical
chess games available for download on the internet in PGN format.  These games
can be loaded into a chess engine and analyzed.  The Chess Replayer will take
PGN data and re-play the chess games contained within.

The .d64 image contains the Chess Replayer program and a data file containing
the 21 chess games (well, actually 20) between Boris Spassky and Bobby Fischer
played in the 1972 Chess Championships.  If you load and run the Chess Replayer,
that is what you will see.

I have also included the pgn_to_pet.py program that will allow you to encode PGN
files of your own choosing for use with the Chess Replayer.  It is written in
Python 3, sorry if you're still using Python 2.  The code isn't overly complex,
so a Python 2 user can probably get it to run with minimal changes.

To encode your own PGN file(s) into binary form that can be read by the Chess
Replayer, simply run the pgn_to_pet.py utility:

python3 pgn_to_pet.py <pgn file> [<pgn file2> <pgn file3> ...]

An output file named "chessdata" will be created in the current directory.

To facilitate users creating their own chessdata files and using them, I've
included the chessreplay.prg file outside of the .d64 image as well.  It is
identical to the one inside the chessreplay.d64 file.


THE SCREEN

The Chess Replayer draws the chess board and moves the pieces using the bulk of
the display.  To the right of the board it will display the event at which the
game was played, the person playing both White and Black pieces, and the date
the game was played, if available.  The person playing White is given first and
the person playing black is second on the screen.  That's how chess notation
works (white first), but it can seem a little disorienting because the white
pieces are at the bottom of the screen.

Below the text is a running list of the moves being played on the board in
algebraic chess notation.


REPLAYING GAMES

The Chess Replayer will play through all the games represented in its data file,
pausing at the end of each game before moving on.  Once it hits the end of all
the game data in the data file, it will restart at the beginning again.


CAVEATS

I've written and tested these programs on a Mac and a Linux machine.  I've run
the Chess Replayer in VICE on both platforms as well as on my hardware PET 2001.
I've not tried it on any other platform.

The pgn_to_pet.py file uses a parser of my own design to read PGN files.  This
was done because I didn't want folks who many not be overly familiar with python
programming to need to pull down external packages.  I've put several PGN data
files through my parser, but there may be latent bugs somewhere.  If you attempt
to encode a PGN file and hit any errors, feel free to contact me with the
offending PGN file and I'll see if I can debug the issue.

The pgn_to_pet.py program processes any and all PGN data it is given.  It us up
to the user to determine whether or not a chessdata file is too large to load
onto a disk.


CREDITS

The design of the chess pieces in PETSCII characters came from the CHESSCII demo
program for the C64 by Dr. Terror Z and Marq, uploaded to csdb.dk in February of
2018 (link: https://csdb.dk/release/?id=162204).  I assumed I could use the
design based on a comment in the upload: "A chess board in pure PETSCII. We
started wondering whether one would be possible and gave it a go. 3x3 character
pieces on both black and white squares isn't an easy format - try if you can do
it any better :)"  If either Dr. Terror Z or Marq feel that I'm appropriating
their work improperly, I hope they will contact me and I guess I'll redo the
design of the chess pieces somehow.

I've also included a couple of credits for some code recipes and/or inspiration
in the comments of the assembly code.

Drawing the chess pieces and getting the proper PETSCII code values was helped
immensely by David Murray's PetDraw program (link:
https://www.the8bitguy.com/download-davids-software/).


CONTACT ME

My name is Rick Reynolds.  If you have compliments, questions, or criticisms
regarding this project, you can contact me over on AtariAge (I'm user Rick
Reynolds there) or via email at rick@rickandviv.net.


VERSIONS

Version 2.0, 2023-04-01

* Reads one game at a time from the disk rather than pulling all the data in
  up front.
* Some mild refactoring and cleanup of the code from version 1.

Version 1.0, 2023-03-24

* Initial release, was limited in that it had to read all the chess data at
  once.
