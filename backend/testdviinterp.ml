open Format
open Dviinterp

module Dumb_device =
struct
  type t = unit
  let reset () = ()
  let fill_rect () _ _ _ _ = ()
  let draw_char () _ _ _ _ = ()
end

module Dumb_interp = Interp(Dumb_device)
  
let _ =
  Dumb_interp.set_debug true
  match Array.length Sys.argv with
    | 1 ->
	printf "Usage : dviinterp <file1.dvi> <file2.dvi> ...\n"
    | n ->
	for i = 1 to n-1 do
	  let s = Sys.argv.(i) in
          ignore (Dumb_interp.load_file s)
	done