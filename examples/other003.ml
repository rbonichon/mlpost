open Path
open Command

let fig =
  let a =  -1. , -1. in
  let b =  1. , -1. in
  let c =  1. , 1. in
  let d =  -1. , 1. in
    [ draw (path ~style:jLine ~scale:Num.cm ~cycle:jLine [a;b;c;d]) ;
      draw (path ~scale:Num.cm [a;c]);
      draw (path ~scale:Num.cm [b;d]);
      ]


