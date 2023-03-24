#!/usr/bin/env python3

import argparse
import struct


# NOTE: this address needs to match the address for CHESSGAMESDATA in the assembly code. It also must be higher in
# memory than the end of the program data post-assembly. The label ENDOFCODE can be checked in DASM's output to find
# the upper end of the memory used by the program.

# set the starting addr as 0C00
CHESS_DATA_STARTING_ADDRESS_MSB = 0x0C
CHESS_DATA_STARTING_ADDRESS_LSB = 0x00


class PgnToPet:
    def __init__(self, filenames):
        games = []
        self.output_stream = []
        self.output_bytes = []
        self.board_piece_to_byte_stream = {' ': 'BS', 'P': 'WP', 'R': 'WR', 'N': 'WN', 'B': 'WB', 'Q': 'WQ', 'K': 'WK',
                                           'p': 'BP', 'r': 'BR', 'n': 'BN', 'b': 'BB', 'q': 'BQ', 'k': 'BK'}
        self.stream_code = {'BR': 101, 'BN': 102, 'BB': 103, 'BQ': 104, 'BK': 105, 'BP': 106, 'WR': 107, 'WN': 108,
                            'WB': 109, 'WQ': 110, 'WK': 111, 'WP': 112, 'BS': 113, 'ZZ': 114, 'DP': 115, 'DN': 116,
                            'CB': 117, 'PG': 118, 'EV': 119, 'DT': 120, 'WX': 121, 'BX': 122, 'MX': 123, 'PX': 124,
                            'NG': 125, 'EOG': 126, 'EOR': 254, 'EOF': 255}
        self.default_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"

        for filename in filenames:
            with open(filename, 'r') as fh:
                self.lines = fh.readlines()

            self.file_index = 0

            while self.file_index < len(self.lines):
                # get any metadata tags
                meta = self.parse_pgn_file_for_metadata()

                # pull any defined FEN element and populate the initial board
                fen = meta.get('FEN', None)
                board = self.populate_board(fen)
                fen_moves = self.board_to_draw_commands(board)

                # get the first pass through the moves text, return a set of tokens
                tokens = self.parse_pgn_file_for_moves_tokens()

                # convert the tokens to a set of moves structs
                moves = self.create_pgn_moves_struct(tokens)

                # add the board movements
                moves = self.add_board_movements(moves, board)

                # save this game info
                games.append({'moves': moves, 'meta': meta, 'fenmoves': fen_moves})

        for game in games:
            # ordering matters here in terms of what gets drawn when
            meta = game['meta']
            fen = game['fenmoves']
            moves = game['moves']
            self.generate_metadata_outputs(meta)
            self.generate_fen_draw_outputs(fen)
            self.generate_first_move_data(moves)
            self.generate_pause()
            self.generate_moves_data(moves)
            self.generate_pause(num=4)
            self.generate_eog()
        self.generate_eof()
        return

    def parse_pgn_file_for_metadata(self):
        metadata = {}

        # consume all blank lines we encounter at the top of the current section
        while len(self.lines[self.file_index].strip()) == 0:
            self.file_index += 1

        while self.file_index < len(self.lines):
            line = self.lines[self.file_index]
            self.file_index += 1
            line = line.strip()

            # end of the metadata section - a blank line
            if len(line) == 0:
                break

            # only going to parse files with one element per line in this section
            if (line.startswith('[') and line.endswith(']')) is False:
                continue
            line = line[1:-1]

            for i in range(0, len(line)):
                if line[i] == ' ':
                    tag = line[0:i]
                    value = line[i + 1:]
                    value = value.replace('"', '')

                    # missing values show up as "?", dates have periods
                    if all(x in ('?', '.') for x in value) is False:
                        metadata[tag] = value
                    break
        return metadata

    def parse_pgn_file_for_moves_tokens(self):
        ignore_stack = []
        token = ''
        partial_token = ''
        tokens = []

        # consume all blank lines we encounter at the top
        while len(self.lines[self.file_index].strip()) == 0:
            self.file_index += 1

        while self.file_index < len(self.lines):
            line = self.lines[self.file_index]
            self.file_index += 1

            # end of this moves section - blank line
            if len(line.strip()) == 0 and len(ignore_stack) == 0:
                break

            for ch in line:
                if ch in ('[', '{', '('):
                    ignore_stack.append(ch)
                if ch in (']', '}', ')'):
                    ignore_stack.pop()

                if len(ignore_stack) > 0:
                    continue
                elif ch in (']', '}', ')'):
                    continue

                if ch == ' ' or ch == '\n':
                    token = partial_token
                    partial_token = ''
                else:
                    partial_token += ch
                    continue

                # at some state transitions, we end up with an empty token here, just continue to the next
                if token == '':
                    continue

                # tokens that start with '$' are part of some meta commenting
                if token.startswith('$'):
                    continue

                # find the end result if it is here
                if self.move_is_end_of_game(token):
                    if '½' in token:
                        tokens.append('1/2-1/2')
                    else:
                        tokens.append(token)
                    continue

                # tokens can have a move number on the front of them, if so separate them
                if token[0].isdigit() and '.' in token and token[-1] != '.':
                    # find last '.'
                    for i in reversed(range(0, len(token))):
                        if token[i] == '.':
                            movenum = token[0:i + 1]
                            move = token[i + 1:]
                            break
                    tokens.append(movenum)
                    tokens.append(move)
                else:
                    tokens.append(token)
        return tokens

    def token_starts_with_movenum(self, token):
        seen_num = False
        for ch in token:
            if ch in '0123456789.':
                seen_num = True
            else:
                if seen_num is False:
                    return False
        return True

    def populate_board(self, fen=None):
        if fen is None:
            fen = self.default_fen
        self.fen = fen
        board = []
        for row in range(0, 8):
            board.append(['', '', '', '', '', '', '', ''])
        row = 0
        col = 0
        for ch in fen:
            if ch == '/':
                col = 0
                row += 1
                continue
            if ch in ('r', 'R', 'n', 'N', 'b', 'B', 'q', 'Q', 'k', 'K', 'p', 'P'):
                board[row][col] = ch
            elif ch.isdigit():
                col += int(ch) - 1
            else:
                # anything else would mean we've walked through the FEN string past the board representation
                break
            col += 1
        return board

    def board_to_draw_commands(self, board):
        draws = []
        if self.fen == self.default_fen:
            return draws
        for row in range(0, 8):
            for col in range(0, 8):
                ch = board[row][col]
                if ch != '':
                    draws.append((row, col, ch))
        return draws

    def dump_board(self, board):
        # useful when debugging
        for row in range(0, 8):
            rank = 8 - row
            print(rank, end='')
            for col in range(0, 8):
                if board[row][col] == '':
                    print(" _", end='')
                else:
                    print(f" {board[row][col]}", end='')
            print('')
        print('  A B C D E F G H\n')
        return

    def dump_moves(self, moves):
        # useful when debugging
        for move in moves:
            print(move)
        return

    def move_is_end_of_game(self, move_text):
        if all(x in ('0', '1', '-', '½', '/', '2', '*') for x in move_text):
            return True
        return False

    def strip_annotations_from_text_move(self, move_text):
        mtext = move_text
        # good endings are any rank number, O for castling, or pieces that can be a target of a pawn promotion
        good_ending_chars = ('1', '2', '3', '4', '5', '6', '7', '8', 'Q', 'R', 'N', 'B', 'O')
        while mtext[-1] not in good_ending_chars:
            mtext = mtext[:-1]
        return mtext

    def create_pgn_moves_struct(self, tokens):
        current_player = 'WHITE'
        moves = []
        for token in tokens:
            # detect move number - move numbers can occur more than once if there was a comment between white's and
            # black's move
            if all(x in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.') for x in token):
                movenum = int(token.replace('.', ''))
                if '...' in token:
                    current_player = 'BLACK'
                else:
                    current_player = 'WHITE'
                continue

            # detect end of game token
            if self.move_is_end_of_game(token):
                moves.append({'player': None,
                              'move_text': token,
                              'move_num': None})
                # this really SHOULD be the last token for the game, but we'll loop back up anyway
                continue

            moves.append({'player': current_player,
                          'move_text': token,
                          'move_num': movenum})

            current_player = 'WHITE' if current_player == 'BLACK' else 'BLACK'
        return moves

    def dump_game_pgn(self, moves):
        # useful when debugging
        for move in moves:
            board_move = str(move.get('board_move', ''))
            if move['player'] is None:
                print(f"{move['move_text']}")
                need_cr = False
            if move['player'] == 'WHITE':
                print(f"{move['move_num']}. {move['move_text']} {board_move}", end='')
                need_cr = True
            else:
                print(f"  {move['move_text']} {board_move}")
                need_cr = False

        if need_cr is True:
            print('')
        return

    def convert_algebraic_file_to_col(self, file):
        return ord(file) - 97

    def convert_algebraic_rank_to_row(self, rank):
        return 8 - int(rank)

    def get_pawn_promotion_info(self, move_text):
        dst_piece = move_text[-1]
        trimmed_move = move_text[:-2]
        return (dst_piece, trimmed_move)

    def find_piece_in_row(self, dst_row, piece, board, starting_col=None):
        #
        #  If starting_col is given, that should be used as a place where the search should start.  It also implies that
        #  this is a piece movement path and all cells between the starting location and the piece location should be
        #  empty.
        #
        found_row = None
        found_col = None
        for_piece_move = True

        rownum = dst_row

        if starting_col is None:
            for_piece_move = False
            starting_col = -1

        # check to the right
        colnum = starting_col + 1
        while colnum < 8:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '' and for_piece_move is True:
                    break
            except Exception:
                pass
            colnum += 1

        if found_row is not None:
            return (found_row, found_col)

        # check to the left
        colnum = starting_col - 1
        while colnum >= 0:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '' and for_piece_move is True:
                    break
            except Exception:
                pass
            colnum -= 1
        return (found_row, found_col)

    def find_piece_in_col(self, dst_col, piece, board, starting_row=None):
        found_row = None
        found_col = None
        for_piece_move = True

        colnum = dst_col

        if starting_row is None:
            for_piece_move = False
            starting_row = -1

        # check down
        rownum = starting_row + 1
        while rownum < 8:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '' and for_piece_move is True:
                    break
            except Exception:
                pass
            rownum += 1

        if found_row is not None:
            return (found_row, found_col)

        # check up
        rownum = starting_row - 1
        while rownum >= 0:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '' and for_piece_move is True:
                    break
            except Exception:
                pass
            rownum -= 1
        return (found_row, found_col)

    def find_knight(self, dst_row, dst_col, piece, board):
        found_row = None
        found_col = None

        offsets = [(-2, -1), (-2, 1),
                   (2, -1), (2, 1),
                   (-1, 2), (1, 2),
                   (-1, -2), (1, -2)]

        # work through the various positions, checking for the knight
        for offset in offsets:
            row = dst_row + offset[0]
            col = dst_col + offset[1]
            try:
                if board[row][col] == piece:
                    found_row = row
                    found_col = col
            except Exception:
                # if we check off the board, just move on
                pass
        return (found_row, found_col)

    def find_piece_on_diagonals(self, dst_row, dst_col, piece, board):
        #
        #  This is assumed to be called in the context of finding a piece diagonally from a location on the board.
        #  All squares between the location and the piece need to be empty.
        #
        found_row = None
        found_col = None

        # diagonally up-right
        rownum = dst_row - 1
        colnum = dst_col + 1
        while rownum >= 0 and colnum < 8:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '':
                    break
            except Exception:
                pass
            rownum -= 1
            colnum += 1

        if found_row is not None:
            return (found_row, found_col)

        # diagonally up-left
        rownum = dst_row - 1
        colnum = dst_col - 1
        while rownum >= 0 and colnum >= 0:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '':
                    break
            except Exception:
                pass
            rownum -= 1
            colnum -= 1

        if found_row is not None:
            return (found_row, found_col)

        # diagonally down-right
        rownum = dst_row + 1
        colnum = dst_col + 1
        while rownum < 8 and colnum < 8:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '':
                    break
            except Exception:
                pass
            rownum += 1
            colnum += 1

        if found_row is not None:
            return (found_row, found_col)

        # diagonally down-left
        rownum = dst_row + 1
        colnum = dst_col - 1
        while rownum < 8 and colnum >= 0:
            try:
                if board[rownum][colnum] == piece:
                    found_row = rownum
                    found_col = colnum
                    break
                elif board[rownum][colnum] != '':
                    break
            except Exception:
                pass
            rownum += 1
            colnum -= 1
        return (found_row, found_col)

    def get_info_from_move_text(self, move_text):
        #
        # Moves look like this:
        #  Qc8
        #  Kd2
        #  Rxf6
        #  e7
        #  exd4
        #
        # When a move is ambiguous, rank and/or file is added to indicate source
        #  R1a3
        #  Rdf8
        #
        # Queens can need both
        #  Qh4e1
        #

        # destination file and rank are always there in the last two characters
        dst_col = self.convert_algebraic_file_to_col(move_text[-2])
        dst_row = self.convert_algebraic_rank_to_row(move_text[-1])
        src_col = None
        src_row = None

        outlst = [src_row, src_col, dst_row, dst_col]

        # strip these off and see if there is any other info given
        mvtext = move_text[:-2]
        if len(mvtext) == 0:
            return outlst

        # drop the piece on the front if it is there
        if mvtext[0] == mvtext[0].upper():
            mvtext = mvtext[1:]
        if len(mvtext) == 0:
            return outlst

        # drop any capture 'x'
        if mvtext[-1] == 'x':
            mvtext = mvtext[:-1]
        if len(mvtext) == 0:
            return outlst

        # there is something left, numbers indicate source ranks, letters indicate source files
        for ch in mvtext:
            if ch.isdigit():
                src_row = self.convert_algebraic_rank_to_row(ch)
                outlst[0] = src_row
            elif ch in 'abcdefgh':
                src_col = self.convert_algebraic_file_to_col(ch)
                outlst[1] = src_col
        return outlst

    def pawn_move(self, move_text, player, board):
        moves = []
        piece = 'P' if player == 'WHITE' else 'p'
        dst_piece = piece

        # check for pawn promotion
        if '=' in move_text:
            dst_piece, move_text = self.get_pawn_promotion_info(move_text)

        if player == 'BLACK':
            dst_piece = dst_piece.lower()

        # destination is always given in the move text
        dst_row = self.convert_algebraic_rank_to_row(move_text[-1])
        dst_col = self.convert_algebraic_file_to_col(move_text[-2])

        # find the pawn that is moving
        src_col = self.convert_algebraic_file_to_col(move_text[0])

        # a pawn can't move more than two squares at any time, so the source row is within two rows of the
        # destination within the source column.  Also, it has to be the first pawn we find moving from the
        # destination square back
        src_row = None
        if player == 'WHITE':
            for row in range(dst_row + 1, dst_row + 3):
                if board[row][src_col] == piece:
                    src_row = row
                    break
        else:
            for row in range(dst_row - 1, dst_row - 3, -1):
                if board[row][src_col] == piece:
                    src_row = row
                    break

        # check for en passant capture
        # (should be enough to check that the pawn is capturing in an unoccupied square)
        rem_row = None
        if 'x' in move_text and board[dst_row][dst_col] == '':
            if player == 'WHITE':
                board[dst_row + 1][dst_col] = ''
                rem_row = dst_row + 1
                rem_col = dst_col
            else:
                board[dst_row - 1][dst_col] = ''
                rem_row = dst_row - 1
                rem_col = dst_col

        board[src_row][src_col] = ''
        board[dst_row][dst_col] = dst_piece
        moves.append((src_row, src_col, dst_row, dst_col, piece))

        # promotion means drawing the promoted piece immediately after drawing the move
        if piece != dst_piece:
            moves.append((dst_row, dst_col, dst_piece))

        # handle en passant capture by removing the opposing pawn
        if rem_row is not None:
            moves.append((rem_row, rem_col, ' '))
        return moves

    def king_move(self, move_text, player, board):
        moves = []
        piece = 'K' if player == 'WHITE' else 'k'

        # there is only one king, so it isn't necessary to search for the nearest one
        for row in range(0, 8):
            for col in range(0, 8):
                if board[row][col] == piece:
                    src_row = row
                    src_col = col

        dst_col = self.convert_algebraic_file_to_col(move_text[-2])
        dst_row = self.convert_algebraic_rank_to_row(move_text[-1])

        board[src_row][src_col] = ''
        board[dst_row][dst_col] = piece
        moves.append((src_row, src_col, dst_row, dst_col, piece))
        return moves

    def queen_move(self, move_text, player, board):
        moves = []
        piece = 'Q' if player == 'WHITE' else 'q'

        src_row, src_col, dst_row, dst_col = self.get_info_from_move_text(move_text)

        if src_row is not None and src_col is not None:
            pass

        elif src_row is not None:
            src_row, src_col = self.find_piece_in_row(src_row, piece, board)

        elif src_col is not None:
            src_row, src_col = self.find_piece_in_col(src_col, piece, board)

        else:
            try:
                # no hints from the move text, start looking
                src_row, src_col = self.find_piece_in_col(dst_col, piece, board, starting_row=dst_row)
                if src_row is not None:
                    src_col = dst_col
                    raise Exception('DONE')

                src_row, src_col = self.find_piece_in_row(dst_row, piece, board, starting_col=dst_col)
                if src_col is not None:
                    src_row = dst_row
                    raise Exception('DONE')

                src_row, src_col = self.find_piece_on_diagonals(dst_row, dst_col, piece, board)

            except Exception as errmsg:
                if 'DONE' not in str(errmsg):
                    raise

        board[src_row][src_col] = ''
        board[dst_row][dst_col] = piece
        moves.append((src_row, src_col, dst_row, dst_col, piece))
        return moves

    def rook_move(self, move_text, player, board):
        moves = []
        piece = 'R' if player == 'WHITE' else 'r'

        src_row, src_col, dst_row, dst_col = self.get_info_from_move_text(move_text)

        if src_row is not None and src_col is not None:
            pass

        elif src_row is not None:
            src_row, src_col = self.find_piece_in_row(src_row, piece, board)

        elif src_col is not None:
            src_row, src_col = self.find_piece_in_col(src_col, piece, board)

        else:
            try:
                # no hints from the move text, start looking
                src_row, src_col = self.find_piece_in_col(dst_col, piece, board, starting_row=dst_row)
                if src_row is not None:
                    src_col = dst_col
                    raise Exception('DONE')

                src_row, src_col = self.find_piece_in_row(dst_row, piece, board, starting_col=dst_col)
                if src_col is not None:
                    src_row = dst_row
                    raise Exception('DONE')

            except Exception as errmsg:
                if 'DONE' not in str(errmsg):
                    raise

        board[src_row][src_col] = ''
        board[dst_row][dst_col] = piece
        moves.append((src_row, src_col, dst_row, dst_col, piece))
        return moves

    def knight_move(self, move_text, player, board):
        moves = []
        piece = 'N' if player == 'WHITE' else 'n'

        src_row, src_col, dst_row, dst_col = self.get_info_from_move_text(move_text)

        if src_row is not None and src_col is not None:
            pass

        elif src_row is not None:
            src_row, src_col = self.find_piece_in_row(src_row, piece, board)

        elif src_col is not None:
            src_row, src_col = self.find_piece_in_col(src_col, piece, board)

        else:
            src_row, src_col = self.find_knight(dst_row, dst_col, piece, board)

        board[src_row][src_col] = ''
        board[dst_row][dst_col] = piece
        moves.append((src_row, src_col, dst_row, dst_col, piece))
        return moves

    def bishop_move(self, move_text, player, board):
        moves = []
        piece = 'B' if player == 'WHITE' else 'b'

        src_row, src_col, dst_row, dst_col = self.get_info_from_move_text(move_text)
        src_row, src_col = self.find_piece_on_diagonals(dst_row, dst_col, piece, board)

        board[src_row][src_col] = ''
        board[dst_row][dst_col] = piece
        moves.append((src_row, src_col, dst_row, dst_col, piece))
        return moves

    def castle_move(self, move_text, player, board):
        moves = []
        if player == 'WHITE':
            rook = 'R'
            king = 'K'
            row = 7
        else:
            rook = 'r'
            king = 'k'
            row = 0
        king_src_col = 4

        if move_text == 'O-O-O':
            rook_src_col = 0
            rook_dst_col = 3
            king_dst_col = 2
        else:
            rook_src_col = 7
            rook_dst_col = 5
            king_dst_col = 6

        board[row][rook_src_col] = ''
        board[row][king_src_col] = ''
        board[row][rook_dst_col] = rook
        board[row][king_dst_col] = king

        moves.append((row, king_src_col, row, king_dst_col, king))
        moves.append((row, rook_src_col, row, rook_dst_col, rook))
        return moves

    def add_board_movements(self, moves, board):
        for move in moves:
            if self.move_is_end_of_game(move['move_text']):
                continue

            mtext = self.strip_annotations_from_text_move(move['move_text'])
            if mtext[0] == mtext[0].lower():
                # looks like a pawn move
                move['board_move'] = self.pawn_move(mtext, move['player'], board)

            elif mtext[0] == 'K':
                move['board_move'] = self.king_move(mtext, move['player'], board)

            elif mtext[0] == 'Q':
                move['board_move'] = self.queen_move(mtext, move['player'], board)

            elif mtext[0] == 'B':
                move['board_move'] = self.bishop_move(mtext, move['player'], board)

            elif mtext[0] == 'R':
                move['board_move'] = self.rook_move(mtext, move['player'], board)

            elif mtext[0] == 'N':
                move['board_move'] = self.knight_move(mtext, move['player'], board)

            elif mtext.startswith('O-O'):
                move['board_move'] = self.castle_move(mtext, move['player'], board)

            else:
                raise Exception(f"Parser error. I don't know what to do with {mtext}")
        return moves

    def char_to_petscii(self, inchar):
        # ascii and petscii are the same for most text, we just need to shift all letters to lowercase
        if inchar.isalpha():
            return ord(inchar.upper()) - 64
        else:
            return ord(inchar)

    def center_string_within_width(self, instr, width):
        instr = instr.strip()
        strlen = len(instr)
        if strlen > 16:
            return instr[:16]
        padlen = int((width - strlen) / 2)
        blanks = ' ' * 16
        return blanks[:padlen] + instr

    def generate_metadata_outputs(self, metadata):
        metas = {'Event': 'EV', 'White': 'WX', 'Black': 'BX', 'Date': 'DT'}
        for item in metas.keys():
            self.generate_metadata_output(item, metas[item], metadata)
        return

    def generate_metadata_output(self, item, code, metadata):
        msg = metadata.get(item, None)
        if msg is not None:
            msg = self.center_string_within_width(msg, 16)

            # byte stream code
            self.output_stream.append(self.stream_code[code])
            self.output_bytes.append(code)

            # characters in PETSCII format
            for ch in msg:
                self.output_stream.append(self.char_to_petscii(ch))
                self.output_bytes.append(self.char_to_petscii(ch))

            # end of record
            self.generate_eor()
        return

    def generate_fen_draw_outputs(self, fen_moves):
        if len(fen_moves) == 0:
            return

        # "Clear board" token
        self.output_stream.append(self.stream_code['CB'])
        self.output_bytes.append('CB')

        # "Draw N pieces" record
        self.output_stream.append(self.stream_code['DN'])
        self.output_bytes.append('DN')

        # pieces are represented as square, piece pairs
        for piecemove in fen_moves:
            row = piecemove[0]
            col = piecemove[1]
            piece = piecemove[2]
            board_square = row * 8 + col

            self.output_stream.append(board_square)
            self.output_stream.append(self.stream_code[self.board_piece_to_byte_stream[piece]])

            self.output_bytes.append(board_square)
            self.output_bytes.append(self.board_piece_to_byte_stream[piece])

        # end of record
        self.generate_eor()
        return

    def generate_first_move_data(self, moves):
        # check first move
        if len(moves) == 0:
            return
        move = moves[0]
        move_num = move['move_num']
        player = move['player']

        if move_num is None:
            move_num = 1
        if player is None:
            player = 'WHITE'
        if move_num != 1:
            self.output_stream.append(self.stream_code['MX'])
            self.output_bytes.append('MX')
            self.output_stream.append(move['move_num'])
            self.output_bytes.append(move['move_num'])
        if player != 'WHITE':
            self.output_stream.append(self.stream_code['PX'])
            self.output_bytes.append('PX')
            self.output_stream.append(2)
            self.output_bytes.append(2)
        return

    def generate_moves_data(self, moves):
        if len(moves) == 0:
            return
        for move in moves:
            if 'board_move' in move.keys():
                # the board coordinates and piece code
                for piecemove in move['board_move']:
                    if len(piecemove) == 5:
                        row = piecemove[0]
                        col = piecemove[1]
                        src_square = row * 8 + col

                        row = piecemove[2]
                        col = piecemove[3]
                        dst_square = row * 8 + col

                        piece = piecemove[4]

                        # find negative numbers
                        if src_square < 0:
                            raise Exception(f"found negative src square - move={move}")
                        if dst_square < 0:
                            raise Exception(f"found negative src square - move={move}")

                        self.output_stream.append(src_square)
                        self.output_stream.append(dst_square)
                        self.output_stream.append(self.stream_code[self.board_piece_to_byte_stream[piece]])

                        self.output_bytes.append(src_square)
                        self.output_bytes.append(dst_square)
                        self.output_bytes.append(self.board_piece_to_byte_stream[piece])

                    elif len(piecemove) == 3:
                        row = piecemove[0]
                        col = piecemove[1]
                        src_square = row * 8 + col
                        piece = piecemove[2]

                        if src_square < 0:
                            raise Exception(f"found negative src square - move={move}")

                        self.output_stream.append(self.stream_code['DP'])
                        self.output_stream.append(src_square)
                        self.output_stream.append(self.stream_code[self.board_piece_to_byte_stream[piece]])

                        self.output_bytes.append('DP')
                        self.output_bytes.append(src_square)
                        self.output_bytes.append(self.board_piece_to_byte_stream[piece])

            # a move record with no player is the end of game result
            if move['player'] is None:
                self.output_stream.append(self.stream_code['EOG'])
                self.output_bytes.append('EOG')

                for ch in self.center_string_within_width(move['move_text'], 16):
                    self.output_stream.append(self.char_to_petscii(ch))
                    self.output_bytes.append(self.char_to_petscii(ch))
                self.generate_eor()

            else:
                # the PGN text record
                self.output_stream.append(self.stream_code['PG'])
                self.output_bytes.append('PG')

                # max any given move at 6 chars
                for ch in move['move_text'][:6]:
                    self.output_stream.append(self.char_to_petscii(ch))
                    self.output_bytes.append(self.char_to_petscii(ch))
                self.generate_eor()

            # output a wait at the end of each move
            self.generate_pause()
        return

    def generate_pause(self, num=1):
        for i in range(0, num):
            self.output_stream.append(self.stream_code['ZZ'])
            self.output_bytes.append('ZZ')
        return

    def generate_eog(self):
        self.output_stream.append(self.stream_code['NG'])
        self.output_bytes.append('NG')
        return

    def generate_eor(self):
        self.output_stream.append(self.stream_code['EOR'])
        self.output_bytes.append('EOR')
        return

    def generate_eof(self):
        self.output_stream.append(self.stream_code['EOF'])
        self.output_bytes.append('EOF')
        return

    def dump_asm_byte_statements(self):
        # this routine was originally used to dump the data stream out as a block of memory that could be
        # copy-n-pasted into the main program to use in place of data read from a file on disk. I've kept it
        # here because it's still useful as a way to see the actual byte stream generated.
        count = 0
        outline = []
        for out in self.output_bytes:
            if count % 20 == 0 and len(outline) > 0:
                line = ', '.join(outline)
                outline = []
                print(f"     .byte {line}")
            outline.append(f"{out:>3}")
            count += 1
        line = ', '.join(outline)
        print(f"     .byte {line}")
        return count

    def dump_title_byte_statement(self):
        # was originally used to generate the PETSCII codes necessary to print "CHESS REPLAYER" on the screen.
        # I've left it here as a simple way to generate PETSCII from ASCII if/when necessary in the future.
        msg = 'CHESS REPLAYER'
        print("     .byte ", end='')
        for ch in msg:
            print(f"{self.char_to_petscii(ch)}, ", end='')
        print("EOR")
        return

    def write_pet_datafile(self, filename):
        count = 0
        for ch in self.output_stream:
            count += 1
            # check for a couple of errors found in earlier versions of this program
            if ch is None:
                print(f"found None at count={count}")
            if ch < 0:
                print(f"found {ch} at count={count}")
        with open(filename, 'wb') as fhw:
            # write the loading address in first two bytes
            fhw.write(struct.pack('BB', CHESS_DATA_STARTING_ADDRESS_LSB,
                                  CHESS_DATA_STARTING_ADDRESS_MSB))
            try:
                for ch in self.output_stream:
                    fhw.write(struct.pack('B', ch))
            except Exception:
                print(f"Couldn't write {ch} to file")
                raise
        return count


if __name__ == '__main__':
    helptext = """
Transforms an ASCII .pgn file into a binary file that can be read by the
PET Chess Replayer.

NOTE: The output file is always named chessdata.  This is the name that the
PET Chess Replayer expects.  Running this program WILL OVERWRITE an existing
chessdata file.  Making backup copies of chessdata files you want to keep
is advised.
"""
    argp = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter, description=helptext)
    argp.add_argument('filenames', nargs='+', help='Names of a valid .pgn files')
    args = argp.parse_args()

    ptp = PgnToPet(args.filenames)

    num_bytes = ptp.write_pet_datafile('chessdata')
    print(f"number of bytes written to chessdata file: {num_bytes}")
    num_bytes = ptp.dump_asm_byte_statements()
    print(f"number of bytes printed to screen: {num_bytes}")
