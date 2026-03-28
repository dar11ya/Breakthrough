:- module(server, [start_server/1]).
:- use_module(library(thread)).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).

:- use_module(game_state).
:- use_module(moves).
:- use_module(apply_move).
:- use_module(terminal).
:- use_module(ai).

:- dynamic current_state/1.

:- multifile http:location/3.
:- dynamic   http:location/3.

:- initialization(main, main).

% ----- paths -----

server_dir(Dir) :-
    source_file(server:server_dir(_), File),
    file_directory_name(File, Dir).

web_dir(WebDir) :-
    server_dir(Dir),
    absolute_file_name('../web', WebDir, [relative_to(Dir)]).

index_file(IndexFile) :-
    web_dir(WebDir),
    absolute_file_name('index.html', IndexFile, [relative_to(WebDir)]).

% ----- handlers -----

:- http_handler(root(.), home_handler, []).
:- http_handler(root('style.css'), web_css_handler, []).
:- http_handler(root('app.js'), web_js_handler, []).
:- http_handler(root(api/new_game), new_game_handler, []).
:- http_handler(root(api/legal_moves), legal_moves_handler, []).
:- http_handler(root(api/make_move), make_move_handler, []).
:- http_handler(root(api/ai_move), ai_move_handler, []).
:- http_handler(root(api/surrender), surrender_handler, []).
:- http_handler(root(api/end_game), end_game_handler, []).
:- http_handler(root(api/state), state_handler, []).

home_handler(Request) :-
    index_file(IndexFile),
    http_reply_file(IndexFile, [unsafe(true)], Request).

web_css_handler(Request) :-
    web_dir(WebDir),
    absolute_file_name('style.css', CssFile, [relative_to(WebDir)]),
    http_reply_file(CssFile, [unsafe(true)], Request).

web_js_handler(Request) :-
    web_dir(WebDir),
    absolute_file_name('app.js', JsFile, [relative_to(WebDir)]),
    http_reply_file(JsFile, [unsafe(true)], Request).

% ----- server start -----

start_server(Port) :-
    retractall(current_state(_)),
    default_state(State),
    assertz(current_state(State)),
    http_server(http_dispatch, [port(Port)]).

main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [PortAtom|_]
    ->  atom_number(PortAtom, Port)
    ;   Port = 8080
    ),
    start_server(Port),
    format('Server started at http://localhost:~w~n', [Port]),
    thread_get_message(_).

% ----- api -----

new_game_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Size = Dict.get(size),
    ModeString = Dict.get(mode),
    DifficultyString = Dict.get(difficulty),
    atom_string(Mode, ModeString),
    atom_string(Difficulty, DifficultyString),
    initial_board(Size, Board),
    State = state(Board, white, Mode, Difficulty, playing, none),
    retractall(current_state(_)),
    assertz(current_state(State)),
    reply_json_dict(_{
        ok:true,
        board:Board,
        currentPlayer:"white",
        mode:ModeString,
        difficulty:DifficultyString,
        status:"playing",
        winner:null
    }).

legal_moves_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Board0 = Dict.get(board),
    PlayerString = Dict.get(player),
    atom_string(Player, PlayerString),
    normalize_board(Board0, Board),
    legal_moves(Board, Player, Moves),
    moves_to_dicts(Moves, MoveDicts),
    reply_json_dict(_{ok:true, moves:MoveDicts}).

make_move_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Board0 = Dict.get(board),
    PlayerString = Dict.get(player),
    MoveDict = Dict.get(move),
    atom_string(Player, PlayerString),
    normalize_board(Board0, Board),
    dict_to_move(MoveDict, Move),
    (   apply_move(Board, Player, Move, NewBoard)
    ->  (   game_over(NewBoard, Winner)
        ->  atom_string(Winner, WinnerString),
            reply_json_dict(_{
                ok:true,
                board:NewBoard,
                gameOver:true,
                winner:WinnerString
            })
        ;   other_player(Player, Next),
            atom_string(Next, NextString),
            reply_json_dict(_{
                ok:true,
                board:NewBoard,
                gameOver:false,
                nextPlayer:NextString
            })
        )
    ;   reply_json_dict(_{ok:false, message:"Illegal move"})
    ).

ai_move_handler(Request) :-
    http_read_json_dict(Request, Dict),
    Board0 = Dict.get(board),
    PlayerString = Dict.get(player),
    DifficultyString = Dict.get(difficulty),
    atom_string(Player, PlayerString),
    atom_string(Difficulty, DifficultyString),
    normalize_board(Board0, Board),
    (   best_move(Board, Player, Difficulty, minimax, Move)
    ->  apply_move(Board, Player, Move, NewBoard),
        move_to_dict(Move, MoveDict),
        (   game_over(NewBoard, Winner)
        ->  atom_string(Winner, WinnerString),
            reply_json_dict(_{
                ok:true,
                move:MoveDict,
                board:NewBoard,
                gameOver:true,
                winner:WinnerString
            })
        ;   other_player(Player, Next),
            atom_string(Next, NextString),
            reply_json_dict(_{
                ok:true,
                move:MoveDict,
                board:NewBoard,
                gameOver:false,
                nextPlayer:NextString
            })
        )
    ;   reply_json_dict(_{ok:false, message:"AI has no move"})
    ).

surrender_handler(Request) :-
    http_read_json_dict(Request, Dict),
    PlayerString = Dict.get(player),
    atom_string(Player, PlayerString),
    other_player(Player, Winner),
    atom_string(Winner, WinnerString),
    reply_json_dict(_{ok:true, gameOver:true, winner:WinnerString}).

end_game_handler(_Request) :-
    retractall(current_state(_)),
    reply_json_dict(_{ok:true, message:"Game ended"}).

state_handler(_Request) :-
    (   current_state(state(Board, Player, Mode, Difficulty, Status, Winner))
    ->  atom_string(Player, PlayerString),
        atom_string(Mode, ModeString),
        atom_string(Difficulty, DifficultyString),
        reply_json_dict(_{
            ok:true,
            board:Board,
            currentPlayer:PlayerString,
            mode:ModeString,
            difficulty:DifficultyString,
            status:Status,
            winner:Winner
        })
    ;   reply_json_dict(_{ok:false})
    ).

% ----- helpers -----

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

move_to_dict(move(R1,C1,R2,C2), _{
    fromRow:R1, fromCol:C1, toRow:R2, toCol:C2
}).

moves_to_dicts([], []).
moves_to_dicts([M|Ms], [D|Ds]) :-
    move_to_dict(M, D),
    moves_to_dicts(Ms, Ds).

dict_to_move(Dict, move(R1,C1,R2,C2)) :-
    R1 = Dict.get(fromRow),
    C1 = Dict.get(fromCol),
    R2 = Dict.get(toRow),
    C2 = Dict.get(toCol).
