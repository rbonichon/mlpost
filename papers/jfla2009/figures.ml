
(* figures pour l'article JFLA *)

open Mlpost
open Command
open Picture
open Path
module H = Helpers
open Num
open Num.Infix
open Point
open Box

(* St�phane *)
(** the old ugly version *)
(* let graph_sqrt = *)
(*   let u = Num.cm in *)
(*   let pen = Pen.circle ~tr:[Transform.scaled one] () in  *)
(*   let rec pg = function *)
(*     | 0 -> start (knot ~r:(vec up) ~scale:u (0.,0.)) *)
(*     | n -> let f = (float_of_int n /. 2.) in  *)
(* 	concat ~style:jCurve (pg (n-1)) (knot ~scale:u (f, sqrt f))  *)
(*   in *)
(*   [draw (pathn ~style:jLine [(zero,u 2.); (zero,zero); (u 4.,zero)]); *)
(*    draw ~pen (pg 8); *)
(*    label ~pos:`Lowright (tex "$ \\sqrt x$") (pt (u 3., u (sqrt 3.))); *)
(*    label ~pos:`Bot (tex "$x$") (pt (u 2., zero)); *)
(*    label ~pos:`Lowleft (tex "$y$") (pt (zero, u 1.))] *)

(** the new short one :) *)
let graph_sqrt =
  let u = cm 1. in
  let sk = Plot.mk_skeleton 4 2 u u in
  let label = Picture.tex "$\\sqrt x$", `Top, 3 in
  let graph = Plot.draw_func ~label (fun x -> sqrt (float x)) sk in
    [graph; Plot.draw_simple_axes "$x$" "$y$" sk]

let architecture =
  let fill = Color.color "salmon" in 
  let mk_box name m = 
    Box.tex ~style:RoundRect ~dx:(bp 5.) ~dy:(bp 5.) ~name ~fill m in
  let mk_unbox name m = 
    Box.tex ~style:RoundRect ~stroke:None ~dx:(bp 5.) ~dy:(bp 5.) ~name m in
  let num = mk_box "num" "Num" in
  let point = mk_box "point" "Point" in
  let path = mk_box "num" "Path" in
  let dots = mk_unbox "dots" "$\\ldots$" in
  let cmd = mk_box "cmd" "Command" in
  let basictypes = Box.hbox ~padding:(mm 2.) [num; point; path; dots; cmd] in
  let compile = mk_unbox "compile" "Compile" in
  let compile_ext = 
    let dx = (Box.width basictypes -/ Box.width compile) /./ 2. in
    Box.hbox ~style:RoundRect ~dx ~fill ~stroke:(Some Color.black) [compile]
  in
    [Box.draw (Box.vbox ~padding:(mm 2.) [basictypes; compile_ext])]

(* Romain *)
let automate =
  [nop]

(* Johannes *)
let diagramme =
  [nop]

(* JC *)
let bresenham =
  [nop]

let () = Metapost.emit "automate" automate
let () = Metapost.emit "diagramme" diagramme
let () = Metapost.emit "graph_sqrt" graph_sqrt
let () = Metapost.emit "architecture" architecture
let () = Metapost.emit "bresenham" bresenham




