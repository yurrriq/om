-module(om).
-description('CoC Compiler').
-behaviour(supervisor).
-include("om.hrl").
-behaviour(application).
-export([init/1, start/2, stop/1]).
-compile(export_all).

% env

privdir()    -> application:get_env(om,priv,"priv").
mode(S)      -> application:set_env(om,mode,S).
mode()       -> application:get_env(om,mode,"normal").
debug(S)     -> application:set_env(om,debug,atom(S)).
debug()      -> application:get_env(om,debug,false).

% constants
allmodes()   -> ["hurkens","normal","setoids","new-setoids", "posets"].
modes()      -> allmodes() ++ ["src-hurkens", "russell","girard"].

% providing functions

help(_)      -> help().
help()       -> om_help:help().
pwd(_)       -> mad_repl:cwd().
print(X)     -> io:format("~ts~n",[bin(X)]).
bin(X)       -> unicode:characters_to_binary(om:flat(om_parse:print(X,0))).
extract(_)   -> extract().
extract()    -> om_extract:scan().
normalize(T) -> om_type:normalize(T).
eq(X,Y)      -> om_type:eq(X,Y).
type(S)      -> type(S,[]).
type(T,C)    -> om_type:type(T,C).
erase(X)     -> erase(X,[]).
erase(T,C)   -> om_erase:erase(T,C).
modes(_)     -> modes().
allmodes(_)  -> allmodes().
priv(Mode)   -> lists:concat([privdir(),"/",Mode]).
name(M,[])   -> priv(mode());
name(M,F)    -> string:join([priv(mode()),F],"/").
name(M,[],F) -> name(M,F);
name(M,P,F)  -> string:join([priv(mode()),P,F],"/").
tokens(B)    -> om_tok:tokens([],B,0,{1,[]},[]).
str(F)       -> tokens(unicode:characters_to_binary(F)).
read(F)      -> tokens(file(F)).
comp(F)      -> rev(tokens(F,"/")).
normal(F)    -> om_type:normalize(F).
cname(F)     -> hd(comp(F)).
tname(F)     -> tname(F,[]).
pname(F)     -> string:join(tl(tl(string:tokens(F,"/"))),"/").
tname(F,S)   -> X = string:join(rev(tl(comp(F))),"/"), case om:mode() of X -> []; _ -> X ++ S end.
show(F)      -> Term = snd(parse(tname(F),cname(F))), mad:info("~n~ts~n~n", [bin(Term)]), Term.
a(F)         -> snd(parse(str(F))).
fst({X,_})   -> X.
snd({error,X}) -> {error,X};
snd({_,[X]}) -> X;
snd({_,X})   -> X.
parse(X)     -> om_parse:expr2([],X,[],{0,0}).
parse(T,C)   -> om_parse:expr2(T,read(name(mode(),T,C)),[],{0,0}).
linear(C)    -> put(inc,0), R = om_parse:expr2([],C,[],{0,0}),
                case {get(inc),length(C)} of {X,Y} when X =< Y * 2 -> R ; {X,Y} -> {error,{nonlinear,X,Y}} end.
cache_src(N)       -> om_cache:load(src,N).
cache_term(N)      -> om_cache:load(term,N).
cache_normal(N)    -> om_cache:load(normal,N).
cache_type(N)      -> om_cache:load(type,N).
cache_erased(N)    -> om_cache:load(erased,N).
cache_extracted(N) -> om_cache:load(extracted,N).

% system functions

convert(A,S, nt) -> convert(A,S);
convert(A,S, _)  -> A.

convert([],Acc) -> rev(Acc);
convert([$>|T],Acc) -> convert(T,[61502|Acc]);
convert([$<|T],Acc) -> convert(T,[61500|Acc]);
convert([$:|T],Acc) -> convert(T,[61498|Acc]);
convert([$||T],Acc) -> convert(T,[61564|Acc]);
convert([H|T],Acc)  -> convert(T,[H|Acc]).

opt()        -> [ set, named_table, { keypos, 1 }, public ].
tables()     -> [ terms, types, erased ].
boot()       -> [ ets:new(T,opt()) || T <- tables() ],
                [ code:del_path(S) || S <- code:get_path(), string:str(S,"stdlib") /= 0 ].
unicode()    -> io:setopts(standard_io, [{encoding, unicode}]).
main(A)      -> unicode(), case A of [] -> mad:main(["sh"]); A -> console(A) end.
start()      -> start(normal,[]).
start(_,_)   -> unicode(), mad:info("~tp~n",[om:ver()]), supervisor:start_link({local,om},om,[]).
stop(_)      -> ok.
init([])     -> boot(), mode("normal"), {ok, {{one_for_one, 5, 10}, []}}.
ver(_)       -> ver().
ver()        -> {version,[keyget(I,element(2,application:get_all_key(om)))||I<-[description,vsn]]}.
console(S)   -> boot(),
                mad_repl:load(), put(ret,0),
                Fold = lists:foldr(fun(I,O) ->
                      R = rev(I),
                      Res = lists:foldl(fun(X,A) -> om:(atom(X))(A) end,hd(R),tl(R)),
                      io:format("~tp~n",[Res]),
                      [get(ret)|O]
                      end, [], string:tokens(S,[","])),
                halt(lists:sum(Fold)).

% test suite
% TODO use cache in tests // no pipes!

typed(X)     -> try Y = om:type(X),  {X,[]} catch E:R -> {X,typed}  end.
erased(X)    -> try A = om:erase(X), {A,[]} catch E:R -> {X,erased} end.
parsed(F)    -> case parse([],pname(F)) of {_,[X]} -> {X,[]}; _ -> {F,parsed} end.
pipe(L)      -> io:format("[~tp]",[L]), % workaround for trevis timeout break
                lists:foldl(fun(X,{A,D}) ->
                {N,E}=?MODULE:X(A), {N,[E|D]} end,{L,[]},[parsed,typed,erased]).
pass(0)      -> "PASSED";
pass(X)      -> "FAILED " ++ integer_to_list(X).
all(_)       -> all().
all()        -> om:debug(false), lists:flatten([ begin om:mode(M), om:scan() end || M <- allmodes() ]).
syscard(P)    -> [ {F} || F <- filelib:wildcard(name(mode(),P,"**/*")), filelib:is_dir(F) /= true ].
wildcard(P)  -> Q = om:name(mode(),P), lists:flatten([ {A} || {A,B} <- ets:tab2list(filesystem), lists:sublist(A,length(Q)) == Q ]).
scan()       -> scan([]).
scan(P)      -> om:debug(false),
                Res = [ { flat(element(2,pipe(F))), lists:concat([tname(F),"/",cname(F)])}
                     || {F} <- lists:umerge(wildcard(P),syscard(P)),
                        lists:member(lists:nth(2,tokens(F,"/")),modes()) ],
                Passed = lists:foldl(fun({X,_},B) -> case X of [] -> B; _ -> B + 1 end end, 0, Res),
                {mode(),pass(Passed),Res}.
test(_)      -> All = om:all(),
                io:format("~tp~n",[om_parse:test()]),
                io:format("~tp~n",[All]),
                case lists:all(fun({Mode,Status,Tests}) -> Status == om:pass(0) end, All) of
                     true  -> 0;
                     false -> put(ret,1),1 end .

% relying functions

rev(X)       -> lists:reverse(X).
flat(X)      -> lists:flatten(X).
tokens(X,Y)  -> string:tokens(X,Y).
debug(S,A)   -> case om:debug() of true -> io:format(S,A); false -> ok end.
atom(X)      -> list_to_atom(cat([X])).
cat(X)       -> lists:concat(X).
keyget(K,D)  -> proplists:get_value(K,D).
keyget(K,D,I)  -> lists:nth(I+1,proplists:get_all_values(K,D)).
hierarchy(Arg,Out) -> Out.           % impredicative
%hierarchy(Arg,Out) -> max(Arg,Out). % predicative

file(F) -> case file:read_file(convert(F,[],element(2,os:type()))) of
                {ok,Bin} -> Bin;
                {error,_} -> mad(F) end.

mad(F)  -> case mad_repl:load_file(F) of
                {ok,Bin} -> Bin;
                {error,_} -> erlang:error({"File not found",F}) % <<>>
            end.
