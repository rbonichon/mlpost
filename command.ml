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

module F = Format
module T = Transform

type position =
  | Center
  | PLeft
  | PRight
  | PTop
  | PBot
  | UpLeft
  | UpRight
  | LowLeft
  | LowRight

type t = 
  | Draw of Path.t * Color.t option * Pen.t option
  | DrawArrow of Path.t * Color.t option * Pen.t option
  | Fill of Path.t * Color.t option
  | Label of Picture.t * position * Point.t
  | DotLabel of Picture.t * position * Point.t
  | Loop of int * int * (int -> t list)
  | DrawBox of Color.t option * Box.t

type figure = t list

let label ?(pos=Center) pic point = Label (pic,pos,point)
(* replace later *)
let dotlabel ?(pos=Center) pic point = DotLabel (pic,pos,point)

let draw ?color ?pen t = 
  (* We don't use a default to avoid the output of 
     ... withcolor (0.00red+0.00green+0.00blue) withpen .... 
     for each command in the output file *)
    Draw (t, color, pen)

let draw_arrow ?color ?pen t = DrawArrow (t, color, pen)

let fill ?color t = Fill (t, color)

let iter from until f = Loop (from, until, f)

let draw_box ?fill b = DrawBox (fill, b)

let print_position fmt = function
  | Center  -> F.fprintf fmt ""
  | PLeft   -> F.fprintf fmt ".lft"
  | PRight  -> F.fprintf fmt ".rt"
  | PTop    -> F.fprintf fmt ".top"
  | PBot    -> F.fprintf fmt ".bot"
  | UpLeft  -> F.fprintf fmt ".ulft"
  | UpRight -> F.fprintf fmt ".urt"
  | LowLeft -> F.fprintf fmt ".llft"
  | LowRight -> F.fprintf fmt ".lrt"

let print_option start printer fmt = function
  | None -> ()
  | Some o -> F.fprintf fmt "%s%a" start printer o

let rec print_command fmt  = function
  | Draw (path, color, pen) ->
      F.fprintf fmt "draw %a%a%a;@\n" Path.print path
        (print_option " withcolor " Color.print) color
        (print_option " withpen " Pen.print) pen
  | DrawArrow (path, color, pen) ->
      F.fprintf fmt "drawarrow %a%a%a;@\n" Path.print path
        (print_option " withcolor " Color.print) color
        (print_option " withpen " Pen.print) pen
  | Fill (path, color) ->
      F.fprintf fmt "fill %a%a;@\n" Path.print path
        (print_option " withcolor " Color.print) color
  | Label (pic,pos,p) ->
      F.fprintf fmt "label%a(%a,%a); @\n"
        print_position pos Picture.print pic Point.print p
  | DotLabel (pic,pos,p) ->
      F.fprintf fmt "dotlabel%a(%a,%a); @\n"
        print_position pos Picture.print pic Point.print p
  | Loop(from,until,cmd) ->
      for i = from to until - 1 do
	List.iter (print_command fmt) (cmd i);
      done
  | DrawBox (None, b) ->
      F.fprintf fmt "%adrawboxed(%a);@\n" Box.declare b Name.print (Box.name b)
  | DrawBox (Some _ as c, b) ->
      let fill = Fill (Path.bpath b, c) in
      F.fprintf fmt "%a%adrawboxed(%a);@\n" 
	Box.declare b print_command fill Name.print (Box.name b)

let print i fmt l =
  F.fprintf fmt "beginfig(%d)@\n %a endfig;@." i 
    (fun fmt l -> List.iter (print_command fmt) l)
    l