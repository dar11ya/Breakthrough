:- module(game_state, [
    initial_board/2,
    other_player/2,
    difficulty_depth/2,
    default_state/1
]).

other_player(white, black).
other_player(black, white).

difficulty_depth(easy, 2).
difficulty_depth(medium, 4).
difficulty_depth(hard, 6).

default_state(state(Board, white, human_human, medium, playing, none)) :-
    initial_board(8, Board).

initial_board(Size, Board) :-
    TopRow = black,
    BottomRow = white,
    Empty = empty,
    findall(Row,
        (between(1, Size, R), make_row(Size, R, TopRow, BottomRow, Empty, Row, Size)),
        Board).


make_row(Size, R, TopRow, _BottomRow, _Empty, Row, _N) :-
    R =< 2,
    make_filled_row(Size, TopRow, Row), !.
make_row(Size, R, _TopRow, BottomRow, _Empty, Row, N) :-
    R >= N - 1,
    make_filled_row(Size, BottomRow, Row), !.
make_row(Size, _R, _TopRow, _BottomRow, Empty, Row, _N) :-
    make_filled_row(Size, Empty, Row).

make_filled_row(Size, Value, Row) :-
    length(Row, Size),
    maplist(=(Value), Row).