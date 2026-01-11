import common.{loc} as c
import gleam/list
import gleam/option.{None, Some}
import gleeunit

import gecko/builder as b
import gecko/lexer

pub fn main() -> Nil {
  gleeunit.main()
}

fn lexer() {
  b.init()
  |> b.keywords([
    #("if", c.If),
    #("then", c.Then),
    #("else", c.Else),
  ])
  |> b.tokens([
    #("(", c.OParen),
    #(")", c.CParen),
    #("=>", c.FatArrow),
    #("->", c.SkinnyArrow),
    #(".", c.Dot),
    #("..", c.Spread),
    #("...", c.Elipsis),
  ])
  |> b.comment("//.*", c.Comment)
  |> b.ident("[a-zA-Z][a-zA-Z0-9_]*", c.Ident)
  |> b.float("[0-9][0-9_]*\\.[0-9_]+", c.Float)
  |> b.number("[0-9][0-9_]*", c.Number)
  |> b.string("([^\"]*(?:\\.[^\"\\]*)*)", c.String)
  |> b.compile(c.Eof)
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

pub fn multi_line_test() {
  let lexer = lexer()
  let source =
    "super big things
  oh a newline"
  let #(source, _loc, t1) = lexer.next(lexer, source, loc(0, 0))
  let #(source, _loc, t2) = lexer.next(lexer, source, loc(0, 0))
  let #(source, _loc, t3) = lexer.next(lexer, source, loc(0, 0))
  let #(source, _loc, t4) = lexer.next(lexer, source, loc(0, 0))
  let #(source, _loc, t5) = lexer.next(lexer, source, loc(0, 0))
  let #(source, _loc, t6) = lexer.next(lexer, source, loc(0, 0))
  assert source == ""
  assert t1 == c.Ident("super")
  assert t2 == c.Ident("big")
  assert t3 == c.Ident("things")
  assert t4 == c.Ident("oh")
  assert t5 == c.Ident("a")
  assert t6 == c.Ident("newline")
}

pub fn collect_test() {
  let lexer = lexer()
  let source =
    "super big things
  oh a newline"
  let tokens =
    lexer.collect(lexer, source, loc(0, 0), []) |> list.map(fn(tk) { tk.1 })
  assert tokens
    == [
      c.Ident("super"),
      c.Ident("big"),
      c.Ident("things"),
      c.Ident("oh"),
      c.Ident("a"),
      c.Ident("newline"),
      c.Eof,
    ]
}
