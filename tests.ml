(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) Johannes Kanig, Stephane Lescuyer                       *)
(*  and Jean-Christophe Filliatre                                         *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2, with the special exception on linking              *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Mlpost
open Num
open Command
open Format
open Helpers
open Point
open Path
module T = Transform

let (++) x y = p (cm x, cm y)
let shift x y = transform [Transform.shifted (x ++ y)]

let d1 = 
  let a = Box.circle (0. ++ 0.) (Picture.tex "$\\sqrt2$") in
  let b = Box.rect (2. ++ 0.) (Picture.tex "$\\pi$") in
  let pen = Pen.default ~tr:[Transform.scaled 3.] () in
  [ draw_box a;
    draw_box ~fill:Color.purple b;
    draw
      ~color:Color.red
      (transform [Transform.shifted (1. ++ 1.)] (bpath a));
    draw_label_arrow ~color:Color.orange ~pen 
      ~pos:Pupright (Picture.tex "foo") (Box.west a) (Box.south_east b);
    box_arrow ~color:Color.blue a b;
  ]

open Tree

let () = Random.self_init ()

let rec random_tree = function
  | 1 -> 
      leaf "1"
  | 2 -> 
(*       node ~style:Rect ~fill:(Color.cmyk 1. 0.5 0.3 0.2) "2" [leaf "1"] *)
      node ~style:Rect ~fill:(Color.rgb 0.5 0.3 0.2) "2" [leaf "1"]
(*
  | n when Random.bool () -> 
      node (string_of_int n) [random_tree (n-1)]
*)
  | n -> 
      let k = 1 + Random.int (n - 2) in
      node (string_of_int n) [random_tree k; random_tree (n - 1 - k)]

let d2c, d2s, d2sq, d2hsq = 
  let tree = random_tree 17 in
  [draw ~ls:(-1.0) 
       ~node_style:Circle ~arrow_style:Directed ~edge_style:Curve
       ~fill:Color.yellow ~stroke:Color.blue ~pen:(Pen.circle ()) tree],
  [draw ~ls:(-1.0) 
       ~node_style:Circle ~arrow_style:Directed ~edge_style:Straight
       ~fill:Color.yellow ~stroke:Color.blue ~pen:(Pen.circle ()) tree],
  [draw ~ls:(-1.0)
       ~node_style:Circle ~arrow_style:Directed ~edge_style:Square
       ~fill:Color.yellow ~stroke:Color.blue ~pen:(Pen.circle ()) tree],
  [draw ~ls:(-1.0)
       ~node_style:Circle ~arrow_style:Directed ~edge_style:HalfSquare
       ~fill:Color.yellow ~stroke:Color.blue ~pen:(Pen.circle ()) tree]

let proval =
  let f = 7. in
  let pen = Pen.square ~tr:[T.yscaled 0.5; T.rotated 40.] () in
  let check = jointpath [-1.2,1.2; 0., -2. ; 2., 2. ; 5., 5.] [JLine ; JCurve; JCurve] in
    [ fill ~color:(Color.gray 0.2)
        (transform [Transform.scaled f] fullcircle) ;
      label ~pos:Pleft (Picture.tex "Pr") (Point.p (f /. (-4.),0.)) ;
      label ~pos:Pright (Picture.tex "al") (Point.p (f /. 4.,0.)) ;
      Command.draw ~color:Color.green ~pen check;]

let cheno011 =
  let p = path ~cycle:JCurve [(0.,0.); (30.,40.); (40.,-20.); (10.,20.)] in
  let pen = Pen.circle ~tr:[T.scaled 1.5] () in
  [Command.draw p;
   seq (List.map
	   (fun (pos, l, i) -> 
	     Command.dotlabel ~pos (Picture.tex l) (point i p))
	   [Pbot, "0", 0.;  Pupleft, "1", 1. ;
	    Plowleft, "2", 2. ;  Ptop, "3", 3. ; Pleft, "4", 4. ]);
   Command.draw ~pen (subpath 1.3 3.2 p)]

open Dash

let d3 =
  let p = pathp [cmp (0., 0.); cmp (5., 0.)] in
  let pat = pattern [On (bp 6.); Off (bp 12.); On (bp 6.)] in
  [Command.draw p ~dashed:pat]


let pic = Picture.make (seq cheno011)

let d4 = 
  [draw_pic pic;
   iter 1 5 
     (fun i -> 
	draw_pic (Picture.transform [T.rotated (10. *. float i)] pic))
  ]

let d5 = 
  let t1 = random_tree 5 in
  let pic1 = Picture.make (Tree.draw t1) in
  let b1 = Box.rect (cmp (0.,0.)) pic1 in
  let t2 = random_tree 6 in
  let pic2 = Picture.make (Tree.draw t2) in
  let b2 = Box.rect (cmp (4.,0.)) pic2 in
  [ draw_box b1;
    draw_box b2;
    box_arrow b1 b2 ]

let d7 =
  let pic = 
    Picture.transform [T.scaled 4.] (Picture.tex "bound this!") in
  let pbox = pathp ~style:JLine ~cycle:JLine
    [Picture.ulcorner pic; Picture.urcorner pic; 
     Picture.lrcorner pic; Picture.llcorner pic] in
    [Command.draw_pic pic;
     Command.draw (Picture.bbox pic);
     Command.draw pbox;
     Command.dotlabel ~pos:Pleft (Picture.tex "ulcorner") (Picture.ulcorner pic);
     Command.dotlabel ~pos:Pleft (Picture.tex "llcorner") (Picture.llcorner pic);
     Command.dotlabel ~pos:Pright (Picture.tex "urcorner") (Picture.urcorner pic);
     Command.dotlabel ~pos:Pright (Picture.tex "lrcorner") (Picture.lrcorner pic);
    ]
    
open Tree.Pic

let tree1 () = Picture.make (Tree.draw (random_tree (1 + Random.int 5)))

let rec random_tree2 = function
  | 1 -> 
      leaf (tree1 ())
  | 2 -> 
      node (tree1 ()) [leaf (tree1 ())]
  | n -> 
      let k = 1 + Random.int (n - 2) in
      node (tree1 ()) [random_tree2 k; random_tree2 (n - 1 - k)]

let d6 =
  [Tree.draw ~scale:(Scale.cm 3.) ~cs:(mm 0.2) (random_tree2 10)]

let half pic = Picture.transform [Transform.scaled 0.5] pic

let rec right_split n pic = 
  if n <= 0 then pic
  else
    let smaller = right_split (n-1) (half pic) in
      Picture.beside pic (Picture.below smaller smaller)

let d11 =
  let p1 = Picture.transform [Transform.rotated 90.] (Picture.tex "recursion") in
    [Command.draw_pic (right_split 5 p1)]

let rec sierpinski p n =
  if n = 0 then p else
    let sp = sierpinski p (n-1) in
    let p = half sp in
    let p1 = Picture.beside p p in
      Picture.below p p1

let d12 = 
  let p1 = Picture.tex "A" in
    [Command.draw_pic (sierpinski p1 8)]

let rec fold_from_to f acc a b =
  if a <= b then fold_from_to f (f acc a) (a+1) b else acc

let grid x y =
  let fx,fy = float_of_int x, float_of_int y in
  let step = 20. in
  let maxl, maxr = 0., step *. fx in
  let maxu, maxd = step *. fy, 0. in
  let ul, ur = (0., maxu), (maxr, maxu)  in
  let ll, lr = (0., 0.), (maxr, 0.)  in
  let box = path ~style:JLine ~cycle:JLine [ll; lr; ur; ul] in
  let stp i = (float_of_int i) *. step in
  let pattern = Dash.scaled 0.5 Dash.withdots in
  let horizontal i = 
    [Command.draw ~dashed:pattern (path [maxl, stp i; maxr, stp i]);
     Command.draw (path [maxl, stp i; maxl +. step /. 3., stp i]);
     Command.draw (path [maxr, stp i; maxr -. step /. 3., stp i]);
     label ~pos:Pleft (Picture.tex (string_of_int i)) (p (maxl, stp i));
    ]
  in
  let vertical i = 
    [Command.draw ~dashed:pattern (path [stp i, maxd; stp i, maxu]);
     Command.draw (path [stp i, maxl; stp i, maxd +. step /. 3.]);
     Command.draw (path [stp i, maxu; stp i, maxu -. step /. 3.]);
     label ~pos:Pbot (Picture.tex (string_of_int i)) (p (stp i, maxd));
    ]
  in
  let c =
    fold_from_to
      (fun acc i -> (seq (horizontal i)) :: acc)
      (fold_from_to
        (fun acc i -> (seq (vertical i)) :: acc) 
        [Command.draw box] 1 x) 
      1 y
  in
    Picture.make (seq c)

let d13 =
  let p = grid 20 14 in
    [draw_pic p]


let figs = [d13; d11; d7; d6; d5; d4; cheno011; proval; d3; 
            d2sq; d2hsq; d2s; d2c; d1]

let figs =
  let r = ref 0 in
  List.map (fun f -> incr r; !r, f) figs

let () =
  Metapost.generate_mp "test/tests.mp" figs;
  Misc.write_to_formatted_file "test/tests.tex"
    (fun fmt ->
      fprintf fmt "\\documentclass[a4paper]{article}@.";
      fprintf fmt "\\usepackage[]{graphicx}@.";
      fprintf fmt "@[<hov 2>\\begin{document}@.";
      List.iter
        (fun (i,_) ->
          fprintf fmt "@\n %i\\quad" i;
	  fprintf fmt "\\includegraphics[width=\\textwidth,height=\\textwidth,keepaspectratio]{tests.%d}" i;
          fprintf fmt "@\n \\vspace{3cm}@\n"
        ) figs;
      fprintf fmt "@]@\n\\end{document}@.")
