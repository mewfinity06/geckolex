import gecko/lexer.{type Loc, Loc}

pub type Token {
  OParen
  CParen

  FatArrow
  SkinnyArrow

  Dot
  Spread
  Elipsis

  If
  Then
  Else

  Ident(String)
  Number(Int)
  Float(Float)
  Comment(String)
  String(String)

  Eof
}

pub fn loc(row, col) -> Loc {
  Loc("", row, col)
}
