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

open Types
open Hashcons


(* A duplicate analysis - find out the number of times a node is used *)


module Num =
struct
  type t = num_node hash_consed
  let equal = (==)
  let hash x = x.hkey
end

module Point =
struct
  type t = point_node hash_consed
  let equal = (==)
  let hash x = x.hkey
end

module MetaPath =
struct
  type t = metapath_node hash_consed
  let equal = (==)
  let hash x = x.hkey
end

module Path =
struct
  type t = path_node hash_consed
  let equal = (==)
  let hash x = x.hkey
end

module Picture =
struct
  type t = picture_node hash_consed
  let equal = (==)
  let hash x = x.hkey
end

module NM = Hashtbl.Make (Num)
module PtM = Hashtbl.Make (Point)
module MPthM = Hashtbl.Make (MetaPath)
module PthM = Hashtbl.Make (Path)
module PicM = Hashtbl.Make (Picture)

let num_map = NM.create 257
let point_map = PtM.create 257
let path_map = PthM.create 257
let picture_map = PicM.create 257

let test_and_incr_num n =
  try incr (NM.find num_map n) ; true
  with Not_found -> NM.add num_map n (ref 1) ; false

let test_and_incr_point n =
  try incr (PtM.find point_map n); true
  with Not_found -> PtM.add point_map n (ref 1); false

let test_and_incr_path n =
  try incr (PthM.find path_map n); true
  with Not_found -> PthM.add path_map n (ref 1); false

let test_and_incr_pic n =
  try incr (PicM.find picture_map n); true
  with Not_found -> PicM.add picture_map n (ref 1); false

let option_count f = function
  | None -> ()
  | Some x -> f x

let rec num' = function
  | F _ -> ()
  | NXPart p | NYPart p -> point p
  | NAdd(n1,n2)
  | NSub(n1,n2)
  | NMult (n1,n2)
  | NDiv (n1,n2)
  | NMax (n1,n2)
  | NMin (n1,n2)
  | NGMean (n1,n2) -> num n1; num n2
  | NLength p -> path p
  | NIfnullthenelse (n,n1,n2) -> num n; num n1; num n2

and num n =
  if test_and_incr_num n then () else num' n.node

and point' = function
  | PTPair (f1,f2) -> num f1; num f2
  | PTPointOf (f,p) | PTDirectionOf (f,p) -> path p ; num f
  | PTAdd (p1,p2)
  | PTSub (p1,p2) -> point p1; point p2
  | PTMult (f,p) -> num f; point p
  | PTRotated (f,p) -> point p
  | PTPicCorner (pic, corner) -> commandpic pic
  | PTTransformed (p,tr) ->
      point p ; transform tr
and point p =
  if test_and_incr_point p then () else point' p.node

and direction d =
  match d.node with
  | Vec p -> point p
  | Curl _ | NoDir -> ()

and joint j =
  match j.node with
  | JLine | JCurve | JCurveNoInflex | JTension _ -> ()
  | JControls (p1,p2) -> point p1; point p2

and knot k =
  match k.Hashcons.node with
  | { knot_in = d1 ; knot_p = p ; knot_out = d2 } ->
      direction d1; point p; direction d2

and metapath p =
  match p.Hashcons.node with
  | MPAConcat (k,j,p) -> knot k; joint j; metapath p
  | MPAAppend (p1,j,p2) -> metapath p1; joint j; metapath p2
  | MPAKnot k -> knot k
  | MPAofPA p -> path p

and path' = function
  | PAofMPA p -> metapath p
  | MPACycle (d,j,p) -> direction d; joint j; metapath p
  | PATransformed (p,tr) -> path p; transform tr
  | PACutAfter (p1,p2)
  | PACutBefore (p1,p2) -> path p1; path p2
  | PABuildCycle pl -> List.iter path pl
  | PASub (f1, f2, p) -> num f1; num f2; path p
  | PABBox p -> commandpic p
  | PAUnitSquare | PAQuarterCircle | PAHalfCircle | PAFullCircle -> ()
and path p =
(*   Format.printf "%a@." Print.path p; *)
  if test_and_incr_path p then () else path' p.node

and picture' = function
    | PITransformed (p,tr) -> transform tr; commandpic p
    | PITex s -> ()
    | PIClip (pic,pth) -> commandpic pic; path pth
and picture p =
  if test_and_incr_pic p then () else picture' p.node

and transform t =
  match t.node with
  | TRRotated f -> ()
  | TRScaled f | TRSlanted f | TRXscaled f | TRYscaled f  -> num f
  | TRShifted p | TRZscaled p -> point p
  | TRReflect (p1,p2) -> point p1; point p2
  | TRRotateAround (p,f) -> point p
  | TRMatrix p -> num p.x0; num p.y0; num p.xx; num p.xy; num p.yx; num p.yy
and command c =
  match c.node with
  | CDraw (p, b) ->
      path p; brush b
  | CFill (p, c) -> path p
  | CDotLabel (pic, pos, pt) -> commandpic pic; point pt
  | CLabel (pic, pos ,pt) -> commandpic pic; point pt
  | CExternalImage _ -> ()
and brush b =
  let b = b.Hashcons.node in
  option_count pen b.pen; option_count dash b.dash
and pen p =
  match p.Hashcons.node with
  | PenCircle | PenSquare -> ()
  | PenFromPath p -> path p
  | PenTransformed (p, tr) -> pen p; transform tr

and dash d =
  match d.Hashcons.node with
  | DEvenly | DWithdots -> ()
  | DScaled (f, d) -> dash d
  | DShifted (p,d) -> point p; dash d
  | DPattern l -> List.iter dash_pattern l

and dash_pattern o =
  match o.Hashcons.node with
  | On f | Off f -> num f

and commandpic p =
  match p.node with
  | Picture p -> picture p
  | Command c -> command c
  | Seq l -> List.iter commandpic l

