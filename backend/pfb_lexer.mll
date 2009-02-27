(* File lexer.mll *)
{
open Format
open Pfb_parser        (* The type token is defined in parser.mli *)

let incr_linenum lexbuf =
    let pos = lexbuf.Lexing.lex_curr_p in
    lexbuf.Lexing.lex_curr_p <- { pos with
      Lexing.pos_lnum = pos.Lexing.pos_lnum + 1;
      Lexing.pos_bol = pos.Lexing.pos_cnum;
    }

type state = |Header | Encoding | Charstring

let state = ref Header

}
let ident = (['.''-''_''a'-'z''A'-'Z''0'-'9'])+
let float = ['-']?['0'-'9']*'.'['0'-'9']+
let int = ['0'-'9']+

rule header_token = parse
  | "/Encoding" [^'\n']* '\n' [^'\n']* '\n' {incr_linenum lexbuf;
                                             incr_linenum lexbuf;
                                             state:=Encoding; DUMB}
  | [^'\n']* '\n' {incr_linenum lexbuf;
                   header_token lexbuf}
  | _ {eprintf "During header parsing\n"; failwith ""} 

and encoding_token = parse
  | "dup " (int as id) {ID_ENCODING (int_of_string id)}
  | ' '* '/' (ident as id) " put\n" {incr_linenum lexbuf;
                                NAME_ENCODING id}
  | "readonly" {shortcut_token lexbuf}
  | _ {eprintf "During encoding parsing@."; failwith ""} 

and shortcut_token = parse
  | [^'/']* "/CharStrings" [^'\n']* '\n' {incr_linenum lexbuf;
                                  state:=Charstring; DUMB}
  | [^'\n']* '\n' {incr_linenum lexbuf;
                   shortcut_token lexbuf}
  | _ {eprintf "During middle parsing@.";failwith ""} 

and charstring_token = parse
  | '/' (ident as id) [^'{']* '{' [^'}']* '}' [^'\n']* '\n' 
      {incr_linenum lexbuf;
       NAME_CHARSTRING id}
  | '\n' {charstring_token lexbuf}
  | "end" {end_token lexbuf}
  | _ {eprintf "During charstring parsing@."; failwith ""} 

and end_token = parse
  | _* eof {state:=Header; DUMB}
  | _ {eprintf "During end parsing@."; failwith ""} 

and enc_token = parse
  | '%' [^'\n']* '\n' {incr_linenum lexbuf; enc_token lexbuf}
  | '/' [^'[']* '[' '\n' {incr_linenum lexbuf; DUMB}
  | '/' (ident as a) {NAME_ENCODING a}
  | ' '* '\n' {incr_linenum lexbuf; enc_token lexbuf}
  | ']' _* eof {DUMB}
{
let pfb_human_token x = match !state with
  |Header -> header_token x
  |Encoding -> encoding_token x
  |Charstring -> charstring_token x

}
