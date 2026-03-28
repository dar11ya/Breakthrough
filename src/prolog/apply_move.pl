:- module(apply_move, [
    apply_move/4
]).

:- use_module(rules).
:- use_module(moves).

apply_move(Board, Player, move(R1,C1,R2,C2), NewBoard) :-
    legal_move(Board, Player, move(R1,C1,R2,C2)),
    set_cell(Board, R1, C1, empty, TempBoard),
    set_cell(TempBoard, R2, C2, Player, NewBoard).