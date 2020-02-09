typealias ParserFunction<A> = ((String) -> (A, String)?)

class Parser<A> {
  let parseFunc: ParserFunction<A>

  init(_ parseFunc: @escaping ParserFunction<A>) {
    self.parseFunc = parseFunc
  }

  func parse(_ input: String) -> (A, String)? {
    return self.parseFunc(input)
  }
}

class Parsers {
  static func char(_ char: Character) -> Parser<Character> {
    return satisfy({ c in c == char })
  }

  static func satisfy(_ predicate: @escaping ((Character) -> Bool)) 
                     -> Parser<Character> {
    return Parser({ input in
      if let first = strHead(input) {
        if (predicate(first)) {
          return (first, strTail(input))
        }
      }

      return nil
    })
  }

  static func strNull(_ str: String) -> Bool {
    return str.count == 0
  }

  static func strHead(_ str: String) -> Character? {
    return str.first
  }

  static func strTail(_ str: String) -> String {
    return String(str.dropFirst(1))
  }

  static func charsToString(_ chars: [Character]) -> String {
    return String(chars)
  }
}
