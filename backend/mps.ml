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
open Matrix
module P = Picture_lib
module S = Spline_lib
open Format
open Dviinterp

let conversion = 0.3937 *. 72.
let point_of_cm cm = conversion *. cm

let float fmt f =
    (* PDF does not understand e notation, so we protect the printf which
    uses %g in the cases where this would use e notation; we do not need that
    much precision anyway*)
  let a = abs_float f in
  if a < 0.0001 then fprintf fmt "0"
  else if a >= 1.e04 then fprintf fmt "%.4f" f
  else fprintf fmt "%.4g" f

module MPS = struct

  type line_cap =
    | ButtCap
    | RoundCap
    | SquareCap

  type line_join =
    | MiterJoin
    | RoundJoin
    | BevelJoin

  let psstart fmt = fprintf fmt "@[<hov 0>"
  let psend fmt = fprintf fmt "@]"
  let string = pp_print_string
  let moveto_float fmt x y =
    fprintf fmt "%t%a@ %a@ moveto%t" psstart float x float y psend
  let lineto_float fmt x y =
    (* psstart fmt; float fmt x; float fmt y; string fmt "lineto"; psend fmt *)
    fprintf fmt "%t%a@ %a@ lineto%t" psstart float x float y psend
  let moveto fmt p = moveto_float fmt p.x p.y
  let curveto fmt p1 p2 p3 =
    fprintf fmt "%t%a@ %a@ %a@ %a@ %a@ %a@ curveto%t"
      psstart float p1.x float p1.y float p2.x float p2.y float p3.x float p3.y
      psend

  let rlineto fmt p =
    fprintf fmt "%t%a@ %a@ rlineto%t" psstart float p.x float p.y psend
  let close_path fmt = fprintf fmt "%tclose_path%t" psstart psend
  let newpath fmt = fprintf fmt "%tnewpath%t" psstart psend
  let stroke fmt = fprintf fmt "%tstroke%t" psstart psend
  let fill fmt = fprintf fmt "%tfill%t" psstart psend
  let showpage fmt = fprintf fmt "%tshowpage%t" psstart psend
  let clip fmt = fprintf fmt "%tclip%t" psstart psend

  let gsave fmt = fprintf fmt "%tgsave%t" psstart psend
  let grestore fmt = fprintf fmt "%tgrestore%t" psstart psend

  let setlinewidth fmt f =
   fprintf fmt
     "%t0@ %a@ dtransform@ truncate@ idtransform@ setlinewidth@ pop%t"
     psstart float f psend

  let setlinecap fmt c =
    let i =
      match c with
      | ButtCap -> 0
      | RoundCap -> 1
      | SquareCap -> 2 in
    fprintf fmt "%t%d setlinecap%t" psstart i psend

  let setlinejoin fmt j =
    let i =
      match j with
      | MiterJoin -> 0
      | RoundJoin -> 1
      | BevelJoin -> 2 in
    fprintf fmt "%t%d setlinejoin%t" psstart i psend

  let matrix fmt t =
    fprintf fmt "%t[%a@ %a@ %a@ %a@ %a@ %a]%t" psstart
      float t.xx float t.yx float t.xy float t.yy float t.x0 float t.y0 psend

  let transform fmt t =
    if t = Matrix.identity then () else
    fprintf fmt "%t%a concat%t" psstart matrix t psend

  let scolor fmt c =
    match c with
    | Concrete_types.RGB (r,g,b) ->
        fprintf fmt "%t%a@ %a@ %a@ setrgbcolor%t"
          psstart float r float g float b psend
    | Concrete_types.CMYK (c,m,y,k) ->
        fprintf fmt "%t%a@ %a@ %a@ %a@ setcmykcolor%t"
          psstart float c float m float y float k psend
    | Concrete_types.Gray c ->
        fprintf fmt "%t%a@ setgray%t" psstart float c psend

  let color fmt c =
    match c with
    | Concrete_types.OPAQUE c -> scolor fmt c
    | Concrete_types.TRANSPARENT _ -> assert false

  let char_const fmt c =
    fprintf fmt "\\%03lo" c

  let glyph fmt cl font =
    fprintf fmt "%t(%a)@ %s@ %a@ fshow%t" psstart
      (Misc.print_list Misc.nothing char_const) cl
      (Fonts.tex_name font) float (Fonts.scale font conversion) psend

  let rectangle fmt p w h =
    newpath fmt;
    pp_print_space fmt ();
    moveto fmt p;
    pp_print_space fmt ();
    lineto_float fmt (p.x+.w) p.y;
    pp_print_space fmt ();
    lineto_float fmt (p.x+.w) (p.y+.h);
    pp_print_space fmt ();
    lineto_float fmt p.x (p.y+.h);
    pp_print_space fmt ();
    close_path fmt;
    pp_print_space fmt ();
    fill fmt
end

let in_context fmt f =
  MPS.gsave fmt;
  pp_print_space fmt ();
  f ();
  pp_print_space fmt ();
  MPS.grestore fmt

let fill_rect fmt trans _ x y w h =
  (** FIXME take into account info *)
  let x = point_of_cm x and y = point_of_cm y
  and w = point_of_cm w and h = point_of_cm h in
  let p = { x = x ; y = y } in
  in_context fmt (fun () ->
    MPS.transform fmt trans;
    pp_print_space fmt ();
    MPS.rectangle fmt p w h
  )

let draw_char fmt trans text =
  (** FIXME take into account info *)
  let (f1,f2) = text.tex_pos in
  let f1 = point_of_cm f1 and f2 = point_of_cm f2 in
  let p = { x = f1; y = f2 } in
  in_context fmt (fun () ->
    MPS.transform fmt trans;
    pp_print_space fmt ();
    MPS.moveto fmt p;
    pp_print_space fmt ();
    MPS.glyph fmt text.tex_string text.tex_font
  )

(* FIXME why do we need to negate y coordinates? *)
let tex_cmd fmt trans c =
  match c with
  | Dviinterp.Fill_rect (i,x,y,w,h) ->
      fill_rect fmt trans i x (-. y) w h
  | Dviinterp.Draw_text text -> draw_char fmt trans text
  | Dviinterp.Specials _ -> ()
  | Dviinterp.Draw_text_type1 _ -> assert false

let draw_tex fmt t =
  (* FIXME currently the transformation is applied and restored for every
     letter *)
  List.iter (fun x ->
    tex_cmd fmt t.Gentex.trans x;
    pp_print_space fmt ()) t.Gentex.tex

let curveto fmt s =
  let _, sb, sc, sd = Spline.explode s in
  MPS.curveto fmt sb sc sd

let path =
  let rec path fmt = function
    | S.Path p ->
        begin match p.S.pl with
        | [] -> assert false
        | (x::_) as l ->
          MPS.moveto fmt (Spline.left_point x);
	  pp_print_space fmt ();
          Misc.print_list Misc.space curveto fmt l
        end ;
        if p.S.cycle then begin pp_print_space fmt (); MPS.close_path fmt end
    | S.Point p ->
        MPS.moveto fmt p;
	pp_print_space fmt ();
        MPS.rlineto fmt p in
  fun fmt p ->
    MPS.newpath fmt;
    pp_print_space fmt ();
    path fmt p


let option p fmt o =
  match o with
  | None -> ()
  | Some c -> p fmt c

let pen fmt t =
  (* FIXME do something better *)
  (* for now assume that the pen is simply a scaled circle, so just grab the xx
   * value of the matrix and use that as linewidth *)
  MPS.setlinewidth fmt t.xx

let rec picture fmt = function
  | P.Empty -> ()
  | P.OnTop l ->
      Misc.print_list Misc.space picture fmt l
  | P.Stroke_path(pa,clr,pe,_) ->
      (* FIXME dash pattern *)
      in_context fmt (fun () ->
        option MPS.color fmt clr;
	pp_print_space fmt ();
        pen fmt pe;
	pp_print_space fmt ();
        path fmt pa;
	pp_print_space fmt ();
        MPS.stroke fmt)
  | P.Fill_path (p,c)->
      in_context fmt (fun () ->
        option MPS.color fmt c;
	pp_print_space fmt ();
        path fmt p;
	pp_print_space fmt ();
        MPS.fill fmt)
  | P.Tex t -> draw_tex fmt t
  | P.Transform (m,t) -> picture fmt (P.apply_transform_cmds m t)
  | P.Clip (com,p) ->
      in_context fmt (fun () ->
        path fmt p;
	pp_print_space fmt ();
        MPS.clip fmt;
	pp_print_space fmt ();
        picture fmt com
      )
  | _ -> assert false
(*
  | ExternalImage (filename,height,width) ->
      Cairo.save cr;
      inversey cr height;
      let img = Cairo_png.image_surface_create_from_file filename in
      let iwidth = float_of_int (Cairo.image_surface_get_width img) in
      let iheight = float_of_int (Cairo.image_surface_get_height img) in
      Cairo.scale cr (width/.iwidth) (height/.iheight);
      Cairo.set_source_surface cr img 0. 0.;
      Cairo.paint cr;
      Cairo.restore cr
*)

(* FIXME do better than comparing font names *)
module FontCmp = struct
  type t = Fonts.t
  let compare a b = String.compare (Fonts.tex_name a) (Fonts.tex_name b)
end
module FS = Set.Make(FontCmp)

let fonts p =
  let x = ref FS.empty in
  Picture_lib.iter (fun p ->
    match p with
    | P.Tex g ->
        List.iter (fun c ->
          match c with
          | Draw_text text -> x := FS.add text.tex_font !x
          | _ -> ()) g.Gentex.tex
    | _ -> ()) p;
  !x

let draw fmt x =
  let {x = minx; y = miny},{x = maxx; y = maxy} = Picture_lib.bounding_box x in
  let minxt, minyt, maxxt, maxyt =
    floor minx, floor miny, ceil maxx, ceil maxy in
  fprintf fmt "%%!PS@\n";
  fprintf fmt "%%%%BoundingBox: %f %f %f %f@\n" minxt minyt maxxt maxyt;
  fprintf fmt "%%%%HiResBoundingBox: %f %f %f %f@\n" minx miny maxx maxy;
  fprintf fmt "%%%%Creator: Mlpost %s@\n" Version.version;
  fprintf fmt "%%%%CreationDate: %s@\n" (Misc.date_string ());
  fprintf fmt "%%%%Pages: 1@\n";
  let usedfonts = fonts x in
  FS.iter (fun f ->
    let n = Fonts.tex_name f in
    (* FIXME this is not exactly as metapost does *)
    let d = Fonts.design_size f in
    let r = point_of_cm (Fonts.ratio_cm f) in
  (* FIXME what is the 30:f8 for? *)
    fprintf fmt "%%*Font: %s %f %f 30:f8@\n" n d r) usedfonts;
  fprintf fmt "%%%%BeginProlog@\n";
  fprintf fmt "%%%%EndProlog@\n";
  fprintf fmt "%%%%Page: 1 1@\n";
  MPS.setlinewidth fmt (P.default_line_size /.2.);
  pp_print_space fmt ();
  MPS.setlinecap fmt MPS.RoundCap;
  pp_print_space fmt ();
  MPS.setlinejoin fmt MPS.RoundJoin;
  pp_print_space fmt ();
  picture fmt (P.content x);
  pp_print_space fmt ();
  MPS.showpage fmt;
  fprintf fmt "@\n%%%%EOF@\n"

let generate_one fn fig =
  File.write_to_formatted fn (fun fmt ->
    let fig = LookForTeX.commandpic fig in
(*     Format.printf "picturelib code: @\n %a@." P.Print.pic fig; *)
    draw fmt fig);
  fn

let mps figl =
  List.map (fun (fn,fig) ->
(*     Format.printf "metapost code:@\n %a@."Print.commandpic fig; *)
    generate_one fn fig) figl

let dump () = ignore (mps (Metapost.emited ()))

let generate figs =
  let figl = List.map (fun (s,f) ->
    let s = File.from_string s in
    File.set_ext s "mps", f) figs in
  ignore (mps figl)
