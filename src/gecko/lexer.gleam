import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/string

/// Metadata about how a token was matched.
/// 
/// - `Rule`: Token was matched using a regex pattern
/// - `Naked`: Token was matched using a literal string
pub type Naked {
  Rule(regex: String)
  Naked
}

/// Internal wrapper type for tokens matched by token functions.
/// 
/// This type is public for use in type signatures but should not be 
/// exposed directly to library users. Use the `next` function instead,
/// which automatically unwraps tokens.
/// 
/// Stores the matched text and metadata about how it was matched.
pub type Token(tt) {
  Token(wrapper: Naked, token_type: fn(String) -> tt, word: String)
}

/// A function that attempts to match a token at the start of input.
/// 
/// Takes:
/// - `input`: The input string to match against
/// - `check`: Additional context (currently unused)
/// - `constructor`: Function to construct token (currently unused)
/// 
/// Returns `Some(#(remaining, wrapper))` if matched, `None` otherwise.
pub type TokenFn(tt) =
  fn(String, String, fn(String) -> tt) -> Option(#(String, Token(tt)))

/// Creates a token function that matches a literal string.
/// 
/// ## Example
/// 
/// ```gleam
/// let lparen = gen_naked("(", fn(_) { OParen })
/// ```
/// 
/// ## Parameters
/// 
/// - `s`: The literal string to match
/// - `constructor`: Function that takes matched text and returns a token
/// 
/// ## Returns
/// 
/// A `TokenFn` that matches the literal string at the start of input.
pub fn gen_naked(s: String, constructor: fn(String) -> tt) -> TokenFn(tt) {
  fn(input: String, _check: String, _ret: fn(String) -> tt) -> Option(
    #(String, Token(tt)),
  ) {
    let s_len = string.length(s)
    let input_len = string.length(input)
    case s_len <= input_len && string.starts_with(input, s) {
      True ->
        Some(#(string.drop_start(input, s_len), Token(Naked, constructor, s)))
      False -> None
    }
  }
}

/// Creates a token function that matches a regex pattern.
/// 
/// Uses the `gleam_regexp` library for regex matching.
/// Supports standard regex syntax as provided by the library.
/// 
/// ## Example
/// 
/// ```gleam
/// let identifier = gen_rule("[a-zA-Z][a-zA-Z0-9_]*", Ident)
/// let number = gen_rule("[1-9][0-9]*", fn(s) { Number(parse_int(s)) })
/// ```
/// 
/// ## Parameters
/// 
/// - `regex`: A regex pattern string
/// - `constructor`: Function that takes matched text and returns a token
/// 
/// ## Returns
/// 
/// A `TokenFn` that matches the regex pattern at the start of input.
pub fn gen_rule(regex: String, constructor: fn(String) -> tt) -> TokenFn(tt) {
  fn(input: String, _check: String, _ret: fn(String) -> tt) -> Option(
    #(String, Token(tt)),
  ) {
    case regexp.compile(regex, regexp.Options(False, False)) {
      Ok(compiled) -> {
        case regexp.scan(compiled, input) {
          [match, ..] -> {
            case string.starts_with(input, match.content) {
              True -> {
                let matched_text = match.content
                let remaining =
                  string.drop_start(input, string.length(matched_text))
                Some(#(remaining, Token(Rule(regex), constructor, matched_text)))
              }
              False -> None
            }
          }
          _ -> None
        }
      }
      Error(_) -> None
    }
  }
}

/// A lexer that tokenizes input strings.
/// 
/// ## Fields
/// 
/// - `toks`: List of token functions to try in order
/// - `eof`: Token value to return when input is empty
/// 
/// ## Example
/// 
/// ```gleam
/// let lexer = Lexer([
///   gen_naked("(", OParen),
///   gen_naked(")", CParen),
///   gen_rule("[a-zA-Z]+", Ident("")),
/// ], Eof)
/// ```
pub type Lexer(tt) {
  Lexer(toks: List(TokenFn(tt)), eof: tt)
}

/// Attempt to read the next token from the start of `source`.
/// - If `source` is empty, returns `Some(#(source, eof))`.
/// - Otherwise, tries each token function in order and returns the first match.
/// - If no token matches the current input, returns `None`.
pub fn next_opt(lexer: Lexer(tt), source: String) -> Option(#(String, tt)) {
  let Lexer(toks, eof) = lexer
  let trimmed = string.trim_start(source)
  case string.is_empty(trimmed) {
    True -> Some(#(trimmed, eof))
    False -> try_toks(toks, trimmed, eof)
  }
}

/// Attempt to read the next token from the start of `source`.
/// - If `source` is empty, returns `#("", eof)`.
/// - Otherwise, tries each token function in order and returns the first match.
/// - If no token matches the current input, returns `#("", eof)`.
pub fn next(lexer: Lexer(tt), source: String) -> #(String, tt) {
  case next_opt(lexer, source) {
    Some(#(source, tk)) -> #(source, tk)
    None -> #("", lexer.eof)
  }
}

fn try_toks(
  toks: List(TokenFn(tt)),
  source: String,
  eof: tt,
) -> Option(#(String, tt)) {
  case toks {
    [] -> None
    [f, ..rest] ->
      case f(source, "", fn(_) { eof }) {
        Some(#(remaining, Token(_, constructor, word))) -> {
          let token = constructor(word)
          Some(#(remaining, token))
        }
        None -> try_toks(rest, source, eof)
      }
  }
}
