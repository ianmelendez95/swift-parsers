
typealias EmptyHtmlTag = (String, [String: String]) // (tag name, attributes)

let emptyHtmlTag: Parser<EmptyHtmlTag> = {
  let openBracket = Parsers.char("<")
  let attributes: Parser<[String: String]> = 
    tagAttribute.token().many().map({ attributes in pairsToDict(attributes) })
  let closeBracket = Parsers.char("/").then(Parsers.char(">"))

  let tagName = Parsers.letters().token()

  return openBracket
          .then(tagName.flatMap({ tagName in 
            attributes.precedes(closeBracket).map({ attrs in (tagName, attrs) })
          }))
}()

func testEmptyHtmlTag() {
  print(emptyHtmlTag.parse("<input type=\"text\" value=\"hello world!\"/>"))
}

func pairsToDict<A,B>(_ pairs: [(A,B)]) -> [A:B] {
  var dict: [A:B] = [:]
  for (key, value) in pairs {
    dict[key] = value
  }
  return dict
}

func testPairsToDict() {
  print(pairsToDict([("x", 1), ("y", 2)]))
}

let tagAttribute: Parser<(String, String)> = {
  let key = Parsers.letters().token()

  let equals = Parsers.char("=")
  
  let valueContent = 
    Parsers.asString(Parsers.satisfy({ c in c != "\"" }).many())
  let value = valueContent.quoted()

  return key.flatMap({ keyStr in 
            equals.then(value.map({ valueStr in (keyStr, valueStr) }))
          })
}()

func testTagAttribute() { 
  print(tagAttribute.parse("type=\"text\""))
}

typealias ParserFunction<A> = ((String) -> (A, String)?)

class Parser<A> {
  let parseFunc: ParserFunction<A>

  init(_ parseFunc: @escaping ParserFunction<A>) {
    self.parseFunc = parseFunc
  }

  func parse(_ input: String) -> (A, String)? {
    return self.parseFunc(input)
  }

  func quoted() -> Parser<A> {
    let quote = Parsers.char("\"")
    return quote.then(self).precedes(quote)
  }

  func then<B>(_ parser: Parser<B>) -> Parser<B> {
    return Parser<B>({ input in
      if let (_, rest1) = self.parse(input) {
        return parser.parse(rest1)
      } else {
        return nil
      }
    })
  }

  func token() -> Parser<A> {
    return self.precedes(Parsers.spaces())
  }

  func precedes<B>(_ follows: Parser<B>) -> Parser<A> {
    return Parser({ input in 
      if let (result1, rest1) = self.parse(input) {
        if let (_, rest2) = follows.parse(rest1) {
          return (result1, rest2)
        }
      }

      return nil
    })
  }

  func map<B>(_ mapFunc: @escaping ((A) -> B)) -> Parser<B> {
    return Parser<B>({ input in
      if let (result, rest) = self.parse(input) {
        return (mapFunc(result), rest)
      } else {
        return nil
      }
    })
  }

  func flatMap<B>(_ boundParserFunc: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return Parser<B>({ input in 
      if let (result, rest) = self.parse(input) {
        return boundParserFunc(result).parse(rest)
      } else {
        return nil
      }
    })
  }

  func many() -> Parser<[A]> {
    return Parser<[A]>({ input in
      var result: [A] = [] 
      var curInput = input
      while let (nextResult, nextInput) = self.parse(curInput) {
        result.append(nextResult)
        curInput = nextInput
      }

      return (result, curInput)
    })
  }
}

class Parsers {
  static func asString(_ parser: Parser<[Character]>) -> Parser<String> {
    return parser.map(charsToString)
  }

  static func spaces() -> Parser<Void> {
    return space().many().then(null())
  }

  static func space() -> Parser<Character> {
    return satisfy({ c in c.isWhitespace })
  }

  static func letters() -> Parser<String> {
    return asString(letter().many())
  }

  static func letter() -> Parser<Character> {
    return satisfy({ c in c.isLetter })
  }

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

  static func null() -> Parser<Void> {
    return Parser({ input in ((), input) })
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
