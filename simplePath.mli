(** build a knot from a pair of floats *)
val knot :
    ?l:Path.direction -> ?r:Path.direction -> 
      ?scale:(float -> Num.t) -> float * float -> Path.knot
(** build a knot from a point *)
val knotp :
    ?l:Path.direction -> ?r:Path.direction -> Point.t -> Path.knot

(** build a path from a list of floatpairs *)
val path : 
    ?style:Path.joint -> ?cycle:Path.joint -> ?scale:(float -> Num.t) -> 
      (float * float) list -> Path.t

(** build a path from a knot list *)
val pathk :
    ?style:Path.joint -> ?cycle:Path.joint -> Path.knot list -> Path.t

(** build a path from a point list *)
val pathp :
    ?style:Path.joint -> ?cycle:Path.joint -> Point.t list -> Path.t

(** build a path from [n] knots and [n-1] joints *)
val jointpathk : Path.knot list -> Path.joint list -> Path.t
(** build a path from [n] points and [n-1] joints, with default directions *)
val jointpathp : Point.t list -> Path.joint list -> Path.t

(** build a path from [n] float_pairs and [n-1] joints, with default 
* directions *)
val jointpath : 
    ?scale:(float -> Num.t) -> (float * float) list -> 
      Path.joint list -> Path.t

(** the same functions as in [Path] but with labels *)
val cycle : ?dir:Path.direction -> ?style:Path.joint -> Path.t -> Path.t
val concat : ?style:Path.joint -> Path.t -> Path.knot -> Path.t