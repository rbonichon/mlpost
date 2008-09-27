(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) Johannes Kanig, Stephane Lescuyer                       *)
(*  and Jean-Christophe Filliatre                                         *)
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

type color = 
  | RGB of float * float * float
  | CMYK of float * float * float * float
  | Gray of float

type name = string

type corner = N | S | W | E | NE | NW | SW | SE
type piccorner = UL | UR | LL | LR


type hposition = [`Center | `Left | `Right]
type vposition = [`Center | `Top | `Bot]
type position = [
  | hposition 
  | vposition 
  | `Upleft
  | `Upright
  | `Lowleft
  | `Lowright
]

open Hashcons

type num_node = private
  | F of float
  | NXPart of point
  | NYPart of point
  | NAdd of num * num
  | NSub of num * num
  | NMult of num * num
  | NDiv of num * num
  | NMax of num * num
  | NMin of num * num
  | NGMean of num * num
  | NLength of path

and num = num_node hash_consed

and point_node = private
  | PTPair of num * num
  | PTPicCorner of picture * piccorner
  | PTPointOf of float * path
  | PTDirectionOf of float * path
  | PTAdd of point * point
  | PTSub of point * point
  | PTMult of num * point
  | PTRotated of float * point
  | PTTransformed of point * transform list

and point = point_node hash_consed

and on_off_node = private 
  | On of num 
  | Off of num

and on_off = on_off_node hash_consed 

and direction_node = private
  | Vec of point
  | Curl of float
  | NoDir 

and direction = direction_node hash_consed

and joint_node = private
  | JLine
  | JCurve
  | JCurveNoInflex
  | JTension of float * float
  | JControls of point * point

and joint = joint_node hash_consed

and knot_node = private 
    { knot_in : direction ; knot_p : point ; knot_out : direction }

and knot = knot_node hash_consed

and path_node = private
  | PAConcat of knot * joint * path
  | PACycle of direction * joint * path
  | PAFullCircle
  | PAHalfCircle
  | PAQuarterCircle
  | PAUnitSquare
  | PATransformed of path * transform list
  | PAKnot of knot
  | PAAppend of path * joint * path
  | PACutAfter of path * path
  | PACutBefore of path * path
  | PABuildCycle of path list
  | PASub of float * float * path
  | PABBox of picture

and path = path_node hash_consed

and transform_node = private
  | TRRotated of float
  | TRScaled of num
  | TRShifted of point
  | TRSlanted of num
  | TRXscaled of num
  | TRYscaled of num
  | TRZscaled of point
  | TRReflect of point * point
  | TRRotateAround of point * float

and transform = transform_node hash_consed

and picture_node = private
  | PITex of string
  | PIMake of command
  | PITransform of transform list * picture
  | PIClip of picture * path

and picture = picture_node hash_consed

and dash_node = private
  | DEvenly
  | DWithdots
  | DScaled of float * dash
  | DShifted of point * dash
  | DPattern of on_off list

and dash = dash_node hash_consed

and pen_node = private
  | PenCircle
  | PenSquare
  | PenFromPath of path
  | PenTransformed of pen * transform list

and pen = pen_node hash_consed

and command_node = private
  | CDraw of path * color option * pen option * dash option
  | CDrawArrow of path * color option * pen option * dash option
  | CDrawPic of picture
  | CFill of path * color option
  | CLabel of picture * position * point
  | CDotLabel of picture * position * point
  | CSeq of command list

and command = command_node hash_consed

(* smart constructors *)

(* num *)

val mkF: float -> num

val mkNAdd : num -> num -> num

val mkNSub : num -> num -> num

val mkNMult : num -> num -> num

val mkNDiv : num -> num -> num

val mkNMax : num -> num -> num

val mkNMin : num -> num -> num

val mkNGMean : num -> num -> num

val mkNXPart : point -> num

val mkNYPart : point -> num

val mkNLength : path -> num

(* point *)

val mkPTPair : num -> num -> point

val mkPTAdd : point -> point -> point

val mkPTSub : point -> point -> point

val mkPTMult : num -> point -> point

val mkPTRotated : float -> point -> point

val mkPTTransformed : point -> transform list -> point

val mkPTPointOf : float -> path -> point
val mkPTDirectionOf : float -> path -> point

val mkPTPicCorner : picture -> piccorner -> point

(* transform *)

val mkTRScaled :  num -> transform

val mkTRXscaled :  num -> transform

val mkTRYscaled :  num -> transform

val mkTRZscaled :  point -> transform

val mkTRRotated : float -> transform

val mkTRShifted : point -> transform

val mkTRSlanted : num -> transform

val mkTRReflect : point -> point -> transform

val mkTRRotateAround : point -> float -> transform

(* knot *)

val mkKnot : direction -> point -> direction -> knot

(* path *)

val mkPAKnot : knot -> path
val mkPAConcat : knot -> joint -> path -> path
val mkPACycle : direction -> joint -> path -> path
val mkPAAppend : path -> joint -> path -> path
val mkPAFullCircle : path
val mkPAHalfCircle : path
val mkPAQuarterCircle : path
val mkPAUnitSquare : path
val mkPATransformed : path -> transform list -> path
val mkPACutAfter : path -> path -> path
val mkPACutBefore : path -> path -> path
val mkPABuildCycle : path list -> path
val mkPASub : float -> float -> path -> path
val mkPABBox : picture -> path

(* joint *)
val mkJCurve : joint
val mkJLine : joint
val mkJCurveNoInflex : joint
val mkJTension: float -> float -> joint
val mkJControls: point -> point -> joint


(* direction *)

val mkNoDir : direction
val mkVec : point -> direction
val mkCurl : float -> direction

(* picture *)

val mkPITex : string -> picture
val mkPIMake : command -> picture
val mkPITransform : transform list -> picture -> picture
val mkPIClip : picture -> path -> picture

(* command *)

val mkCDraw: path -> color option -> pen option -> dash option -> command
val mkCDrawArrow: path -> color option -> pen option -> dash option -> command
val mkCDrawPic: picture -> command
val mkCFill: path -> color option -> command
val mkCLabel: picture -> position -> point -> command
val mkCDotLabel: picture -> position -> point -> command
val mkCSeq: command list -> command

(* dash *)

val mkDEvenly: dash
val mkDWithdots: dash
val mkDScaled: float -> dash -> dash
val mkDShifted: point -> dash -> dash
val mkDPattern: on_off list -> dash

(* pen *)

val mkPenCircle: pen
val mkPenSquare: pen
val mkPenFromPath: path -> pen
val mkPenTransformed: pen -> transform list -> pen

(* on_off *)

val mkOn : num -> on_off
val mkOff : num -> on_off
