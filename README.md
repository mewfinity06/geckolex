# gecko

A simple lexer library for Gleam supporting literal string matching and basic regex patterns.

[![Package Version](https://img.shields.io/hexpm/v/geckolex)](https://hex.pm/packages/geckolex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/geckolex/)

```sh
gleam add geckolex
```

## Quick Start

```gleam
import gecko.{type TokenFn, Lexer, gen_naked, gen_rule}

type TokenType {
  OParen // (
  CParen // )
  OBrack // {
  CBrack // }

  SkinnyArrow // ->
  FatArrow    // =>

  Elipsis // ...
  Dot     // .

  Ident(String)
  Number(Int)

  Eof
}

fn get_lexer() {
  Lexer([
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
  ], Eof)
}

pub fn main() -> Nil {
  let lexer = get_lexer()
  let source = "hello world"
  let #(source, t1) = gecko.next(lexer, source)
  let #(source, t2) = gecko.next(lexer, source)
}

```

## Features

- **Literal string matching**: Use `gen_naked` to match exact strings like `"("`, `"=>"`, etc.
- **Regex patterns**: Use `gen_rule` to match regex patterns with support for:
  - Character classes: `[a-z]`, `[A-Z]`, `[0-9]`, `[a-zA-Z0-9_]`
  - Quantifiers: `*` (zero or more), `+` (one or more)
- **Token construction**: Pass constructor functions to capture matched text in your tokens
- **Ordered matching**: Token functions are tried in order; the first match wins

Further documentation can be found at <https://hexdocs.pm/gecko>.

## Development

```sh
gleam test  # Run the tests
```
