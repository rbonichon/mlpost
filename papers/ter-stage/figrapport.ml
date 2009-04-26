open Mlpost
open Num
open Color
open Box
open Path
open Tree

(* blocks mémoire *)     

let simple_block =
  let b = Box.hblock ~pos:`Bot [Box.tex "a"; Box.tex "b"; Box.tex "D"] in
  Box.draw b

(* schema de l'interface *)
let interface = 
  let dx = bp 5. and dy = bp 5. in
  let tex' = tex ~style:RoundRect ~dx ~dy in
  let tex = tex' ~stroke:(Some Color.black) in
  let box name = box ~stroke:None ~dx:(mm 2.) ~name in
  let fml = box "fml" (tex "figure.ml") in
  let fedit = box "fedit" (tex "figure.edit") in
  let png = box "png" (tex "figure.png") in
  Command.nop


let hist1 =
  Hist.simple [3.;1.;6.]

let hist2 =
  Hist.compare
  [[1.;5.;6.;5.;3.];
   [1.;2.;3.;6.;-1.]]

let hist3 =
  Hist.stack ~fill:[lightred;lightblue;lightyellow;lightgreen]
    [[4.;5.;5.;]; [8.;3.;1.]; [2.;8.;1.;4.]]

let hist5 =
  Hist.stack
    ~perspective:true ~padding:(bp 25.)
    ~fill:[lightred;lightblue;lightyellow;lightgreen]
    ~histlabel:(`Center, Hist.Values)
    [[4.;5.;5.;]; [8.;3.;1.]; [2.;8.;1.;4.]]


let hist4 =
  let pics =
    List.map Picture.tex ["2000";"2001";"2002";"2003";"2004";"2005"]
  in
  Hist.simple ~histlabel:(`Top, Hist.User pics)
    [4.5;5.0;6.2;8.;7.2;6.1]

let radar1 =
  let pic =
    Radar.stack
      ~pen:(Pen.scale (bp 3.) Pen.circle)
      ~color:[blue;red;green]
      ~label:["weight";"acceleration";"speed";"maniability";"stickiness"]
      [[3.;4.;5.;6.;4.];
       [6.;5.;2.;1.;1.];
       [1.;7.;2.;4.;5.]]
  in
  Command.draw_pic pic
 

let radar2 =
    let pics =
    Radar.compare
    ~pen:(Pen.scale (bp 1.5) Pen.circle)
    ~color:[lightblue;lightred;lightgreen] ~fill:true
    [[3.;4.;5.;6.;4.];
      [6.;5.;2.;1.;1.];
      [1.;7.;2.;4.;5.]]
    in
    Box.draw (Box.vbox ~padding:(bp 10.) 
    (List.map (Box.pic ~stroke:None) pics))

let path1 = 
  let p = Path.smart_path 
    [Right;Up;Right]
    ~style:jLine
    (Point.pt (bp 0.,bp 0.)) 
    (Point.pt (bp 50.,bp 50.))
  in
  Command.draw p

let path2 = 
  let p = Path.smart_path 
    [Right;Down;Left;Down;Right;Down;Left;Down;Right]
    ~style:jLine
    (Point.pt (bp 0.,bp 100.)) 
    (Point.pt (bp 100.,bp 0.))
  in
  Command.draw_arrow p

let path3 = 
  let p = Path.smart_path 
    [Left;Down;Left;Down;Left] 
    (Point.pt (bp 0.,bp 0.)) 
    (Point.pt (bp (-50.),bp (-50.)))
  in
  Command.draw_arrow p


let path4 = 
  let p = Path.smart_path 
    [Down;Right;Upn (bp 10.);Right;Downn (bp 10.);Right;Upn (bp 10.);Right;Downn (bp 10.);Right;Upn (bp 10.);Right;Down]
    (Point.pt (bp 0.,bp 100.)) 
    (Point.pt (bp 100.,bp 0.))
  in
  Command.draw p

 
let tree1 =
  let node s = Tree.node ~edge_style:Curve (Box.tex s) in
  let leaf s = Tree.leaf (Box.tex s) in
  Tree.draw (node "1" [node "2" [leaf "4"; leaf "5"]; 
		       node "3" [leaf "6"; leaf "7"]])


let tree2 =
  let node s = Tree.node ~arrow_style:Undirected ~edge_style:HalfSquare (Box.tex s) in
  let leaf s = Tree.leaf (Box.tex s) in
  Tree.draw 
    (node "1" [node "2" [node "4" [leaf "8"]; leaf "5"]; 
	       node "3" [node "6" [leaf "9"; node "10" [leaf "12"; leaf "13"]]; 
			 node "7" [leaf "11"]]])

let _ =
  List.iter (fun (name,fig) -> Metapost.emit name fig)
  [ "hist1", hist1;
    "hist2", hist2;
    "hist3", hist3;
    "hist4", hist4;
    "hist5", hist5;
    "radar1",radar1;
    "radar2",radar2;
    "simple_block",simple_block;
    "interface",interface;
    "path1",path1;
    "path2",path2;
    "path3",path3;
    "path4",path4;
    "tree1",tree1;
    "tree2",tree2;
  ]
