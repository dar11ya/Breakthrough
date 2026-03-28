:- module(rules, [
    inside_board/3,
    get_cell/4,
    set_cell/5,
    forward_dir/2,
    enemy/2,
    count_pieces/3,
    board_size/2
]).

board_size(Board, Size) :-
    length(Board, Size).

inside_board(Board, Row, Col) :-
    board_size(Board, Size),
    Row >= 1, Row =< Size,
    Col >= 1, Col =< Size.

get_cell(Board, Row, Col, Value) :-
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, Value).

set_cell(Board, Row, Col, Value, NewBoard) :-
    nth1(Row, Board, OldRow, RestRows),
    nth1(Col, OldRow, _OldValue, RestCells),
    nth1(Col, NewRow, Value, RestCells),
    nth1(Row, NewBoard, NewRow, RestRows).

forward_dir(white, -1).
forward_dir(black, 1).

enemy(white, black).
enemy(black, white).

count_pieces(Board, Player, Count) :-
    findall(1,
        (member(Row, Board), member(Player, Row)),
        Pieces),
    length(Pieces, Count).