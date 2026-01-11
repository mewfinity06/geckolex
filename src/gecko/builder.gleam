import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

import gecko/lexer.{type Lexer, type TokenFn, Lexer}

pub type LiteralBuilder(tt) =
  #(String, tt)

pub type RegexBuilder(tt) =
  #(String, fn(String) -> tt)

pub opaque type Builder(tt) {
  Builder(
    keywords: List(LiteralBuilder(tt)),
    tokens: List(LiteralBuilder(tt)),
    comment: Option(RegexBuilder(tt)),
    ident: Option(RegexBuilder(tt)),
    float: Option(RegexBuilder(tt)),
    number: Option(RegexBuilder(tt)),
    string: Option(RegexBuilder(tt)),
    regexes: List(RegexBuilder(tt)),
  )
}

/// Initialize a new empty Builder.
pub fn init() -> Builder(tt) {
  Builder(
    keywords: [],
    tokens: [],
    comment: None,
    ident: None,
    float: None,
    number: None,
    string: None,
    regexes: [],
  )
}

/// Set the list of keyword tokens for the builder.
///
/// Keywords are matched as literal strings.
pub fn keywords(
  builder: Builder(tt),
  list: List(LiteralBuilder(tt)),
) -> Builder(tt) {
  Builder(..builder, keywords: list)
}

/// Set the list of non-keyword literal tokens for the builder.
///
/// Tokens are matched as literal strings.
pub fn tokens(
  builder: Builder(tt),
  list: List(LiteralBuilder(tt)),
) -> Builder(tt) {
  Builder(..builder, tokens: list)
}

/// Set the comment regex for the builder.
///
/// The regex is used to match comments in the input.
pub fn comment(
  builder: Builder(tt),
  regex: String,
  token: fn(String) -> tt,
) -> Builder(tt) {
  Builder(..builder, comment: Some(#(regex, token)))
}

/// Set the identifier regex for the builder.
///
/// The regex is used to match identifiers in the input.
pub fn ident(
  builder: Builder(tt),
  regex: String,
  token: fn(String) -> tt,
) -> Builder(tt) {
  Builder(..builder, ident: Some(#(regex, token)))
}

/// Set a universal float-matching regex for the builder.
///
/// The regex is used to match floats as strings, and the token function receives the matched string.
pub fn float_universal(
  builder: Builder(tt),
  regex: String,
  token: fn(String) -> tt,
) -> Builder(tt) {
  Builder(..builder, number: Some(#(regex, token)))
}

/// Set the float regex for the builder.
///
/// The regex is used to match floats, and the token function receives a parsed Float.
pub fn float(
  builder: Builder(tt),
  regex: String,
  float: fn(Float) -> tt,
) -> Builder(tt) {
  Builder(
    ..builder,
    float: Some(
      #(regex, fn(s) {
        let f = case float.parse(s) {
          Ok(f) -> f
          Error(_) -> panic as { "float: could not parse: " <> s }
        }
        float(f)
      }),
    ),
  )
}

/// Set a universal number-matching regex for the builder.
///
/// The regex is used to match numbers as strings, and the token function receives the matched string.
pub fn number_universal(
  builder: Builder(tt),
  regex: String,
  token: fn(String) -> tt,
) -> Builder(tt) {
  Builder(..builder, number: Some(#(regex, token)))
}

/// Set the number regex for the builder.
///
/// The regex is used to match numbers, and the token function receives a parsed Int.
pub fn number(
  builder: Builder(tt),
  regex: String,
  number: fn(Int) -> tt,
) -> Builder(tt) {
  Builder(
    ..builder,
    number: Some(
      #(regex, fn(s) {
        let n = case int.parse(s) {
          Ok(f) -> f
          Error(_) -> panic as { "number: could not parse: " <> s }
        }
        number(n)
      }),
    ),
  )
}

/// Set the string regex for the builder.
///
/// The regex is used to match string literals in the input.
pub fn string(
  builder: Builder(tt),
  regex: String,
  token: fn(String) -> tt,
) -> Builder(tt) {
  Builder(..builder, string: Some(#(regex, token)))
}

/// Set additional regex token matchers for the builder.
///
/// These regexes are tried after keywords and tokens.
pub fn regexes(
  builder: Builder(tt),
  regexes: List(RegexBuilder(tt)),
) -> Builder(tt) {
  Builder(..builder, regexes: regexes)
}

/// Compile the builder into a Lexer, returning a Result.
///
/// Returns `Ok(Lexer)` on success, or `Error(String)` if there is a problem.
pub fn compile_safe(builder: Builder(tt), eof: tt) -> Result(Lexer(tt), String) {
  // Get list types
  let keywords =
    builder.keywords
    |> list.sort(by: compare_literal_builders)
    |> list.map(with: lb_to_tokenfn)
  let tokens =
    builder.tokens
    |> list.sort(by: compare_literal_builders)
    |> list.map(with: lb_to_tokenfn)
  let regexes = builder.regexes |> list.map(with: rb_to_token_fn)
  // Get optional types
  let ident = case builder.ident {
    Some(i) -> [i |> rb_to_token_fn()]
    None -> []
  }
  let float = case builder.float {
    Some(i) -> [i |> rb_to_token_fn()]
    None -> []
  }
  let number = case builder.number {
    Some(i) -> [i |> rb_to_token_fn()]
    None -> []
  }
  let string = case builder.string {
    Some(i) -> [i |> rb_to_token_fn()]
    None -> []
  }
  // Build List(tt)
  //  [ Keywords, tokens, regexes, ident, float, number, string ]
  let toks = []
  let toks = list.append(toks, keywords)
  let toks = list.append(toks, tokens)
  let toks = list.append(toks, regexes)
  let toks = list.append(toks, ident)
  let toks = list.append(toks, float)
  let toks = list.append(toks, number)
  let toks = list.append(toks, string)
  // Ensure eof and return
  Ok(Lexer(toks, eof))
}

/// Compile the builder into a Lexer, panicking on error.
///
/// Returns a Lexer, or panics if there is a problem.
pub fn compile(builder: Builder(tt), eof: tt) -> Lexer(tt) {
  case compile_safe(builder, eof) {
    Ok(l) -> l
    Error(e) -> panic as e
  }
}

// HELPER FUNCTIONS
fn compare_literal_builders(
  l1: LiteralBuilder(tt),
  l2: LiteralBuilder(tt),
) -> order.Order {
  let #(s1, _) = l1
  let #(s2, _) = l2
  let l1_len = string.length(s1)
  let l2_len = string.length(s2)
  int.compare(l2_len, l1_len)
}

fn lb_to_tokenfn(l: LiteralBuilder(tt)) -> TokenFn(tt) {
  let #(s, l) = l
  lexer.gen_naked(s, fn(_) { l })
}

fn rb_to_token_fn(r: RegexBuilder(tt)) -> TokenFn(tt) {
  let #(s, f) = r
  lexer.gen_rule(s, f)
}
