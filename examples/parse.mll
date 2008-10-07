{
  open Lexing

  let togglescript = 
    "<script type=\"text/javascript\">
<!--
    function toggle_visibility(id) {
       var e = document.getElementById(id);
       if(e.style.display == 'block')
          e.style.display = 'none';
       else
          e.style.display = 'block';
    }
//-->
</script>"
}

let alpha_lower = ['a'-'z' ]
let alpha_upper = ['A'-'Z']
let alpha = ['a' - 'z' 'A'-'Z']
let digit = ['0'-'9']
let identifier = alpha_lower (alpha | digit | '\'' | '_')*
let blank = [' ' '\t' '\n' '\r' ]

rule scan = parse
  | "<<togglescript>>" { Printf.printf "%s" togglescript; scan lexbuf }
  | ">>" { Printf.printf "</p> </div><hr>"; scan lexbuf }
  | "<<" (identifier as i)
      { 
        Printf.printf "<p><img src=\"%s.png\" /></p>" i;
        Printf.printf "<a href=\"javascript:toggle_visibility('%s')\">show/hide code</a>" i;
        Printf.printf "<div id=\"%s\" style='display:none;'>" i;
        Printf.printf "<p>";
        scan lexbuf
      }
  | blank { scan lexbuf }
  | eof { Printf.printf "%!" }


{
let _ = 
  let buf = Lexing.from_channel stdin in
  scan buf

}
