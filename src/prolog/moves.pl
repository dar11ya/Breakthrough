:- module(moves, [
    legal_move/3,
    legal_moves/3
]).

:- use_module(rules).

legal_move(Board, Player, move(R1,C1,R2,C2)) :-
    get_cell(Board, R1, C1, Player),
    forward_dir(Player, D),
    R2 is R1 + D,
    (
        C2 = C1,
        inside_board(Board, R2, C2),
        get_cell(Board, R2, C2, empty)
    ;
        C2 is C1 - 1,
        diag_target_ok(Board, Player, R2, C2)
    ;
        C2 is C1 + 1,
        diag_target_ok(Board, Player, R2, C2)
    ).

legal_moves(Board, Player, Moves) :-
    findall(move(R1,C1,R2,C2),
        legal_move(Board, Player, move(R1,C1,R2,C2)),
        Moves).

diag_target_ok(Board, _Player, R, C) :-
    inside_board(Board, R, C),
    get_cell(Board, R, C, empty), !.
diag_target_ok(Board, Player, R, C) :-
    inside_board(Board, R, C),
    enemy(Player, Enemy),
    get_cell(Board, R, C, Enemy).