-module(om_parse).
-description('Parser').
-compile(export_all).

%     I := #identifier
%     O := ∅ | ( O ) |
%          □ | ∀ ( I : O ) → O |
%          * | λ ( I : O ) → O |
%          I | O → O | O O

expr(P,[],                       Acc)  ->             rewind(Acc,[],[]);
expr(P,[close               |T], Acc)  -> {T1,Acc1} = rewind(Acc, T,[]),      expr(P,T1,Acc1);
expr(P,[{remote,{X,L}}      |T], Acc)  -> expr(P,T,[ret(om:term([],L))|Acc]);
expr(P,[{remote,L}          |T], Acc)  -> expr(P,T,[om:term(L)|Acc]);
expr(P,[{star,I}            |T], Acc)  -> expr(P,T,[{star,I}|Acc]);
expr(P,[{N,X}|T],  [{typevar,Y}| Acc]) -> expr(P,T,[{N,X},{typevar,Y}|Acc]);
expr(P,[{N,X}|T],        [{C,Y}| Acc]) -> expr(P,T,[{app,{{C,Y},{N,X}}}|Acc]);
expr(P,[star                |T], Acc)  -> expr(P,T,[{star,1}|Acc]);
expr(P,[box                 |T], Acc)  -> expr(P,T,[{box,1}|Acc]);
expr(P,[open                |T], Acc)  -> expr(P,T,[{open}|Acc]);
expr(P,[arrow               |T], Acc)  -> expr(P,T,[{arrow}|Acc]);
expr(P,[lambda              |T], Acc)  -> expr(P,T,[{lambda}|Acc]);
expr(P,[pi                  |T], Acc)  -> expr(P,T,[{pi}|Acc]);
expr(P,[colon               |T], Acc)  -> expr(P,T,[{colon}|Acc]);
expr(P,[{var,L},colon       |T], Acc)  -> expr(P,T,[{typevar,L}|Acc]);
expr(P,[{var,L}             |T], Acc)  -> expr(P,T,[{var,L}|Acc]).

% During forward pass we stack applications (except typevars), then
% on reaching close paren ")" we perform backward pass and stack arrows,
% until neaarest unstacked open paren "(" appeared (then we just return
% control to the forward pass).

% We need to preserve applies to typevars as they should
% be processes lately on rewind pass, so we have just typevars bypassing rule.
% On the rewind pass we stack lambdas by matching arrow/apply signatures
% where typevar(x) is an introduction of variable "x" to the Gamma context.
%
%                   apply: (A->B) x A -> B
%                  lambda: arrow(app(typevar(x),A),B)
%

-define(is_fun(F), F == lambda; F== pi).

rewind([{F}|Acc],            T,  [{"→",{{app,{{typevar,{L,M}},{A,X}}},{B,Y}}}|R]) when ?is_fun(F) -> rewind(Acc,T,[{{func(F),{L,M}},{{A,X},{B,Y}}}|R]);
rewind([{F}|Acc],            T,  [{"→",{{L,{{app,{{typevar,M},A}},X}},{B,Y}}}|R]) when ?is_fun(F) -> rewind(Acc,T,[{{func(F),M},{{L,{A,X}},{B,Y}}}|R]);
rewind([{A,X}|Acc],          T,  [{B,Y}|R]) -> rewind(Acc,T,[{app,{{A,X},{B,Y}}}|R]);
rewind([{A,X}|Acc],          T,  R)         -> rewind(Acc,T,[{A,X}|R]);
rewind([{arrow},Y|Acc],      T,  [X|R])     -> rewind(Acc,T,[{func(arrow),{Y,X}}|R]);
rewind([{open},{A,X}|Acc],   T,  [{B,Y}|R]) -> {T,om:flat([{app,{{A,X},{B,Y}}}|[R|Acc]])};
rewind([{open}|Acc],         T,  R)         -> {T,om:flat([R|Acc])};
rewind([{colon}|Acc],        T,  R)         -> {T,om:flat([R|Acc])};
rewind([],                   T,  R)         -> {T,R}.

func(lambda) -> "λ";
func(pi)     -> "∀";
func(arrow)  -> "→";
func(star)   -> "*";
func(Sym)    -> Sym.

ret({[],[X]}) -> X;
ret(Y) -> Y.
