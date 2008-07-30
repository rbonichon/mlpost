module type POS =
sig
  (* POS.repr is the type of objects that we know how to position.
   * In most implementations of POS, this type will be visible.
   * However, in many cases (see ALIGN below) it is convenient to store
   * information about center, size etc along with the object. That is what
   * POS.t is for (consider types of POS.ctr, POS.height, POS.width). POS.t will
   * generally be abstract. To actually move the object, solely its structure is
   * needed (shift all subobjects by the same amount). *)

  type t
  type repr

  val ctr : t -> Point.t
  val height : t -> Num.t
  val width : t -> Num.t
  val shift : Point.t -> repr -> repr

  (* get back the structure of the object *)
  val v : t -> repr

end


open Num.Infix
open Command

module type ALIGN =
sig
  module P : POS
  include POS with type repr = P.repr list
  val horizontal : 
    ?dx:Num.t -> ?spacing:Num.t -> ?pos:Command.position -> P.t list -> t

  val vertical : 
    ?dy:Num.t -> ?spacing:Num.t -> ?pos:Command.position -> P.t list -> t
end

type 'a tree = N of 'a * 'a tree list

module type TREE =
sig
  module P : POS
  include POS with type repr = P.repr tree
  val place : ?dx:Num.t -> ?dy:Num.t -> P.t tree -> t
end

module Align (P : POS) : ALIGN with module P = P  =
struct
  type repr = P.repr list
  type t = { v : P.repr list; center : Point.t; height : Num.t; width : Num.t}
  
  let height x = x.height
  let width x = x.width
  let ctr x = x.center
  let v x = x.v
  module P = P

  let shift pt t = List.map (P.shift pt) t

  let horizontal ?(dx=Num.zero) ?(spacing=Num.zero) ?(pos=Pcenter) pl =
    let hmax = Num.fold_max P.height Num.zero pl in
    let hmax_2 = hmax // Num.two in
    let rec make_new acc x = function
      | [] -> List.rev acc, x
      | p :: pl ->
          let wp,hp = P.width p, P.height p in
          let y = 
            match pos with
              | Pcenter -> hmax_2
              | Ptop -> hmax -/ hp // Num.two
              | Pbot -> hp // Num.two
              | _ -> failwith "alignment not supported"
          in
          let c = Point.pt (x +/ dx +/ wp // Num.two, y) in 
          let b = P.shift (Point.sub c (P.ctr p)) (P.v p) in
            make_new (b::acc) (x +/ wp +/ dx +/ dx +/spacing) pl
    in
    let l,x = make_new [] Num.zero pl in
    let mycenter = Point.pt (x // Num.two, hmax_2) in
    { v = l; width = x; height = hmax; center = mycenter }

  let vertical ?(dy=Num.zero) ?(spacing=Num.zero) ?(pos=Pcenter) pl =
    let wmax = Num.fold_max P.width Num.zero pl in
    let wmax_2 = wmax // Num.two in
    let rec make_new acc y = function
      | [] -> List.rev acc, y
      | p :: pl ->
          let wp,hp = P.width p, P.height p in
          let x = 
            match pos with
              | Pcenter -> wmax_2
              | Pright -> wmax -/ wp // Num.two
              | Pleft ->  wp // Num.two
              | _ -> failwith "alignment not supported"
          in
          let c = Point.pt (x, y -/ dy -/ hp // Num.two) in 
          let b = P.shift (Point.sub c (P.ctr p)) (P.v p) in
            make_new (b::acc) (y -/ hp -/ dy -/ dy -/ spacing) pl
    in
    let l,y = make_new [] Num.zero pl in
    let mycenter = Point.pt (wmax_2, y // Num.two) in
    { v = l; width = wmax; height = y; center = mycenter }
end

module Tree (P : POS) : TREE with module P = P =
struct
  module P = P
  type repr = P.repr tree
  type repr' = repr
  type t = {ctr : Point.t; w : Num.t ; h : Num.t ; v : repr}
  type t' = t

  let v x = x.v
  let ctr x = x.ctr
  let height x = x.h
  let width x = x.w

  let rec shift pt (N (a,l)) = 
    N (P.shift pt a, List.map (shift pt) l)

  module Aux : POS with type repr = repr' and type t = t' =
  struct
    type repr = repr'
    type t = t'
    let v = v
    let ctr = ctr
    let height = height
    let width = width
    let shift = shift
  end

  module TA = Align (Aux)

  let rec place ?dx ?(dy=Num.zero) (N (a,l)) = 
    let pl = TA.horizontal ?dx (List.map (place ?dx ~dy) l) in
    let ctr = 
      Point.add (TA.ctr pl) (Point.pt (Num.zero, P.height a // Num.two +/ dy))
    in
    let new_point = Point.add (TA.ctr pl) (Point.pt (Num.zero, dy)) in
      { v = N (P.shift (Point.sub new_point (P.ctr a)) (P.v a), TA.v pl);
        w = TA.width pl; h = TA.height pl; ctr = ctr; }
end
