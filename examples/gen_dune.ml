(* Generate dune file for the examples *)
(*
 In order to add a new example `foo` from `foo.ml`
  - add the name `foo` in gen_dune.ml
  - touch `foo.dune.inc`
  - dune runtest --auto-promote
  - dune runtest --auto-promote
*)

(** mode general: generate the top rules *)
(** mode leaf: generate the leaf rules *)

let examples =
  ["boxes","";"paths","";(* "misc","" ;*)"tree","";"label","";"automata","";
   "hist","";"radar","";"real_plot","";"dot_dot","mlpost.dot";"color",""]

let mode_general () =
  List.iter (fun (file,libraries) ->
      Format.printf "; Generated by gen_dune.ml@\n";
      Format.printf "(include dune.%s.inc)@\n@." file;
      Format.printf "(executable (name %s) (modules %s) (libraries mlpost.options mlpost %s) (flags -linkall))@\n@\n" file file libraries;
      Format.printf "(rule (with-stdout-to %s.figures (run ./%s.exe -dumpable)))@\n@\n" file file;
      Format.printf "(rule (with-stdout-to dune.%s.inc.gen (run ./gen_dune.exe leaf %s %%{read-lines:%s.figures})))@]@\n@\n" file file file;
      Format.printf "(alias (name promote) (action (diff dune.%s.inc dune.%s.inc.gen)))@\n" file file;
    ) examples

let kinds = [
  "ps_"       , ".mps", ".png", "-ps";
  "mps_"      , ".mps", ".png", "-mps";
  "png_cairo_", ".png", ".png", "-png -cairo";
  "pdf_cairo_", ".pdf", ".png", "-pdf -cairo";
  "svg_cairo_", ".svg", ".svg", "-svg -cairo";
  "pgf_"      , ".pgf", ".png", "-pgf";
]


let mode_leaf () =
  let file = Sys.argv.(2) in
  let figures = Array.sub Sys.argv 3 (Array.length Sys.argv - 3) in
  let iter_figures f = Array.iter f figures in
  let print_figures ?(prefix="") ?(suffix="") fmt =
    iter_figures (fun figure ->
        Format.fprintf fmt " %s%s%s" prefix figure suffix
      )
  in
  Format.printf "; Generated by gen_dune.ml@\n";
  (* create figure *)
  let gen ~prefix ~suffix options =
    Format.printf "(rule (targets %t) (deps %s.exe) (action (run ./%s.exe %s -prefix \"%s\")))@\n@."
      (print_figures ~prefix ~suffix) file file options prefix in
  List.iter (fun (prefix,suffix,_,options) -> gen ~prefix ~suffix options) kinds;
  (* pdf -> png *)
  let pdf_to_png prefix =
    iter_figures (fun figure ->
        Format.printf "(rule (targets %s%s.png) (deps %s%s.pdf) (action (run pdftoppm %%{deps} %s%s -png -singlefile)))@\n"
          prefix figure prefix figure prefix figure
      )
  in
  pdf_to_png "pdf_cairo_";
  pdf_to_png "mps_";
  pdf_to_png "ps_";
  pdf_to_png "pgf_";
  (* mps -> pdf *)
  let mps_to_pdf prefix =
    iter_figures (fun figure ->
        Format.printf "(rule (targets %s%s.pdf) (deps %s%s.mps) (action (ignore-outputs (run pdftex -halt-on-error -fmt=mptopdf \\relax %s%s.mps))))@\n" prefix figure prefix figure prefix figure
        (* Format.printf "(rule (targets %s%s.pdf) (deps all.template %s%s.mps) (action (ignore-outputs (run pdflatex -halt-on-error -jobname %s%s \"\\\\def\\\\filetoconvert{%s%s.mps}\\\\input{all.template}\"))))@\n" prefix figure prefix figure prefix figure prefix figure *)
      );
  in
  mps_to_pdf "mps_";
  mps_to_pdf "ps_";
  (* pgf -> pdf *)
  let pgf_to_pdf prefix =
    iter_figures (fun figure ->
        Format.printf "(rule (targets %s%s.pdf) (deps pgf.template %s%s.pgf) (action (ignore-outputs (run pdflatex -halt-on-error -jobname %s%s \"\\\\def\\\\filetoconvert{%s%s.pgf}\\\\input{pgf.template}\"))))@\n" prefix figure prefix figure prefix figure prefix figure
      );
  in
  pgf_to_pdf "pgf_";
  (* create html *)
  (* Format.printf "(rule (targets %s.ml.html) (deps %s.ml ./parse.exe) (action (run ./parse.exe %s.ml)))"
   *   file file file; *)
  (* build for runtest all the files needed *)
  (* Format.printf "(alias (name %s) (deps prototype.js style.css %s.ml.html%t))@\n@." *)
  Format.printf "(alias (name %s) (deps %t))@\n@."
    file
    (fun fmt -> List.iter (fun (prefix,_,suffix,_) -> print_figures ~prefix ~suffix fmt) kinds);
  Format.printf "(alias (name runtest) (deps (alias %s)))@\n@\n" file;
  ()

let () =
  if Sys.argv.(1) = "general"
  then mode_general ()
  else mode_leaf ();
  Format.printf "@."
