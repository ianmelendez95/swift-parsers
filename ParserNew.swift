class HtmlParserExample {
  typealias EmptyHtmlTag = (String, [String: String]) // (tag name, attributes)

  static let emptyHtmlTag: Parser<EmptyHtmlTag> = {
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

  static func testEmptyHtmlTag() {
    print(emptyHtmlTag.parse("<input type=\"text\" value=\"hello world!\"/>"))
  }

  static func pairsToDict<A,B>(_ pairs: [(A,B)]) -> [A:B] {
    var dict: [A:B] = [:]
    for (key, value) in pairs {
      dict[key] = value
    }
    return dict
  }

  static func testPairsToDict() {
    print(pairsToDict([("x", 1), ("y", 2)]))
  }

  static let tagAttribute: Parser<(String, String)> = {
    let key = Parsers.letters().token()

    let equals = Parsers.char("=")
    
    let valueContent = 
      Parsers.asString(Parsers.satisfy({ c in c != "\"" }).many())
    let value = valueContent.surroundedBy(Parsers.char("\""))

    return key.flatMap({ keyStr in 
              equals.then(value.map({ valueStr in (keyStr, valueStr) }))
            })
  }()

  static func testTagAttribute() { 
    print(tagAttribute.parse("type=\"text\""))
  }
}

class Parser<A> {
  let parseFunc: ((String) -> ParseResult<A>)

  init(_ parseFunc: @escaping ((String) -> ParseResult<A>)) {
    self.parseFunc = parseFunc
  }

  func parse(_ input: String) -> ParseResult<A> {
    return self.parseFunc(input)
  }

  func surroundedBy<B>(_ bound: Parser<B>) -> Parser<A> {
    return bound.then(self).precedes(bound)
  }

  func token() -> Parser<A> {
    return self.precedes(Parsers.spaces())
  }

  func then<B>(_ parser: Parser<B>) -> Parser<B> {
    return Parser<B>({ input in
      self.parse(input).flatMapSuccess({ _, restOfInput in 
        parser.parse(restOfInput)
      })
    })
  }

  func precedes<B>(_ follows: Parser<B>) -> Parser<A> {
    return Parser<A>({ input in 
      self.parse(input).flatMapSuccess({ value, restOfInput in 
        follows.parse(restOfInput).mapValue({ _ in value })
      })
    })
  }

  func map<B>(_ mapFunc: @escaping ((A) -> B)) -> Parser<B> {
    return Parser<B>({ input in
      self.parse(input).mapValue(mapFunc)
    })
  }

  func flatMap<B>(_ boundParserFunc: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return Parser<B>({ input in 
      self.parse(input).flatMapSuccess({ value, restOfInput in
        boundParserFunc(value).parse(restOfInput)
      })
    })
  }

  func many() -> Parser<[A]> { 
    return Parser<[A]>({ input in
      self.parse(input)
          .flatMapEither(
            { value, restOfInput in 
               self.many().parse(restOfInput)
                          .mapValue({ values in Parser.cons(value, values) })
            }, 
            { _ in .Success([], input) })
    })
  }

  static func cons<A>(_ elem: A, _ arr: [A]) -> [A] {
    var newArr = arr
    newArr.insert(elem, at: 0)
    return newArr
  }
}

class Parsers {
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
          return .Success(first, strTail(input))
        }
      }

      return .Failure(genFailureMessage(input))
    })
  }

  static func null() -> Parser<Void> {
    return Parser({ input in .Success((), input) })
  }

  static func asString(_ parser: Parser<[Character]>) -> Parser<String> {
    return parser.map(charsToString)
  }

  static func genFailureMessage(_ input: String) -> String {
    if strNull(input) {
      return "Exhausted input"
    } else {
      return "Failed at char '" 
              + String(strHead(input)!)
              + "' in \"" 
              + strTail(input)
              + "\""
    }
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

enum ParseResult<A> {
  case Success(A, String)
  case Failure(String)

  func mapValue<B>(_ mapFunc: ((A) -> B)) -> ParseResult<B> {
    return flatMapSuccess({ value, restOfInput in 
      .Success(mapFunc(value), restOfInput) 
    })
  }

  func flatMapSuccess<B>(_ successMap: ((A, String) -> ParseResult<B>)) 
                         -> ParseResult<B> {
    return flatMapEither(successMap, { msg in .Failure(msg) })
  }

  func flatMapEither<B>(_ successMap: ((A, String) -> ParseResult<B>),
                        _ failureMap: ((String) -> ParseResult<B>)) 
                        -> ParseResult<B> {
    switch self {
      case .Success(let value, let restOfInput):
        return successMap(value, restOfInput)
      case .Failure(let msg):
        return failureMap(msg)
    }
  }
}
