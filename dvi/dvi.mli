(** Low-level DVI interface *)

(** The DVI preamble *)
type preamble = {
  pre_version : int;
  pre_num : int32;
  pre_den : int32;
  pre_mag : int32;
  pre_text : string;
}

(** The DVI postamble *)
type postamble = {
  last_page : int32;
  post_num : int32;
  post_den : int32;
  post_mag : int32;
  post_height : int32;
  post_width : int32;
  post_stack : int;
  post_pages : int;
}

(** The DVI postpostamble *)
type postpostamble = {
  postamble_pointer : int32;
  post_post_version : int;
}

(** The type of commands. All coordinates in this type are relative to the
    current state of the DVI document. *)
type command =
  | SetChar of int32
  | SetRule of int32 * int32
  | PutChar of int32
  | PutRule of int32 * int32
  | Push
  | Pop
  | Right of int32
  | Wdefault
  | W of int32
  | Xdefault
  | X of int32
  | Down of int32
  | Ydefault
  | Y of int32
  | Zdefault
  | Z of int32
  | FontNum of int32
  | Special of string

(** A page is a list of commands *)
type page = {
  counters : int32 array;
  previous : int32;
  commands : command list
}

(** A document is a list of pages, plus a preamble, postamble,
   postpostamble and font map *)
type t = {
  preamble : preamble;
  pages : page list;
  postamble : postamble;
  postpostamble : postpostamble;
  font_map : Dvi_util.font_def Dvi_util.Int32Map.t
}

(** a few accessor functions *)
val get_conv : t -> float

val fontmap : t -> Dvi_util.font_def Dvi_util.Int32Map.t

val commands : page -> command list

val pages : t -> page list

val read_file : string -> t


(** Vf files *)

(* Vf type *)

type preamble_vf = {
  pre_vf_version : int;
  pre_vf_text    : string;
  pre_vf_cs      : int32;
  pre_vf_ds      : float;
}

type char_desc =
    { char_code : int32;
      char_tfm  : int32;
      char_commands   : command list}

type vf =
    { vf_preamble   : preamble_vf;
      vf_font_map   : Dvi_util.font_def Dvi_util.Int32Map.t;
      vf_chars_desc : char_desc list}

val print_vf : Format.formatter -> vf -> unit
val read_vf_file : string -> vf

