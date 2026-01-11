import common.{loc} as c
import gecko/lexer.{Lexer, gen_naked, gen_rule}
import gleam/float
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
      // Float rule must come before dot and number
      gen_rule("[0-9]+\\.[0-9]+", fn(s) {
        case float.parse(s) {
          Ok(f) -> c.Float(f)
          Error(_) -> c.Float(0.0)
        }
      }),
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

pub fn next_paren_test() {
  let lexer = lexer()
  assert lexer.next(lexer, "(", loc(0, 0)) == #("", loc(0, 1), c.OParen)
}

pub fn float_test() {
  let lexer = lexer()
  assert lexer.next(lexer, "12.34", loc(0, 0))
    == #("", loc(0, 5), c.Float(12.34))
}

pub fn next_empty_is_eof_test() {
  let lexer = lexer()
  assert lexer.next(lexer, "", loc(0, 0)) == #("", loc(0, 0), c.Eof)
}

pub fn next_unmatched_is_none_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "@", loc(0, 1)) == None
}

pub fn next_identifier_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "hello", loc(0, 0))
    == Some(#("", loc(0, 5), c.Ident("hello")))
}

pub fn next_identifier_with_underscore_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "hello_world123", loc(0, 0))
    == Some(#("", loc(0, 14), c.Ident("hello_world123")))
}

pub fn next_number_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "123", loc(0, 0))
    == Some(#("", loc(0, 3), c.Number(123)))
}

pub fn next_number_with_underscore_test() {
  let lexer = lexer()
  // Note: int.parse will handle "1_234_567" but the actual parsed value is 1234567
  assert lexer.next_opt(lexer, "1234567", loc(0, 0))
    == Some(#("", loc(0, 7), c.Number(1_234_567)))
}

pub fn whitespace_is_skipped_test() {
  let lexer = lexer()
  assert lexer.next_opt(lexer, "   hello", loc(0, 0))
    == Some(#("", loc(0, 8), c.Ident("hello")))
}

pub fn get_many_tokens_test() {
  let lexer = lexer()
  let source = "() hello 223"
  let #(source, loc, t1) = lexer.next(lexer, source, loc(0, 0))
  let #(source, loc, t2) = lexer.next(lexer, source, loc)
  let #(source, loc, t3) = lexer.next(lexer, source, loc)
  let #(source, _, t4) = lexer.next(lexer, source, loc)
  assert source == ""
  assert t1 == c.OParen
  assert t2 == c.CParen
  assert t3 == c.Ident("hello")
  assert t4 == c.Number(223)
}

pub fn same_start_test() {
  let lexer = lexer()
  let source = ". .. ... ... . .."
  let #(source, loc, t1) = lexer.next(lexer, source, loc(0, 0))
  let #(source, loc, t2) = lexer.next(lexer, source, loc)
  let #(source, loc, t3) = lexer.next(lexer, source, loc)
  let #(source, loc, t4) = lexer.next(lexer, source, loc)
  let #(source, loc, t5) = lexer.next(lexer, source, loc)
  let #(source, _, t6) = lexer.next(lexer, source, loc)
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
  let #(source, loc, t1) = lexer.next(lexer, source, loc(0, 0))
  let #(source, loc, t2) = lexer.next(lexer, source, loc)
  let #(source, loc, t3) = lexer.next(lexer, source, loc)
  let #(source, loc, t4) = lexer.next(lexer, source, loc)
  let #(source, loc, t5) = lexer.next(lexer, source, loc)
  let #(source, _, t6) = lexer.next(lexer, source, loc)
  assert source == ""
  assert t1 == c.If
  assert t2 == c.Ident("x")
  assert t3 == c.Then
  assert t4 == c.Ident("y")
  assert t5 == c.Else
  assert t6 == c.Ident("z")
}
