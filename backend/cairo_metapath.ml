module P = Point_lib
open Point_lib
open Point_lib.Infix
module S = Spline_lib

exception Not_implemented of string

let not_implemented s = raise (Not_implemented s)

let debug = false
let info = false

type point = P.point
type direction =
  | DVec of point
  | DCurl of float
  | DNo

type joint =
  | JLine
  | JCurve of direction * direction
  | JCurveNoInflex  of direction * direction
  | JTension of direction * float * float * direction
  | JControls of point * point

type knot = point

type t =
  | Start of knot
  | Cons of t * joint * knot
  | Start_Path of S.spline list
  | Append_Path of t * joint * (S.spline list)


open Format
let rec print_dir fmt = function
  |DNo -> fprintf fmt "DNo"
  |DVec p -> fprintf fmt "DVec %a" Point_lib.print p
  |DCurl f -> fprintf fmt "Dcurl %f" f
and print_knot = Point_lib.print
and print_joint fmt = function
  | JLine -> fprintf fmt "JLine"
  | JCurve _ -> fprintf fmt "JCurve"
  | JCurveNoInflex _ -> fprintf fmt "JCurveNoInflex"
  | JTension (_,f1,f2,_) -> fprintf fmt "JTension (%f,%f)" f1 f2
  | JControls (p1,p2) -> 
      fprintf fmt "JControls (%a,%a)" Point_lib.print p1 Point_lib.print p2
and print fmt = function
  | Start k1 -> fprintf fmt "[%a" print_knot k1
  | Cons (p,j,k) -> fprintf fmt "%a;%a-%a" print p print_joint j print_knot k
  | Start_Path p-> fprintf fmt "{%a}" S.print_splines p
  | Append_Path (p1,j,p2) ->
      fprintf fmt "%a;%a-%a" print p1 print_joint j S.print_splines p2


(* Metafont is wiser in the computation of 
   calc_value, calc_ff, curl_ratio, ... *)
(* dk1, uk1 are d_k-1, u_k-1 *)
let curl_ratio gamma alpha1 beta1 =
  let alpha = 1./.alpha1 in
  let beta = 1./.beta1 in
  ((3.-.alpha)*.alpha*.alpha*.gamma+.beta**3.)/.
    (alpha**3.*.gamma +. (3.-.beta)*.beta*.beta)

let reduce_angle x = 
  (* 292. define reduce angle (#) *)
  if (abs_float x) > 180. 
  then if x>0. then x -. 360. else x +. 360.
  else x

let velocity st ct sf cf t = 
  let num = 2.+.(sqrt 2.)*.(st -. (sf /. 16.))*.(sf -. (st /. 16.))*.(ct-.cf) in
  let denom = 3.*.(1.+.0.5*.((sqrt 5.) -. 1.)*.ct +. 0.5 *.(3.-.(sqrt 5.))*.cf) in
  min ((t*.num)/.denom) 4.

let calc_value dk1 dk absrtension absltension uk1 =
  (* Calculate the values aa = Ak /Bk , bb = Dk /Ck , dd = (3 - k-1 )dk,k+1 , ee = (3 - k+1 )dk-1,k , and
   cc = (Bk - uk-1 Ak )/Bk 288 *)
  let aa = 1./.(3.*.absrtension -. 1.) in
  let bb = 1./.(3.*.absltension -. 1.) in
  let dd = dk*.(3.-.1./.absrtension) in
  let ee = dk1*.(3.-.1./.absltension) in
  let cc = 1.-.(uk1*.aa) in
  (aa,bb,cc,dd,ee)
    
let calc_ff cc dd ee absrtension absltension =
  (* Calculate the ratio ff = Ck /(Ck + Bk - uk-1 Ak ) 289 *)
  (*let dd = dd*.cc in
  if absltension = absrtension 
  then ee/.(ee+.dd)
  else if absltension < absrtension
  then 
    let tmp = absltension/.absrtension in
    let tmp = tmp*.tmp in
    let dd = dd*.tmp in
    ee/.(ee+.dd)
  else
    let tmp = absrtension/.absltension in
    let tmp = tmp*.tmp in
    let ee = ee*.tmp in
    ee/.(ee+.dd)*)
  let dd = dd*.cc in
  let tmp = absltension/.absrtension in
  let tmp = tmp*.tmp in
  let dd = dd*.tmp in
  ee/.(ee+.dd)

type tension = float
    
type path_type = 
  | Endpoint
  | Explicit of point
  | Open of tension
  | Endcycle of tension
  | Curl of tension * float
  | Given of tension * float

let tension = function
  | Endpoint -> 1. (* not sure ... *)
  | Explicit _ -> assert false
  | Open t | Endcycle t | Curl (t,_) | Given (t,_) -> t

type kpath = {
  mutable left : path_type;
  mutable right : path_type;
  mutable link : kpath;
  mutable coord : point}

let print_path_type fmt = function
  | Endpoint -> fprintf fmt "Endpoint"
  | Explicit p -> fprintf fmt "Explicit %a" P.print p
  | Open t -> fprintf fmt "Open %f" t
  | Endcycle t -> fprintf fmt "Endcycle %f" t
  | Curl (t,f) -> fprintf fmt "Curl (%f,%f)" t f
  | Given (t,f) -> fprintf fmt "Given (%f,%f)" t f

let print_one_kpath fmt q =
  fprintf fmt "@[{left = @[%a@];@,coord = @[%a@];@,right = @[%a@]}@]"
        print_path_type q.left
        P.print q.coord
        print_path_type q.right

let print_kpath fmt p = 
  let rec aux fmt q =
      fprintf fmt "@[{left = @[%a@];@,coord = @[%a@];@,right = @[%a@];@,link= @[%a@]}@]"
        print_path_type q.left
        P.print q.coord
        print_path_type q.right
        (fun fmt q -> 
           if p!=q 
           then aux fmt q
           else fprintf fmt "...") q.link in
  aux fmt p

let tunity:tension = 1.

let pi = acos (-.1.)

let n_arg = 
  let coef = 180./.pi in
  fun x y -> (atan2 y x)*.coef

let sincos = 
  let coef = pi/.180. in
  fun a -> let a = coef *. a in
  sin a, cos a

let set_controls p q at af rtension ltension deltaxy =
  (* procedure set controls (p, q : pointer ; k : integer ) 299 *)
  let st,ct = sincos at in
  let sf,cf = sincos af in
  let rr = velocity st ct sf cf (abs_float rtension) in
  let ss = velocity sf cf st ct (abs_float ltension) in
  if (rtension < 0.) && (ltension < 0.) then
    (*TODO*) ();
  let sbp = (rr*/ ((ct */ deltaxy) +/ 
                               (st*/(P.swapmy deltaxy)))) in
  let sb = p.coord +/  sbp in
  p.right <- Explicit sb;
  let scm = (ss*/((cf */ deltaxy) +/ 
                              (sf*/(P.swapmx deltaxy)))) in
  let sc = q.coord -/ scm in
  q.left <- Explicit sc
  
let print_array print fmt =
  Array.iter (fun e -> fprintf fmt "%a;@," print e)

let print_float fmt = fprintf fmt "%f"

let solve_choices p q n deltaxyk deltak psik =
  (* If Only one simple arc*)
  match p with
    | {right = Given (rt,rp);link={left=Given (lt,lq)}} -> 
        (* Reduce to simple case of two givens and return 301 *)
        let aa = n_arg deltaxyk.(0).x deltaxyk.(0).y in
        let at = rp -. aa in let af = lq -. aa in
        set_controls p q at af rt lt deltaxyk.(0)
    | {right = Curl (tp,cp);link={left=Curl (tq,cq)}} -> 
        (* Reduce to simple case of straight line and return 302 *)
        let lt = abs_float tq in let rt = abs_float tp in
        let tmp = 
          {x=if deltaxyk.(0).x >= 0. then 1. else -.1.;
           y=if deltaxyk.(0).y >= 0. then 1. else -.1.} in
        p.right <- Explicit  
          begin
            if rt = tunity then 
              p.coord +/ ((deltaxyk.(0) +/ tmp)// 3.)
            else
              let ff = 1. /. (3. *. rt) in
              p.coord +/ (deltaxyk.(0) // ff)
          end;
        q.left <- Explicit  
          begin
            if lt = tunity then 
              q.coord +/ ((deltaxyk.(0) +/ tmp)// 3.)
            else
              let ff = 1. /. (3. *. rt) in
              q.coord +/ (deltaxyk.(0) // ff)
          end
    | {link=t} as s -> 
        let thetak = Array.make (n+2) 0. in
        let uu = Array.make (n+1) 0. in
        let vv = Array.make (n+1) 0. in
        let ww = Array.make (n+1) 0. in
        begin
          if debug then
            Format.printf "Open : @[k : @[%i@];@,s : @[%a@]@]@." 0 print_one_kpath p;
          match p with
            |{right=Given (_,rp)} ->
               (* Set up the equation for a given value of 0 293 *)
               vv.(0) <- reduce_angle (rp -. (n_arg deltaxyk.(0).x deltaxyk.(0).y));
                uu.(0) <- 0.;ww.(0) <- 0.
            |{right=Curl (tp,cc);link={left=lt}} ->
               (* Set up the equation for a curl at 0 294 *)
               let lt = abs_float (tension lt) in let rt = abs_float tp in
               if lt = tunity && rt = tunity 
               then uu.(0) <- (2.*.cc+.1.)/.(cc+.2.)
               else uu.(0) <- curl_ratio cc rt lt;
               vv.(0) <- -. (psik.(1)*.uu.(0));
               ww.(0) <- 0.
            |{right=Open _} ->
               uu.(0) <- 0.;vv.(0) <- 0.;ww.(0) <- 1.
            | _ -> assert false (* { there are no other cases } in 285 because of 273 *)
        end;
        (let rec aux k r = function
            (* last point*)
          | {left=Curl (t,cc)} -> 
              (* Set up equation for a curl at n and goto found 295 *)
              let lt = abs_float t in
              let rt = abs_float (tension r.right) in
              let ff = if lt=1. && rt=1. 
              then (2.*.cc+.1.)/.(cc+.2.)
              else curl_ratio cc lt rt in
              thetak.(n) <- -.((vv.(n-1)*.ff)/.(1.-.ff*.uu.(n-1)))
          | {left=Given (_,f)} -> 
              (* Calculate the given value of n and goto found 292 *)
              thetak.(n) <- reduce_angle (f -. (n_arg deltaxyk.(n-1).x deltaxyk.(n-1).y))
          | {link=t} as s-> 
                (*end cycle , open : Set up equation to match mock curvatures at zk ;
                  then goto found with n adjusted to equal 0 , if a cycle has ended 287 *)
              if debug then
                Format.printf "Open : @[k : @[%i@];@,s : @[%a@]@]@." k print_one_kpath s;
              let absrtension = abs_float (tension r.right) in
              let absltension = abs_float (tension t.left) in
              let (aa,bb,cc,dd,ee) = calc_value deltak.(k-1) deltak.(k) 
                absrtension absltension uu.(k-1) in
              let ff = calc_ff cc dd ee absrtension absltension in
              uu.(k)<- ff*.bb;
              (* Calculate the values of vk and wk 290 *)
              let acc = -. (psik.(k+1)*.uu.(k)) in
              (match r.right with 
                | Curl _ -> (*k=1...*) ww.(k) <- 0.; 
                    vv.(k) <- acc -. (psik.(1) *. (1. -. ff))
                | _ -> 
                    let ff = (1. -. ff)/. cc in
                    let acc = acc -. (psik.(k) *. ff) in
                    let ff = ff*.aa in
                    vv.(k) <- acc -. (vv.(k-1)*.ff);
                    ww.(k) <- -. (ww.(k-1)*.ff));
              (match s.left with
                 | Endcycle _ -> 
                     (* Adjust n to equal 0 and goto found 291 *)
                     let aa,bb = 
                       (let rec aux aa bb = function
                          | 0 -> (vv.(n) -. (aa*.uu.(n))),(ww.(n) -. (bb*.uu.(n)))
                          | k -> aux (vv.(k) -. (aa*.uu.(k))) (ww.(k) -. (bb*.uu.(k))) (k-1) in
                        aux 0. 1. (n-1)) in
                     let aa = aa /. (1. -. bb) in
                     thetak.(n) <- aa;
                     vv.(0) <- aa;
                     for k = 1 to n-1 do
                       vv.(k) <- vv.(k) +. (aa*.ww.(k));
                     done;
                 | _ -> aux (k+1) s t);
         in aux 1 s t);
        (* Finish choosing angles and assigning control points 297 *)
        if debug then
          Format.printf "Finish choosing angles and assigning control points 297@.";
        for k = n-1 downto 0 do
          thetak.(k) <- vv.(k) -. (thetak.(k+1) *. uu.(k))
        done;
        (*Format.printf "thetak : %a@." (print_array print_float) thetak;
        Format.printf "uu : %a@." (print_array print_float) uu;
        Format.printf "vv : %a@." (print_array print_float) vv;
        Format.printf "ww : %a@." (print_array print_float) ww;*)
        (let rec aux k = function
           | _ when k = n -> ()
           | {right=rt;link={left=lt} as t} as s ->
               let at = thetak.(k) in
               let af = -.psik.(k+1) -. thetak.(k+1) in
               (*Format.printf "Set_controls before : @[%a ." print_one_kpath s;*)
               set_controls s t at af (tension rt) (tension lt) deltaxyk.(k);
               (*Format.printf "Set_controls after : @[%a@]@." print_one_kpath s;*)
               aux (k+1) t
         in aux 0 p)

let make_choices knots =
  (* If consecutive knots are equal, join them explicitly 271*)
  (let p = ref knots in
  while !p != knots do
    (match !p with
      | ({coord=coord;right=(Given _|Curl _|Open _);link=q} as k) when coord == q.coord ->
          if debug then
            Format.printf "@[find consecutive knots :k = @[%a@];@,q = @[%a@]@]@."
              print_one_kpath k print_one_kpath q;
          k.right <- Explicit coord;
          q.left  <- Explicit coord;
          (match k.left with
            | Open tension -> k.left <- Curl (tension,tunity)
            | _ -> ());
          (match k.right with
            | Open tension -> k.right <- Curl (tension,tunity)
            | _ -> ());
      | _ -> ());
    p:=(!p).link;
  done);
  (*Find the first breakpoint, h, on the path; insert an artificial breakpoint if the path is an unbroken
    cycle 272*)
  let h = 
    (let rec aux = function
       | {left = (Endpoint | Endcycle _ | Explicit _ | Curl _ | Given _)}
       | {right= (Endpoint | Endcycle _ | Explicit _ | Curl _ | Given _)} as h -> h
       | {left = Open t} as h when h==knots -> knots.left <- Endcycle t; knots
       | {link=h} -> aux h in
     aux knots) in
  if debug then 
    Format.printf "@[find h :h = @[%a@]@]@."
      print_one_kpath h;
  (*repeat Fill in the control points between p and the next breakpoint, then advance p to that
    breakpoint 273
    until p = h*)
(let rec aux = function
   | {right =(Endpoint|Explicit _);link = q} -> if q!=h then aux q
   | p -> let n,q = 
       (let rec search_q n = function
          |{left=Open _;right=Open _;link=q} -> search_q (n+1) q
          | q -> (n,q) in
        search_q 1 p.link) in
     if debug then
       Format.printf "@[search_q : n = %i;@,p = @[%a@];@,q = @[%a@]@]@."
         n print_one_kpath p print_one_kpath q;
     (*Fill in the control information between consecutive breakpoints p and q 278*)
     (*  Calculate the turning angles k and the distances dk,k+1 ; set n to the length of the path 281*)
     let deltaxyk = Array.make (n+1) P.zero in
     (* Un chemin sans cycle demande un tableau de taille n, de n+1 avec cycle *)
     let deltak = Array.make (n+1) 0. in
     let psik = Array.make (n+2) 0. in
     (let rec fill_array k = function
          (* K. utilise des inégalitées pour k=n et k = n+1 -> k>=n*)
        | s when k = n && (match s.left with |Endcycle _ -> false | _ -> true) -> psik.(n) <- 0. 
            (* On a fait un tour le s.left précédent était un Endcycle *) 
        | _ when k = n+1 -> psik.(n+1)<-psik.(1) 
        | {link=t} as s ->
            deltaxyk.(k) <- t.coord -/ s.coord;
            deltak.(k) <- P.norm deltaxyk.(k);
            (if k > 0 then
               let {x=cosine;y=sine} = deltaxyk.(k-1) // deltak.(k-1) in
               let psi = n_arg (deltaxyk.(k).x*.cosine+.deltaxyk.(k).y*.sine)
                 (deltaxyk.(k).y*.cosine-.deltaxyk.(k).x*.sine) in
               psik.(k) <- psi);
            fill_array (k+1) t
      in fill_array 0 p);
     (*Format.printf "deltaxyk : %a@." (print_array P.print) deltaxyk;
     Format.printf "deltak : %a@." (print_array print_float) deltak;
     Format.printf "psik : %a@." (print_array print_float) psik;*)
     (*Remove open types at the breakpoints 282*)
     (match q with
       | {left=Open t} -> q.left <- Curl (t,1.) (* TODO cas bizarre *)
       | _ -> ());
     (match p with
        | {left=Explicit pe;right=Open t} -> 
           let del = p.coord -/ pe in
           if del=P.zero 
           then p.right <- Curl (t,1.)
           else p.right <- Given (t,n_arg del.x del.y)
        | _ -> ());
     (* an auxiliary function *)
       solve_choices p q n deltaxyk deltak psik;
     if q!=h then aux q
 in aux h)
      
let tension_of = function
  | JTension (_,t1,t2,_) -> (t1,t2)
  | _ -> (1.,1.)
      
let direction t = function
  | DNo -> Open t
  | DVec p -> Given (t,n_arg p.x p.y)
  | DCurl f -> Curl (t,f)
      
let right_of_join p = function
  | JLine -> Explicit p
  | JControls (c,_) -> Explicit c
  | JCurve (d,_) -> direction 1. d
  | JCurveNoInflex (d,_) -> direction 1. d (*pas totalement correcte*)
  | JTension (d,f,_,_) -> direction f d
      
let left_of_join p = function
  | JLine -> Explicit p
  | JControls (_,c) -> Explicit c
  | JCurve (_,d) -> direction 1. d
  | JCurveNoInflex (_,d) -> direction 1. d (*pas totalement correcte*)
  | JTension (_,_,f,d) -> direction f d

let dumb_pos = {x=666.;y=42.}
let dumb_dir = Endcycle 42.

let rec dumb_link = { left = dumb_dir;
                     right = dumb_dir;
                     coord = dumb_pos;
                     link = dumb_link}

let path_to_meta nknot l =
  let rec aux aknot = function
  | [] -> assert false
  | [{S.sa=sa;sb=sb;sc=sc;sd=sd}] ->
      nknot.left <- Explicit sc;
      nknot.coord <- sd;
      aknot.link <- nknot ;
      aknot.right <- Explicit sb;
      aknot.coord <- sa; ()
  | {S.sa=sa;sb=sb;sc=sc}::l -> 
      let nknot = {left = Explicit sc;
                   right = dumb_dir;
                   coord = dumb_pos;
                   link = dumb_link} in
      aknot.link <- nknot;
      aknot.right <- Explicit sb;
      aknot.coord <- sa;
      aux nknot l in
  let aknot = {left = Endpoint;
       right = dumb_dir;
       coord = dumb_pos;
       link = dumb_link} in
  aux aknot l;
  aknot
                   
 let kmeta_to_path ?cycle meta = 
   let rec to_knots aknot = function
     | Start p -> 
         aknot.coord <- p;
         aknot.left <- Endpoint;
         aknot
     | Cons (pa,join,p) ->
         aknot.coord <- p;
         aknot.left <- left_of_join p join;
         let nknot = {right = right_of_join p join;
                      left = dumb_dir;
                      coord = dumb_pos;
                      link = aknot} in
         to_knots nknot pa
     | Start_Path pa -> path_to_meta aknot pa
     | Append_Path (p1,join,p2) -> 
         let aknot2 = path_to_meta aknot p2 in 
         aknot2.left<- left_of_join aknot2.coord join;
         let nknot = {right = right_of_join aknot2.coord join;
                      left = dumb_dir;
                      coord = dumb_pos;
                      link = aknot} in
         to_knots nknot p1 in
   let lknots = {right = Endpoint;
                 left = dumb_dir;
                 coord = dumb_pos;
                 link = dumb_link} in
   let knots = to_knots lknots meta in
   lknots.link <- knots;
   (* Choose control points for the path and put the result into cur exp 891 *)
   (* when nocycle *)
   begin
     match cycle with
       |Some join -> 
          begin
            lknots.right <- right_of_join knots.coord join;
            knots.left <- left_of_join knots.coord join;
          end
       | None ->
           begin 
             (match knots.right with
                | Open t -> knots.right <- Curl (t,1.)
                | _ -> ());
             (match lknots.left with
                | Open t -> lknots.left <- Curl (t,1.)
                | _ -> ());
           end
   end;
   if debug then
     Format.printf "@[before : @[%a@];@.middle : @[%a@]@]@." print meta print_kpath knots;
   make_choices knots;
   if debug then
     Format.printf "@[after : @[%a@]@]@." print_kpath knots;
   let rec aux smin = function
   | {right = Endpoint} -> []
   | {right = Explicit sb;coord = sa;
      link={left = Explicit sc;coord = sd} as s} ->
       {S.sa = sa;sb = sb;sc = sc;sd = sd;
        smin=smin;smax=smin+.1.;start=false}::
         (if s==knots then [] else (aux (smin+.1.) s))
   | _ -> assert false in
    let l = aux 0. knots in
    {(List.hd l) with S.start = true}::(List.tl l)

let kto_path ?cycle = function
 | Start p -> S.Point p
 | mp -> 
     let res = S.Path { S.pl = kmeta_to_path ?cycle mp; cycle = cycle <> None} in
     if info then
       Format.printf "@[end : @[%a@]@]@." S.printf res;
     res

let rec to_path_simple = function
  | Start p -> S.create_line p p
  | Cons (pa,JLine,p) -> S.add_end_line (to_path_simple pa) p
  | Cons (pa,JControls(c1,c2),p) -> S.add_end_spline (to_path_simple pa) c1 c2 p
  | Start_Path p -> S.Path {S.pl=p;cycle=false}
  | Append_Path (p1,JControls(c1,c2),p2) -> 
      S.append (to_path_simple p1) c1 c2 (S.Path {S.pl=p2;cycle=false})
  | (Cons(pa,JCurve _,p)) -> S.add_end_line (to_path_simple pa) p (* Faux*)
  |p -> Format.printf "not implemented %a@." print p; not_implemented "to_path"

let knot p = p
  
let vec_direction p = DVec p
let curl_direction f = DCurl f
let no_direction = DNo

let start k = Start k
  
let line_joint = JLine
let curve_joint dir1 dir2 = JCurve(dir1,dir2)
let curve_no_inflex_joint dir1 dir2 = JCurveNoInflex(dir1,dir2)
let tension_joint dir1 f1 f2 dir2 = JTension (dir1,f1,f2,dir2)
let controls_joint p1 p2 = JControls (p1,p2)
  

let concat p j k = Cons (p,j,k)
let rec append p j = function
  | Start knot -> Cons (p,j,knot)
  | Cons(p2,j2,k2) -> Cons(append p j p2,j2,k2)
  | Start_Path p2 -> Append_Path(p,j,p2)
  | Append_Path (p2,j2,p3) -> Append_Path(append p j p2,j2,p3)

let to_path p = kto_path p
let cycle j p = kto_path ~cycle:j p

let from_path = function
  | S.Path p -> Start_Path p.S.pl
  | S.Point p -> Start p

module Approx =
struct
let lineto = S.create_lines
let simple_join = curve_joint no_direction no_direction
let curve l = 
  let rec aux = function
  | [] -> assert false
  | [a] -> start (knot a)
  | a::l -> concat (aux l) simple_join (knot a) in
  aux (List.rev l)
let fullcircle_ l = 
  let l2 = l/.2. in 
  cycle simple_join 
    (curve [{x=l2;y=0.};{x=0.;y=l2};{x= -.l2;y=0.};{x=0.;y= -.l2}])

let fullcircle1 = lazy (fullcircle_ 1.)
let fullcircle = function
  | 1. -> Lazy.force fullcircle1
  | l  -> fullcircle_ l

let halfcirle l = 
  (* 2. because fullcircle is defined with 4 points *)
  S.subpath (fullcircle l) 0. 2. 

let quartercircle l = S.subpath (fullcircle l) 0. 1.
let unitsquare l = 
  let p = {x=0.;y=0.} in
  (S.close (S.create_lines [p;{x=l;y=0.};{x=l;y=l};{x=0.;y=l};p]))
end

module ToCairo =
struct
  type pen = Matrix.t

  let draw_path cr = function
    | S.Path p ->
       List.iter (function 
                    | {S.start = true} as s -> 
                        Cairo.move_to cr s.S.sa.x s.S.sa.y ;
                        Cairo.curve_to cr 
                          s.S.sb.x s.S.sb.y 
                          s.S.sc.x s.S.sc.y 
                          s.S.sd.x s.S.sd.y
                    | s -> 
                        Cairo.curve_to cr 
                          s.S.sb.x s.S.sb.y 
                          s.S.sc.x s.S.sc.y 
                          s.S.sd.x s.S.sd.y) p.S.pl;
        if p.S.cycle then Cairo.close_path cr
    | S.Point _ -> failwith "Metapost fail in that case what should I do???"

  let stroke cr ?(pen=Matrix.identity) = function
    | S.Path _ as path -> 
        draw_path cr path;
        Cairo.save cr;
        (*Matrix.set*) Matrix.transform cr pen;
        Cairo.stroke cr;
        Cairo.restore cr;
    | S.Point p ->
        Cairo.save cr;
        Matrix.transform cr (Matrix.translation p);
        Matrix.transform cr pen;
        draw_path cr (Approx.fullcircle 1.);
        Cairo.fill cr;
        Cairo.restore cr

  let fill cr path = draw_path cr path; Cairo.fill cr
end