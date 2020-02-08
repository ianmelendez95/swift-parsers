typealias Parser<A> = ((String) -> (A, String)?)

func sequence<A>(_ parser1: @escaping Parser<A>, _ parser2: @escaping Parser<A>) -> Parser<A> {
  return { input in
    if let (_, rest1) = parser1(input) {
      return parser2(rest1)
    } else {
      return nil
    }
  }
}

func char(_ char: Character) -> Parser<Character> {
  return satisfy({ c in c == char })
}

func satisfy(_ predicate: @escaping ((Character) -> Bool)) -> Parser<Character> {
  return { input in
    if let first = strHead(input) {
      if (predicate(first)) {
        return (first, strTail(input))
      } else {
        return nil
      }
    } else {
      return nil
    }
  }
}

func strHead(_ str: String) -> Character? {
  return str.first
}

func strTail(_ str: String) -> String {
  return String(str.dropFirst(1))
}

func testSequenced() {
  let hParser = char("h")
  let eParser = char("e")
  let sequenced = sequence(hParser, eParser)
  
  print(sequenced("hello")) // '("e", "llo")'
}
