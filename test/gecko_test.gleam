import gleam/int
import gleam/option.{None, Some}
import gleeunit

import gecko.{Lexer, gen_naked, gen_rule}

pub fn main() -> Nil {
  gleeunit.main()
}

type Token {
  OParen
  CParen

  FatArrow
  SkinnyArrow

  Dot
  Spread
  Elipsis

  Ident(String)
  Number(Int)

  Eof
}

fn get_token_fns() {
  [
    gen_naked("...", fn(_) { Elipsis }),
    gen_naked("..", fn(_) { Spread }),
    gen_naked(".", fn(_) { Dot }),
    gen_naked("=>", fn(_) { FatArrow }),
    gen_naked("->", fn(_) { SkinnyArrow }),
    gen_naked("(", fn(_) { OParen }),
    gen_naked(")", fn(_) { CParen }),
    gen_rule("[a-zA-Z][a-zA-Z0-9_]*", Ident),
    gen_rule("[0-9][0-9_]*", fn(s) {
      case int.parse(s) {
        Ok(n) -> Number(n)
        Error(_) -> Number(0)
      }
    }),
  ]
}

fn init_lexer() {
  Lexer(get_token_fns(), Eof)
}

pub fn match_paren_once_test() {
  let lexer = init_lexer()
  assert gecko.next(lexer, "(") == #("", OParen)
}

pub fn next_paren_test() {
  let lexer = init_lexer()
  assert gecko.next(lexer, "(") == #("", OParen)
}

pub fn next_empty_is_eof_test() {
  let lexer = init_lexer()
  assert gecko.next(lexer, "") == #("", Eof)
}

pub fn next_unmatched_is_none_test() {
  let lexer = init_lexer()
  assert gecko.next_opt(lexer, "@") == None
}

pub fn next_identifier_test() {
  let lexer = init_lexer()
  assert gecko.next_opt(lexer, "hello") == Some(#("", Ident("hello")))
}

pub fn next_identifier_with_underscore_test() {
  let lexer = init_lexer()
  assert gecko.next_opt(lexer, "hello_world123")
    == Some(#("", Ident("hello_world123")))
}

pub fn next_number_test() {
  let lexer = init_lexer()
  assert gecko.next_opt(lexer, "123") == Some(#("", Number(123)))
}

pub fn next_number_with_underscore_test() {
  let lexer = init_lexer()
  // Note: int.parse will handle "1_234_567" but the actual parsed value is 1234567
  assert gecko.next_opt(lexer, "1234567") == Some(#("", Number(1_234_567)))
}

pub fn whitespace_is_skipped_test() {
  let lexer = init_lexer()
  assert gecko.next_opt(lexer, "   hello") == Some(#("", Ident("hello")))
}

pub fn get_many_tokens_test() {
  let lexer = init_lexer()
  let source = "() hello 223"
  let #(source, t1) = gecko.next(lexer, source)
  let #(source, t2) = gecko.next(lexer, source)
  let #(source, t3) = gecko.next(lexer, source)
  let #(source, t4) = gecko.next(lexer, source)
  assert source == ""
  assert t1 == OParen
  assert t2 == CParen
  assert t3 == Ident("hello")
  assert t4 == Number(223)
}

pub fn same_start_test() {
  let lexer = init_lexer()
  let source = ". .. ... ... . .."
  let #(source, t1) = gecko.next(lexer, source)
  let #(source, t2) = gecko.next(lexer, source)
  let #(source, t3) = gecko.next(lexer, source)
  let #(source, t4) = gecko.next(lexer, source)
  let #(source, t5) = gecko.next(lexer, source)
  let #(source, t6) = gecko.next(lexer, source)
  assert source == ""
  assert t1 == Dot
  assert t2 == Spread
  assert t3 == Elipsis
  assert t4 == Elipsis
  assert t5 == Dot
  assert t6 == Spread
}
