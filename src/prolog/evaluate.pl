:- module(evaluate, [
    evaluate_board/3
]).

:- use_module(rules).


evaluate_board(Board, Player, Score) :-
    enemy(Player, Enemy),
    count_pieces(Board, Player, MyCount),
    count_pieces(Board, Enemy, EnemyCount),
    advancement(Board, Player, MyAdv),
    advancement(Board, Enemy, EnemyAdv),
    MobilityScore is 0,
    Score is 20 * (MyCount - EnemyCount) + 3 * (MyAdv - EnemyAdv) + MobilityScore.

advancement(Board, Player, Score) :-
    findall(Value,
        piece_progress(Board, Player, Value),
        Values),
    sum_list(Values, Score).

piece_progress(Board, white, Value) :-
    nth1(R, Board, Row),
    nth1(_C, Row, white),
    board_size(Board, Size),
    Value is Size - R + 1.
piece_progress(Board, black, Value) :-
    nth1(R, Board, Row),
    nth1(_C, Row, black),
    Value is R.
    