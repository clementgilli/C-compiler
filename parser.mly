%{
  open Ast_c
%}

/* def token */

%token <int> CST
%token <string> IDENT COM BCOM
%token INT VOID RETURN PRINTINT 
%token WHILE FOR
%token AND OR NOT IF ELSE
%token LEQ GEQ LE GE EQQ NEQ
%token EOF
%token LP RP LB RB
%token PLUS MINUS TIMES DIV MOD
%token EQ
%token COMMA SEMICOLON
%token ESP

/* def priorites */

(*%right EQ*)
%left OR
%left AND
%left EQQ NEQ
%left LEQ GEQ LE GE
%left PLUS MINUS 
%left TIMES DIV MOD
%nonassoc uminus not

%start file

%type <Ast_c.prog> file

%%

file: 
  | d = def* ; EOF {{defs = d }}
;

types:
  | INT { Int }
  | VOID { Void }

type_args_fun:
  | typ = types ; TIMES* ;i = IDENT { Args(typ,i) }

def: tip = types ;TIMES* ;nom = IDENT ; LP ; args = separated_list(COMMA,type_args_fun) ; RP ; bod =  suite 
  {{typ = tip ; name = nom ; args = args ; body = bod }}
;

suite:
  | LB ; s = list(stmt) ; RB { Sblock(s) }
;

for_incr:
  | s = IDENT EQ e = expr { Sassign(s,e) }
  | s=IDENT PLUS PLUS {Sincr(s,Const(Inti 1))}

stmt:
  | e = expr SEMICOLON { Sval(e) }
  | PRINTINT LP e = expr RP SEMICOLON { Sprintint e }
  | RETURN e = expr SEMICOLON { Sreturn e }
  | typ = types TIMES* nom = IDENT SEMICOLON { Svar(typ,nom) }
  | s = IDENT EQ e = expr SEMICOLON { Sassign(s,e) }
  | TIMES e=expr EQ e2=expr SEMICOLON { Sassign_pointeur(Pointeur(e),e2)} 
  | typ = types TIMES* nom = IDENT EQ e = expr SEMICOLON { Sblock([Svar(typ,nom);Sassign(nom,e)]) }
  | IF LP e=expr RP b=suite { Sif(e,b,Sblock([])) }
  | IF LP e=expr RP b1=suite ELSE b2=suite { Sif(e,b1,b2) }
  | COM { Sblock([]) }
  | BCOM { Sblock([]) }
  | WHILE LP e=expr RP b = suite {Swhile(e,b)}
  | FOR LP def=stmt cond=expr SEMICOLON change=for_incr RP b=suite {Sfor(def,cond,change,b)}
  | s=IDENT PLUS PLUS SEMICOLON {Sincr(s,Const(Inti 1))}
;

const:
  | i = CST { Inti(i) }
;

expr:
  | c = const { Const c }
  | i = IDENT { Var(i) }
  | TIMES e=expr {Pointeur(e)} 
  | NOT e = expr %prec not { Not(e) }
  | MINUS e = expr %prec uminus { Minus(e) } 
  | e1 = expr o = op e2 = expr { Op (o, e1, e2) }
  | nom = IDENT LP args = separated_list(COMMA,expr) RP { Ecall(nom,args) }
  | ESP nom = IDENT { Esper(nom) }
  | LP e = expr RP { e }
;

%inline op:
  | PLUS  { Add }
  | MINUS { Sub }
  | TIMES { Mul }
  | DIV   { Div }
  | MOD   { Mod }
  | LEQ   { Leq }
  | GEQ   { Geq }
  | GE    { Ge  }
  | LE    { Le  }
  | NEQ   { Neq }
  | EQQ   { Eq  }
  | AND   { And }
  | OR    { Or  }
;