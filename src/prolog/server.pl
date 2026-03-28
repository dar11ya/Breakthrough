:- module(server, [start_server/1]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_parameters)).

:- use_module(game_state).
:- use_module(moves).
:- use_module(apply_move).
:- use_module(terminal).
:- use_module(ai).

:- dynamic current_state/1.

:- multifile http:location/3.
:- dynamic   http:location/3.
http:location(web, '/static', []).

% ---------------------------
% START SERVER
% ---------------------------
start_server(Port) :-
    % compute file paths here
    prolog_load_context(directory, Dir),
    format("DIR = ~w~n", [Dir]),

    absolute_file_name('../web', WebDir, [relative_to(Dir)]),
    format("WebDir = ~w~n", [WebDir]),

    absolute_file_name('../web/index.html', IndexFile, [relative_to(Dir)]),
    format("IndexFile = ~w~n", [IndexFile]),

    % now install handlers
    http_handler(root(.), http_reply_file(IndexFile, []), []),
    http_handler(web(.), serve_files_in_directory(WebDir), [prefix]),

    % API endpoints
    http_handler(root(api/new_game), new_game_handler, []),
    http_handler(root(api/legal_moves), legal_moves_handler, []),
    http_handler(root(api/make_move), make_move_handler, []),
    http_handler(root(api/ai_move), ai_move_handler, []),
    http_handler(root(api/surrender), surrender_handler, []),
    http_handler(root(api/end_game), end_game_handler, []),
    http_handler(root(api/state), state_handler, []),

    % init game state
    retractall(current_state(_)),
    default_state(State),
    assertz(current_state(State)),

    % start http server
    http_server(http_dispatch, [port(Port)]).

% CLI entry point
:- initialization(main, main).
main :-
    writeln('MAIN STARTED'),
    current_prolog_flag(argv, Argv),
    writeln(argv=Argv),
    ( Argv = [PortAtom|_] ->
        writeln(portAtom=PortAtom),
        atom_number(PortAtom, Port),
        writeln(port=Port)
    ; 
        writeln('no port provided'),
        Port = 8080
    ),
    writeln('calling start_server'),
    start_server(Port),
    writeln('server started OK').

new_game_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Size = Dict.get(size),
    ModeAtom = Dict.get(mode),
    DifficultyAtom = Dict.get(difficulty),
    atom_string(Mode, ModeAtom),
    atom_string(Difficulty, DifficultyAtom),
    initial_board(Size, Board),
    State = state(Board, white, Mode, Difficulty, playing, none),
    retractall(current_state(_)),
    assertz(current_state(State)),
    reply_json_dict(_{ok:true, state:State}).

legal_moves_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Board = Dict.get(board),
    PlayerAtom = Dict.get(player),
    atom_string(Player, PlayerAtom),
    normalize_board(Board, Normalized),
    legal_moves(Normalized, Player, Moves),
    moves_to_dicts(Moves, MoveDicts),
    reply_json_dict(_{ok:true, moves:MoveDicts}).

make_move_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Board0 = Dict.get(board),
    PlayerAtom = Dict.get(player),
    MoveDict = Dict.get(move),
    atom_string(Player, PlayerAtom),
    normalize_board(Board0, Board),
    dict_to_move(MoveDict, Move),
    ( apply_move(Board, Player, Move, NewBoard) ->
        ( game_over(NewBoard, Winner) ->
            atom_string(Winner, WinnerStr),
            reply_json_dict(_{ok:true, board:NewBoard, gameOver:true, winner:WinnerStr})
        ;
            other_player(Player, Next),
            atom_string(Next, NextStr),
            reply_json_dict(_{ok:true, board:NewBoard, gameOver:false, nextPlayer:NextStr})
        )
    ;
        reply_json_dict(_{ok:false, message:"Illegal move"})
    ).

ai_move_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Board0 = Dict.get(board),
    PlayerAtom = Dict.get(player),
    DifficultyAtom = Dict.get(difficulty),
    atom_string(Player, PlayerAtom),
    atom_string(Difficulty, DifficultyAtom),
    normalize_board(Board0, Board),
    ( best_move(Board, Player, Difficulty, minimax, Move) ->
        apply_move(Board, Player, Move, NewBoard),
        move_to_dict(Move, MoveDict),
        ( game_over(NewBoard, Winner) ->
            atom_string(Winner, WinnerStr),
            reply_json_dict(_{ok:true, move:MoveDict, board:NewBoard, gameOver:true, winner:WinnerStr})
        ;
            other_player(Player, Next),
            atom_string(Next, NextStr),
            reply_json_dict(_{ok:true, move:MoveDict, board:NewBoard, gameOver:false, nextPlayer:NextStr})
        )
    ;
        reply_json_dict(_{ok:false, message:"AI has no move"})
    ).


surrender_handler(Request) :-
    http_read_json_dict(Request, Dict),
    PlayerAtom = Dict.get(player),
    atom_string(Player, PlayerAtom),
    other_player(Player, Winner),
    atom_string(Winner, WinnerStr),
    reply_json_dict(_{ok:true, gameOver:true, winner:WinnerStr}).

end_game_handler(_Request) :-
    retractall(current_state(_)),
    reply_json_dict(_{ok:true, message:"Game ended"}).

state_handler(_Request) :-
    ( current_state(State) ->
        reply_json_dict(_{ok:true, state:State})
    ;
        reply_json_dict(_{ok:false})
    ).


normalize_board(Board0, Board) :-
    maplist(normalize_row, Board0, Board).

normalize_row(Row0, Row) :-
    maplist(normalize_cell, Row0, Row).

normalize_cell("white", white).
normalize_cell("black", black).
normalize_cell("empty", empty).
normalize_cell(white, white).
normalize_cell(black, black).
normalize_cell(empty, empty).

move_to_dict(move(R1,C1,R2,C2), _{fromRow:R1, fromCol:C1, toRow:R2, toCol:C2}).

moves_to_dicts([], []).
moves_to_dicts([M|Ms], [D|Ds]) :-
    move_to_dict(M, D),
    moves_to_dicts(Ms, Ds).

dict_to_move(Dict, move(R1,C1,R2,C2)) :-
    R1 = Dict.get(fromRow),
    C1 = Dict.get(fromCol),
    R2 = Dict.get(toRow),
    C2 = Dict.get(toCol).