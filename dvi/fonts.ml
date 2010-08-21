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

open Dvi_util

exception Fonterror of string

let font_error s = raise (Fonterror s)

type type1 =
    { glyphs_tag : int;
      glyphs_filename : string;
      (* the file, pfb or pfa, which define the glyphs *)
      glyphs_enc : int -> int; (* the conversion of the characters
                                  between tex and the font *)
      slant : float option;
      extend : float option;
      glyphs_ratio_cm : float}

type vf =
    { vf_design_size : float;
      vf_font_map : Dvi_util.font_def Dvi_util.Int32Map.t;
      vf_chars : Dvi.command list Int32H.t}


type glyphs =
  | Type1 of type1
  | VirtualFont of vf

type t =
    { tex_name : string;
      metric : Tfm.t;
      glyphs : glyphs Lazy.t;
      ratio : float;
      ratio_cm : float
    }

let debug = ref false
let info = ref false

let tex_name t = t.tex_name
let ratio_cm t = t.ratio_cm
let metric t = t.metric
let design_size t = Tfm.design_size t.metric
let glyphs t = Lazy.force t.glyphs

let scale t f = t.ratio_cm *. f
let set_verbosity b = info := b


let kwhich = "kpsewhich"
let t1disasm = ref None (*"t1disasm"*)
let which_fonts_table = "pdftex.map"

let memoize f nb =
  let memoize = Hashtbl.create nb in
  fun arg ->
    try
      Hashtbl.find memoize arg
    with
        Not_found ->
          let result = f arg in
          Hashtbl.add memoize arg result;
          result

let find_file_aux file =
  let temp_fn = Filename.temp_file "font_path" "" in
  let exit_status =
    Sys.command
      (Format.sprintf "%s %s > %s" kwhich file temp_fn) in
  if exit_status <> 0 then font_error "kwhich failed"
  else
    let cin = open_in temp_fn in
    let n =
      try input_line cin
      with _ ->
	close_in cin; Sys.remove temp_fn; font_error "Cannot find font"
    in
    close_in cin; Sys.remove temp_fn; n

let find_file = memoize find_file_aux 30

module HString = Hashtbl

let open_pfb_decrypted filename =
  match !t1disasm with
    | None ->
        let buf = T1disasm.open_decr filename in
        (*Buffer.output_buffer stdout buf;*)
        Lexing.from_string (Buffer.contents buf), fun () -> ()
    | Some t1disasm ->
        let temp_fn = Filename.temp_file "pfb_human" "" in
        let exit_status =
          Sys.command
            (Format.sprintf "%s %s > %s" t1disasm filename temp_fn) in
        if exit_status <> 0 then font_error "pfb_human generation failed"
        else
          let file = open_in temp_fn in
          Lexing.from_channel file,(fun () -> Sys.remove temp_fn)

let deal_with_error ?(pfb=false) lexbuf f =
  try f ()
  with
  | (Parsing.Parse_error |Failure _) as a->
      let p_start = Lexing.lexeme_start_p lexbuf in
      let p_end = Lexing.lexeme_end_p lexbuf in
      let str =
        if not pfb then "" else
          match !Pfb_lexer.state with
          | Pfb_lexer.Header -> "header"
          | Pfb_lexer.Encoding -> "encoding"
          | Pfb_lexer.Charstring -> "charstring" in
      Format.eprintf "line %i, characters %i-%i : %s parse_error state : %s@."
      p_start.Lexing.pos_lnum p_start.Lexing.pos_bol p_end.Lexing.pos_bol
      (Lexing.lexeme lexbuf) str ;
      raise a

let load_pfb_aux filename =
  if !info then
    Format.printf "Loading font from %s...@?" filename;
  let lexbuf,do_done = open_pfb_decrypted filename in
  deal_with_error lexbuf ~pfb:true (fun () ->
     let encoding_table, charstring =
      Pfb_parser.pfb_human_main Pfb_lexer.pfb_human_token lexbuf in
    let charstring_table = Hashtbl.create 700 in
    let count = ref 0 in
    List.iter (fun x ->
      Hashtbl.add charstring_table x !count;incr(count)) charstring;
    if !info then Format.printf "done@.";
    do_done ();
    encoding_table,charstring_table)

let load_pfb = memoize load_pfb_aux 15

let load_fonts_map filename =
  if !info then Format.printf "Load font map from %s...@?" filename;
  let file = open_in filename in
  let lexbuf = Lexing.from_channel file in
  deal_with_error lexbuf (fun () ->
    let result = Map_parser.pdftex_main Map_lexer.pdftex_token lexbuf in
    let table = HString.create 1500 in
    List.iter (fun x -> HString.add table x.Fonts_type.tex_name x) result;
    if !info then Format.printf "done@.";
    table)

let load_enc_aux filename =
  if !info then
    Format.printf "Loading enc from %s...@?" filename;
  let file = open_in filename in
  let lexbuf = Lexing.from_channel file in
  deal_with_error lexbuf (fun () ->
    let result = Pfb_parser.enc_main Pfb_lexer.enc_token lexbuf in
    let enc_table = Array.create 256 "" in
    let count = ref 0 in
    List.iter (fun x -> enc_table.(!count)<-x;incr(count)) result;
    if !info then Format.printf "done@.";
    enc_table)

let load_enc = memoize load_enc_aux 15

let fonts_map_table = lazy (load_fonts_map (find_file which_fonts_table))

let fonts_table = (HString.create 1500 : (string,t) Hashtbl.t)

let load_font_tfm fd =
  if !info then
    Format.printf "Loading font %s at [%ld/%ld]...@?"
      fd.name fd.scale_factor fd.design_size;
  let filename =
    if fd.area <> "" then
      Filename.concat fd.area fd.name
    else
      find_file (fd.name^".tfm") in
  if !debug then
    Format.printf "Trying to find metrics at %s...@." filename;
  let tfm = Tfm.read_file filename in
  (* FixMe in vf file the checksum of tfm is 0 *)
  if (Int32.compare fd.checksum Int32.zero <> 0 &&
        Int32.compare tfm.Tfm.body.Tfm.header.Tfm.checksum
	fd.checksum <> 0) then
    font_error "Metrics checksum do not match !.@.";
  if !debug then
    Format.printf "Metrics successfully loaded for font %s from %s.@."
      fd.name filename;
  if !info then
    Format.printf "done@.";
  tfm

let compute_trans_enc encoding_table charset_table char =
  Hashtbl.find charset_table (encoding_table.(char))

let font_is_virtual s =
  try
    Some (find_file (s^".vf"))
  with Fonterror _ -> None

let id = let c = ref (-1) in fun () -> incr c; !c

let load_glyphs tex_name ratio_cm =
  match font_is_virtual tex_name with
    | Some vf ->
      let vf = Dvi.read_vf_file vf in
      let vf_chars = Int32H.create 257 in
      let add cd = Int32H.add vf_chars cd.Dvi.char_code cd.Dvi.char_commands in
      List.iter add vf.Dvi.vf_chars_desc;
      VirtualFont { vf_design_size = vf.Dvi.vf_preamble.Dvi.pre_vf_ds;
                    vf_font_map = vf.Dvi.vf_font_map;
                    vf_chars = vf_chars}
    | None    ->
      let font_map = try HString.find (Lazy.force fonts_map_table) tex_name
        with Not_found ->
          invalid_arg
            (Format.sprintf "This tex font : %s has no pfb counterpart@ \
                             and seems not to be virtual@ \
                             it can't be currently used with the cairo backend"
               tex_name) in
      let pfab = find_file font_map.Fonts_type.pfab_name in
      let pfab_enc,pfab_charset = load_pfb pfab in
      let enc = match font_map.Fonts_type.enc_name with
        | None -> pfab_enc
        | Some x -> load_enc (find_file x) in
      let glyphs_enc = compute_trans_enc enc pfab_charset in
      Type1 { glyphs_tag = id ();
              glyphs_filename = pfab;
              glyphs_enc = glyphs_enc;
              slant = font_map.Fonts_type.slant;
              extend = font_map.Fonts_type.extend;
              glyphs_ratio_cm = ratio_cm}

let load_font doc_conv fdef =
  let tex_name = fdef.name in
  let tfm = load_font_tfm fdef in
  let ratio = Int32.to_float fdef.scale_factor
    (*(Int32.to_float (Int32.mul mag fdef.Dvi.scale_factor))
    /. 1000. (* fdef.Dvi.design_size *)*)
  and ratio_cm =
    (Int32.to_float fdef.scale_factor) *. doc_conv
  in
  let glyphs = lazy (load_glyphs tex_name ratio_cm) in
  { tex_name = tex_name;
    metric = tfm;
    glyphs = glyphs;
    ratio = ratio;
    ratio_cm = ratio_cm
  }

let load_font =
  let memoize = Hashtbl.create 15 in
  fun (fdef : font_def) (doc_conv : float) ->
    try
      Hashtbl.find memoize (doc_conv,fdef.name)
    with
        Not_found ->
          let result = load_font doc_conv fdef in
          Hashtbl.add memoize (doc_conv,fdef.name) result;
          result

let char_width t c = Metric.char_width t.metric c *. t.ratio
let char_height t c = Metric.char_height t.metric c *. t.ratio
let char_depth t c = Metric.char_depth t.metric c *. t.ratio

let char_dims t c =
  let a,b,c = Metric.char_dims t.metric c and f = t.ratio in
  a *. f, b *. f, c *. f


