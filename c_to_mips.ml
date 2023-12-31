open Ast_c
open Ast_mips



let associe_binop op = match op with
  |Mul -> Mulm
  |Sub -> Subm
  |Add -> Addm
  | _ -> failwith "Pas une operation autorisee" (* Ce cas ne devrait pas arriver *)


let init_cpt = let cpt = ref 0 in cpt
let fresh_label (str:string) =
  init_cpt := !init_cpt + 1;
  str^"_"^(string_of_int (!init_cpt))

let converti program = (*On stocke le resultat des instructions dans A(0)*)
  
  let rec eval_binop op e1 e2 off_set var_locales= match op,e1,e2 with

    (*On separe les cas ou on additionne une constante*)
    |Add,Const(Inti(i)),e | Add,e,Const(Inti(i)) 
     -> (eval_expr e off_set var_locales)@[Sbinopi(Addi,A(0),A(0),Intm(i))]
     
    |Sub,e,Const(Inti (i)) -> (eval_expr e off_set var_locales)@[Sbinopi(Addi,A(0),A(0),Intm(-i))]


    |Mul,_,_|Sub,_,_|Add,_,_ -> (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));Sbinop(associe_binop op,A(0),T(0),A(0))]

    |Div,_,_ -> (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));Smonop(Divm,T(0),A(0));Smonop(Smf,A(0),Lo)]

    |Mod,_,_ -> (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));Smonop(Divm,T(0),A(0));Smonop(Smf,A(0),Hi)]

    |_ -> eval_comparaison op e1 e2 off_set var_locales

  and eval_comparaison op e1 e2 off_set var_locales = match op with
    |Eq -> 
      (*evaluations des expressions*)
      (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));

      Sbinop(Slt,T(1),T(0),A(0)); (* e1 < e2 *)
      Sbinop(Slt,A(0),A(0),T(0)); (* e2 < e1*)
      Sbinop(Addm,A(0),T(1),A(0)); (* A(0) = 0 lorsque les deux conditions sont fausse*)
      Smonopi(Li,T(0),Intm(1)); Sbinop(Slt,A(0),A(0),T(0))]  (* A(0) < 1 *)

    |Neq ->  (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));
      
      Sbinop(Subm,A(0),T(0),A(0))] (* e2-e1 *)
    
    |Leq -> 
      (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));

      Sbinopi(Addi,A(0),A(0),Intm(1)); (* e2' = e2+1*)
      Sbinop(Slt,A(0),T(0),A(0))] (* e1 < e2' <=> e1 <= e2*)
    
    |Le ->     
      (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));

      Sbinop(Slt,A(0),T(0),A(0))] (* e1 < e2*)
    
    |Geq -> eval_comparaison Leq e2 e1 off_set var_locales (* e1 >= e2 est la meme chose que e2 <=e1 *)
    |Ge -> eval_comparaison Le e2 e1 off_set var_locales
    
    |Or -> 
      (eval_expr e1 off_set var_locales)
      @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
      @(eval_expr e2 (off_set+1) var_locales)
      @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));
      
      Sbinop(Or,A(0),A(0),T(0))]

    |And -> 
        (eval_expr e1 off_set var_locales)
        @[Sbinopi(Sw,A(0),Sp,Intm(-4*off_set))]
        @(eval_expr e2 (off_set+1) var_locales)
        @[Sbinopi(Lw,T(0),Sp,Intm(-4*off_set));
        
        Sbinop(And,A(0),A(0),T(0))]
    |_->failwith "pas un operateur binaire" (* Ce cas ne devrait pas arriver *)


    and eval_expr e off_set var_locales = match e with
    |Minus(expr) -> eval_binop Sub (Const(Inti 0)) expr off_set var_locales (*0 - expr*)

    |Const(Inti(i)) -> [Smonopi(Li,A(0),Intm(i))]

    |Op(b,e1,e2) -> eval_binop b e1 e2 off_set var_locales

    |Ecall(f,l) -> (* Lors de l'appel de fonction, on deplace Sp a la fin de la pile, et on met a l'indice 0 ra, et aux indices suivants les valeurs des arguments de la fonction*)
      
      let assigne_les_variables = List.concat (List.mapi 
        (fun i arg ->
          (eval_expr arg (off_set+i+1) var_locales)@[Sbinopi(Sw,A(0),Sp,Intm(-4*(off_set+i+1)))]) l) in

      (* On stocke les valeurs des variables*)
      assigne_les_variables
      (* On met Sp a la fin de la pile*)
      @[Sbinopi(Addi,Sp,Sp,Intm(-4*(off_set)))
      ;Sbinopi(Addi,T(2),T(2),Intm(off_set))]
      (* On effectue la fonction *)
      @[Sjump(Jal(f));
      (* On reprend l'ancien etat de la pile*)
      Sbinopi(Addi,Sp,Sp,Intm(4*(off_set)));Sbinopi(Addi,T(2),T(2),Intm(-off_set))]

    |Const(Null) -> []
    
    |Var(s) -> 
      (match Hashtbl.find_opt var_locales s with
        |Some(Intm(n)) -> [Sbinopi(Lw,A(0),Sp,Intm(n))] 
        |_ -> print_string ("variable "^s^" non definie\n");
        failwith "undefined")

    |Esper(s)->(match Hashtbl.find_opt var_locales s with
      |Some(Intm(n)) -> [Sbinopi(Addi,A(0),T(2),Intm(n/(-4)))] (*on met l'adresse relative à Sp: n/(-4) plus l'adresse de Sp pour obtenir une adresse générale*)
      |_ -> print_string ("variable "^s^" non definie\n");
      failwith "undefined")

    |Pointeur(p)->(accede_pointeur (Pointeur(p)) var_locales)@(*on met Sp sur l'adresse pointée*)
                  [Sbinopi(Lw,A(0),Sp,Intm(0));Smonop(Move,Sp,T(4))] (*on renvoie le contenu de l'adresse pointée et on remet Sp a sa valeur initiale*)
    
    |Not (e) -> eval_comparaison Eq e (Const(Inti 0)) off_set var_locales  (*e==0*)

    and eval_stmt ?(main=false) ?(off_set_local = ref 0) var_locales stmt off_set = match stmt with
                      (*off_set_local correspond aux nombre de variables locales*)
    |Sblock(l) ->  
      List.fold_left 
        (fun instr s-> 
          instr@(eval_stmt ~main:main ~off_set_local:off_set_local var_locales s (off_set))) 
        [] l (* Le list.fold_left est equivalent a un List.concat List.map*)

    |Sval(e) -> eval_expr e (off_set+ !off_set_local) var_locales

    |Svar(_,s) -> incr off_set_local;
      Hashtbl.add var_locales s (Intm(-4*(!off_set_local + off_set -1)));
      []
    
    |Sassign(var,e) when Hashtbl.mem var_locales var -> let e_eval = eval_expr e (off_set+ !off_set_local) var_locales in
      e_eval@[Sbinopi(Sw,A(0),Sp,Hashtbl.find var_locales var)]

    |Sassign(var,_) -> print_string ("variable "^var^" non definie\n");
      failwith "undefined"

    |Sprintint(e) -> 
      (eval_expr e (off_set+ !off_set_local) var_locales) (*Evalue l'expression*)
      @ [Smonopi(Li,V0,Intm(1));Ssyscall; (*Print l'expression*)
      Smonopi(Li,A(0),Intm(10));Smonopi(Li,V0,Intm(11));Ssyscall] (*retour a la ligne*)

    |Sreturn(e) when main = true -> (eval_expr e (off_set+ !off_set_local) var_locales)@[Smonopi(Li,V0,Intm(10));Ssyscall]

    |Sreturn(e) -> (eval_expr e (off_set+ !off_set_local) var_locales)@[Sbinopi(Lw,Ra,Sp,Intm(0));Sjump(Jr(Ra))]

    |Sif(cond,stmt_if,stmt_else) -> (
      let cond_eval = eval_expr cond off_set var_locales in
      let eval_if = eval_stmt ~main:main ~off_set_local:off_set_local var_locales stmt_if off_set in
      let eval_else = eval_stmt ~main:main ~off_set_local:off_set_local var_locales stmt_else off_set in
      let then_label = fresh_label "then" in
      let else_label = fresh_label "else" in
      let endif_label = fresh_label "endif" in
      
      (*Evaluation*)
      cond_eval @
      (*On teste si A0 = 0 *)
      [Scond(Beq,A(0),Zero,else_label)] @
      (*Si la condition est vérifiée*)
      [Slabel(then_label)] @ eval_if @ [Sjump(J(endif_label))] @
      (*Sinon*)
      [Slabel(else_label)] @ eval_else @
      (*Sortie du If*)
      [Slabel(endif_label)])
    
    |Swhile(cond,stmt) -> (
      let cond_eval = eval_expr cond off_set var_locales in
      let stmt_eval = eval_stmt ~main:main ~off_set_local:off_set_local var_locales stmt off_set in
      let loop_label = fresh_label "loop" in
      let endloop_label = fresh_label "endloop" in

      [Slabel(loop_label)] @ cond_eval @ [Scond(Beq,A(0),Zero,endloop_label)] @
      stmt_eval @
      [Sjump(J(loop_label)) ; Slabel(endloop_label)]
    )

    |Sfor(def,cond,change,stmt) -> (
      let def_eval = eval_stmt ~main:main ~off_set_local:off_set_local var_locales def off_set in
      let body = Sblock([stmt;change]) in
      let body_eval = eval_stmt ~main:main ~off_set_local:off_set_local var_locales (Swhile(cond,body)) off_set in
      def_eval @  body_eval
    )

    |Sassign_pointeur(e1,e2)-> let deplace_Sp=accede_pointeur e1 var_locales in
                                eval_expr e2 (off_set+ !off_set_local) var_locales @
                                deplace_Sp@
                                [Sbinopi(Sw,A(0),Sp,Intm(0));Smonop(Move,Sp,T(4))] (*mise du resultat dans l'emplacement pointé et réinitialistaion de $sp*)
    
    |Sincr(s,Const(Inti(1))) -> let expr = Op(Add,(Var s),(Const (Inti 1))) in (eval_stmt var_locales (Sassign(s,expr)) off_set)
    | _ -> assert false;

      
    (*|_ -> print_string "Pas codee eval_stmt"; failwith "Pascodee "*)

  (*place Sp sur l'emplacement pointé et sauvegarde le Sp original dans $t4 
     registres utilisés: $t3:adresse suivante pour le déplacement de Sp
                         $t4:sauvegarde de Sp
                         $t5: -4
                         $fp: debut de la stack   *)
  and accede_pointeur point var_locales=match point with
    |Pointeur(e1)->let avant=accede_pointeur e1 var_locales in
                      avant@[ Sbinopi(Lw,T(3),Sp,Intm(0));(*recuperation de la prochaine adresse*)
                              Sbinop(Mulm,T(3),T(3),T(5));(*mise en forme de l'adresse ($t5 = -4)*)
                              Sbinop(Addm,Sp,Fp,T(3));] (*deplacement de Sp*)
    |Var(s) when Hashtbl.mem var_locales s ->let adr=Hashtbl.find var_locales s in [Sbinopi(Addi,T(5),Zero,Intm(-4));
                                                                                    Sbinop(Mulm,T(3),T(5),T(2));
                                                                                    Sbinopi(Addi,T(3),T(3),adr);
                                                                                    Smonop(Move,T(4),Sp);Sbinop(Addm,Sp,Fp,T(3))] (*sauvegarde de Sp puis déplacement de Sp sur la variable pointée*)                                                                         
    |Var(s)->failwith ("variable "^s^" non definie")
    |_->failwith("ceci n'est pas un pointeur") 


  in 
    List.fold_left 
    (fun instr fonction ->
      (* On ajoute les arguments de la fonction dans le contexte*)
      let variables_locales  = Hashtbl.create 100 in
      List.iteri (fun i (Args(_,arg)) -> Hashtbl.add variables_locales arg (Intm(-4*(i+1)))) fonction.args;
      let corps_de_la_fonction = eval_stmt ~main:(fonction.name="main") variables_locales fonction.body (1+(List.length fonction.args)) in 
      (* L'argument main est à true lorsque la fonction etudiee est main, et donc ajoute a la fin de la fonction un syscall pour exit*)
      (* Les premiers elements de la pile sont occupes par les arguments et ra*)

      (* On retire les variables locales du contexte*)

      if fonction.name <> "main" (*Si la fonction n'est pas main, on rajoute un jump pour revenir a l'endroit ou a ete appele la fonction*)
      then 
        instr
        @[Slabel(fonction.name);Sbinopi(Sw,Ra,Sp,Intm(0))]
        @corps_de_la_fonction@[Sbinopi(Lw,Ra,Sp,Intm(0));Sjump(Jr(Ra))]  
      else 
        instr
        @[Slabel("main")]
        @corps_de_la_fonction)

    [] program.defs (* Le list.fold_left est equivalent a un List.concat List.map*)