:- module(terminal, [
    winner/2,
    game_over/2
]).

:- use_module(rules).
:- use_module(moves).
:- use_module(game_state).

winner(Board, white) :-
    nth1(1, Board, Row),
    member(white, Row), !.

winner(Board, black) :-
    board_size(Board, Size),
    nth1(Size, Board, Row),
    member(black, Row), !.

winner(Board, white) :-
    count_pieces(Board, black, 0), !.

winner(Board, black) :-
    count_pieces(Board, white, 0), !.

game_over(Board, Winner) :-
    winner(Board, Winner), !.
game_over(Board, Winner) :-
    legal_moves(Board, white, []), Winner = black, !.
game_over(Board, Winner) :-
    legal_moves(Board, black, []), Winner = white.