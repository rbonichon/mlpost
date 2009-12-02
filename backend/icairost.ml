(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) Johannes Kanig, Stephane Lescuyer                       *)
(*  Jean-Christophe Filliatre, Romain Bardou and Francois Bobot           *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Point_lib
open Format
let info = ref false

let create create_surface out_file (draw:Cairo.t -> unit) height width =
  if !info then printf "height = %f, width = %f@." height width;
  let oc = open_out out_file in
  let s = create_surface oc ~width_in_points:width ~height_in_points:height in
  let cr = Cairo.create s in
  draw cr;
  if !info then printf "Clean up surface_finish ...@.";
  Cairo.surface_finish s;
  if !info then printf "Clean up close file ...@.";
  close_out oc

let rec iter_after f after = function
  | [] -> ()
  | [a] -> f a
  | a::l -> f a; after a;iter_after f after l

let error_replace_by_tex msg_error f arg = 
  match msg_error with
  | None -> f arg
  | Some w -> try f arg with exn -> 
      let msg = sprintf "Error : %s" (Printexc.to_string exn) in
      let msg = Picture.escape_all msg in
      printf "%s@." msg;
      f (Types.mkPicture (Types.mkPITex (sprintf 
"\\begin{minipage}{%f pt}
%s
\\end{minipage}
" w  msg)))



let emit_gen ?msg_error create next_page figs = 
  (*Format.printf "Fig : %a@." Print.commandpic (List.hd figs);*)
  let figs = LookForTeX.commandpicl_error (error_replace_by_tex msg_error) figs in
  let (min,max) = Point_lib.list_min_max Picture_lib.bounding_box figs in
  let ({x=xmin;y=ymin},{x=xmax;y=ymax}) = min,max in
  (*Point_lib.sub min Compute.bbox_offset,
    Point_lib.add max Compute.bbox_offset in*)
  let height = ymax -. ymin in
  let width = xmax -. xmin in
  let figs = List.map (fun fig -> Picture_lib.shift fig (-.xmin) (-.ymin)) figs in
  create (fun cr -> 
            iter_after (Draw.Picture.draw cr width height) (next_page cr) figs
         ) height width

let dumb_next_page _ _ = assert false

let emit_pdf ?msg_error fname fig = emit_gen ?msg_error (create Cairo_pdf.surface_create_for_channel fname) dumb_next_page [fig]
let emit_ps fname fig = emit_gen (create Cairo_ps.surface_create_for_channel fname) dumb_next_page [fig]
let emit_svg fname fig = emit_gen (create Cairo_svg.surface_create_for_channel fname) dumb_next_page [fig]
let emit_png fname fig = emit_gen 
  (fun draw height width ->
     let width = int_of_float (ceil width) in
     let height = int_of_float (ceil height) in
     let surf = Cairo.image_surface_create Cairo.FORMAT_ARGB32 ~width ~height in
     let cr = (Cairo.create surf) in
     draw cr;
     Cairo_png.surface_write_to_file surf fname) dumb_next_page [fig]

let emit_cairo cairo (width,height) fig = 
  (*Compute.clear (); LookForTeX.clear ();*)
  let fig = LookForTeX.commandpic fig in
  Draw.Picture.draw cairo width height fig

let emit_pdfs fname figs = emit_gen 
  (create Cairo_pdf.surface_create_for_channel fname) 
  (fun cr _ -> Cairo.show_page cr) figs
