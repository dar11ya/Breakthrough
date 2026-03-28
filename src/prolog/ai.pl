:- module(ai, [
    best_move/5
]).

:- use_module(game_state).
:- use_module(moves).
:- use_module(apply_move).
:- use_module(terminal).
:- use_module(evaluate).

best_move(Board, Player, Difficulty, minimax, BestMove) :-
    difficulty_depth(Difficulty, Depth),
    legal_moves(Board, Player, Moves),
    Moves \= [],
    choose_best(Board, Player, Player, Depth, Moves, nil, -1000000, BestMove).

choose_best(_, _, _, _, [], BestMove, _, BestMove).
choose_best(Board, RootPlayer, CurrentPlayer, Depth, [Move|Rest], CurrentBest, CurrentScore, BestMove) :-
    apply_move(Board, CurrentPlayer, Move, NextBoard),
    other_player(CurrentPlayer, NextPlayer),
    D1 is Depth - 1,
    minimax(NextBoard, RootPlayer, NextPlayer, D1, Score),
    ( Score > CurrentScore ->
        NewBest = Move,
        NewScore = Score
    ;
        NewBest = CurrentBest,
        NewScore = CurrentScore
    ),
    choose_best(Board, RootPlayer, CurrentPlayer, Depth, Rest, NewBest, NewScore, BestMove).

minimax(Board, RootPlayer, _CurrentPlayer, Depth, Score) :-
    Depth =< 0,
    evaluate_board(Board, RootPlayer, Score), !.
minimax(Board, RootPlayer, _CurrentPlayer, _Depth, Score) :-
    game_over(Board, Winner),
    terminal_score(Winner, RootPlayer, Score), !.
minimax(Board, RootPlayer, CurrentPlayer, Depth, Score) :-
    legal_moves(Board, CurrentPlayer, Moves),
    Moves \= [],
    D1 is Depth - 1,
    other_player(CurrentPlayer, NextPlayer),
    findall(S,
    (
            member(Move, Moves),
            apply_move(Board, CurrentPlayer, Move, NewBoard),
            minimax(NewBoard, RootPlayer, NextPlayer, D1, S)
        ),
        Scores),
    choose_score(CurrentPlayer, RootPlayer, Scores, Score).
minimax(_Board, RootPlayer, CurrentPlayer, _Depth, Score) :-
    other_player(CurrentPlayer, Winner),
    terminal_score(Winner, RootPlayer, Score).

choose_score(Player, RootPlayer, Scores, Score) :-
    ( Player = RootPlayer -> max_list(Scores, Score)
    ; min_list(Scores, Score)
    ).

terminal_score(Winner, Winner, 100000).
terminal_score(Winner, Player, -100000) :- Winner \= Player.