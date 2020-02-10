class Parser<A> {
  let parseFunc: ((String) -> ParseResult<A>)

  init(_ parseFunc: @escaping ((String) -> ParseResult<A>)) {
    self.parseFunc = parseFunc
  }

  func parse(_ input: String) -> ParseResult<A> {
    return self.parseFunc(input)
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
