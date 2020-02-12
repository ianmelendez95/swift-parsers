class Parser<A> {
  let parseFunc: ((String) -> ParseResult<A>)

  init(_ parseFunc: @escaping ((String) -> ParseResult<A>)) {
    self.parseFunc = parseFunc
  }

  func name(_ message: String) -> Parser<A> {
    return Parser({ input in
      return self.parse(input)
                 .mapFailure({ msg in message + " >> " + msg })
    })
  }

  func parse(_ input: String) -> ParseResult<A> {
    return self.parseFunc(input)
  }

  func surroundedBy<B>(_ bound: Parser<B>) -> Parser<A> {
    return self.between(bound, bound)
  }

  func between<B,C>(_ bra: Parser<B>, _ ket: Parser<C>) -> Parser<A> {
    return bra.then(self).precedes(ket)
  }

  func token() -> Parser<A> {
    return self.skipOptional(Parsers.spaces())
  }

  func then<B>(_ parser: Parser<B>) -> Parser<B> {
    return Parser<B>({ input in
      self.parse(input).flatMapSuccess({ _, restOfInput in 
        parser.parse(restOfInput)
      })
    })
  }

  func skipOptional<B>(_ parser: Parser<B>) -> Parser<A> {
    return self.precedes(Parsers.alternate(parser.void(), 
                                           Parsers.null()))
  }

  func void() -> Parser<Void> {
    return self.then(Parsers.null())
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

  func some() -> Parser<[A]> {
    return Parser<[A]>({ input in 
      return self.many().parse(input).flatMapSuccess({ value, restOfInput in 
        self.name("some")
            .parse(input)
            .flatMapSuccess({ value, restOfInput in 
              self.many().parse(restOfInput)
                  .mapValue({ values in Parser.cons(value, values) })
            })
      })
    })
  }

  func fail<B>() -> Parser<B> {
    return self.then(Parsers.fail())
  }

  static func cons<A>(_ elem: A, _ arr: [A]) -> [A] {
    var newArr = arr
    newArr.insert(elem, at: 0)
    return newArr
  }
}

class Parsers {
  static func stringLiteral() -> Parser<String> {
    let escapedQuotes = Parsers.string("\\\"")
    let nonQuote = Parsers.satisfy({ c in c != "\"" }).map(charToString)
    let content = 
      Parsers.alternate(escapedQuotes, nonQuote).many().map(strConcat)

    return content.surroundedBy(Parsers.char("\""))
  }

  static func delayed<A>(_ parserFunc: @escaping (() -> Parser<A>)) -> Parser<A> {
    return Parser<A>({ input in 
      return parserFunc().parse(input)
    })
  }

  static func natural() -> Parser<Int> {
    return Parsers.digit().some()
                  .map(charsToString)
                  .map({ numStr in Int(numStr)! })
  }

  static func choice<A>(_ parsers: [Parser<A>]) -> Parser<A> {
    return foldr( { parser, acc in Parsers.alternate(parser, acc) }
                , Parsers.fail()
                , parsers)
  }

  static func alternate<A>(_ parser1: Parser<A>, _ parser2: Parser<A>) 
                          -> Parser<A> {
    return Parser<A>({ input in
      return parser1.parse(input)
                    .flatMapFailure({ _ in parser2.parse(input) })
    })
  }

  static func string(_ str: String) -> Parser<String> {
    return Parser<String>({ input in 
      return input.hasPrefix(str) ? .Success(str, strDrop(input, str.count))
                                  : .Failure(genFailureMessage(input))
    })
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

  static func digit() -> Parser<Character> { 
    return satisfy({ c in c.isNumber })
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

  static func fail<A>() -> Parser<A> {
    return Parser({ input in .Failure(genFailureMessage(input)) })
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
      return "Failed at char '\(String(strHead(input)!))'"
              + " in \"\(strTake(input, 20))\""
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

  static func strTake(_ str: String, _ num: Int) -> String {
    return String(str.prefix(num))
  }

  static func strDrop(_ str: String, _ num: Int) -> String {
    return String(str.dropFirst(num))
  }

  static func strConcat(_ strs: [String]) -> String {
    var curStr = ""
    for str in strs {
      curStr = curStr + str
    }
    return curStr
  }

  static func charToString(_ char: Character) -> String {
    return String(char)
  }

  static func charsToString(_ chars: [Character]) -> String {
    return String(chars)
  }

  static func foldr<A,B>(_ foldFunc: ((A, B) -> B),
                         _ initValue: B,
                         _ arr: [A]) 
                        -> B {
    var acc = initValue
    for item in arr.reversed() {
      acc = foldFunc(item, acc)
    }
    return acc
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

  func mapFailure(_ failureFunc: ((String) -> String)) -> ParseResult<A> {
    return flatMapFailure({ msg in .Failure(failureFunc(msg)) })
  }

  func flatMapSuccess<B>(_ successMap: ((A, String) -> ParseResult<B>)) 
                         -> ParseResult<B> {
    return flatMapEither(successMap, { msg in .Failure(msg) })
  }

  func flatMapFailure(_ failureMap: ((String) -> ParseResult<A>)) 
                     -> ParseResult<A> {
    return flatMapEither(
      { value, restOfInput in .Success(value, restOfInput) },
      { failureMsg in failureMap(failureMsg) })
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

class ParserTests {
  static func testAlternate() {
    let hParser = Parsers.char("h")
    let bParser = Parsers.char("b")

    print(Parsers.alternate(hParser, bParser).parse("bye world"))
    return
  }

  static func testChoice() {
    let aParser = Parsers.char("a")
    let bParser = Parsers.char("b")
    let cParser = Parsers.char("c")
    let dParser = Parsers.char("d")

    print(Parsers.choice([ aParser
                         , bParser
                         , cParser
                         , dParser]).parse("bye world"))
    return
  }
}
