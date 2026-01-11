import common as c
import gecko/lexer.{Lexer, gen_naked, gen_rule}
import gleam/int
import gleam/option.{None, Some}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

fn lexer() {
  Lexer(
    [
      gen_naked("if", fn(_) { c.If }),
      gen_naked("then", fn(_) { c.Then }),
      gen_naked("else", fn(_) { c.Else }),
      gen_naked("...", fn(_) { c.Elipsis }),
      gen_naked("..", fn(_) { c.Spread }),
      gen_naked(".", fn(_) { c.Dot }),
      gen_naked("=>", fn(_) { c.FatArrow }),
      gen_naked("->", fn(_) { c.SkinnyArrow }),
      gen_naked("(", fn(_) { c.OParen }),
      gen_naked(")", fn(_) { c.CParen }),
      gen_rule("[a-zA-Z][a-zA-Z0-9_]*", c.Ident),
      gen_rule("[0-9][0-9_]*", fn(s) {
        case int.parse(s) {
          Ok(n) -> c.Number(n)
          Error(_) -> c.Number(0)
        }
      }),
    ],
    c.Eof,
  )
}

pub fn match_paren_once_test() {
  let lexer = lexer()
  assert lexer.next(lexer, "(") == #("", c.OParen)
}

pub fn next_paren_test() {
  let lexer = lexer()
  assert lexer.next(lexer, "(") == #("", c.OParen)
}

pub fn next_empty_is_eof_test() {
  let lexer = lexer()
  assert lexer.next(lexer, "") == #("", c.Eof)
}

pub fn next_unmatched_is_none_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "@") == None
}

pub fn next_identifier_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "hello") == Some(#("", c.Ident("hello")))
}

pub fn next_identifier_with_underscore_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "hello_world123")
    == Some(#("", c.Ident("hello_world123")))
}

pub fn next_number_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "123") == Some(#("", c.Number(123)))
}

pub fn next_number_with_underscore_test() {
  let lexer = lexer()
  // Note: int.parse will handle "1_234_567" but the actual parsed value is 1234567
  assert lexer.next_opt(lexer, "1234567") == Some(#("", c.Number(1_234_567)))
}

pub fn whitespace_is_skipped_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "   hello") == Some(#("", c.Ident("hello")))
}

pub fn get_many_tokens_test() {
  let lexer = lexer()
  let source = "() hello 223"
  let #(source, t1) = lexer.next(lexer, source)
  let #(source, t2) = lexer.next(lexer, source)
  let #(source, t3) = lexer.next(lexer, source)
  let #(source, t4) = lexer.next(lexer, source)
  assert source == ""
  assert t1 == c.OParen
  assert t2 == c.CParen
  assert t3 == c.Ident("hello")
  assert t4 == c.Number(223)
}

pub fn same_start_test() {
  let lexer = lexer()
  let source = ". .. ... ... . .."
  let #(source, t1) = lexer.next(lexer, source)
  let #(source, t2) = lexer.next(lexer, source)
  let #(source, t3) = lexer.next(lexer, source)
  let #(source, t4) = lexer.next(lexer, source)
  let #(source, t5) = lexer.next(lexer, source)
  let #(source, t6) = lexer.next(lexer, source)
  assert source == ""
  assert t1 == c.Dot
  assert t2 == c.Spread
  assert t3 == c.Elipsis
  assert t4 == c.Elipsis
  assert t5 == c.Dot
  assert t6 == c.Spread
}

pub fn keyword_test() {
  let lexer = lexer()
  let source = "if x then y else z"
  let #(source, t1) = lexer.next(lexer, source)
  let #(source, t2) = lexer.next(lexer, source)
  let #(source, t3) = lexer.next(lexer, source)
  let #(source, t4) = lexer.next(lexer, source)
  let #(source, t5) = lexer.next(lexer, source)
  let #(source, t6) = lexer.next(lexer, source)
  assert source == ""
  assert t1 == c.If
  assert t2 == c.Ident("x")
  assert t3 == c.Then
  assert t4 == c.Ident("y")
  assert t5 == c.Else
  assert t6 == c.Ident("z")
}
