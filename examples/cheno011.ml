open Mlpost
open Path
open Command
module SP = SimplePath
module T = Transform

let fig =
  let p = SP.path ~cycle:JCurve [(0.,0.); (30.,40.); (40.,-20.); (10.,20.)] in
  let pen = Pen.transform [T.scaled 1.5] Pen.circle in
  [Command.draw p;
   Command.seq 
     (List.map
	 (fun (pos, l, i) -> 
	   Command.dotlabel ~pos (Picture.tex l) (Path.point i p))
	 [Pbot, "0", 0.;  Pupleft, "1", 1. ;
	  Plowleft, "2", 2. ;  Ptop, "3", 3. ; Pleft, "4", 4. ]);
   Command.draw ~pen (Path.sub 1.3 3.2 p)]
