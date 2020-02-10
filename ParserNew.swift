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
}

enum ParseResult<A> {
  case Success(A, String)
  case Failure(String)

  func flatMapSuccess<B>(_ successMap: ((A, String) -> ParseResult<B>)) 
                     -> ParseResult<B> {
    switch self {
      case .Success(let value, let restOfInput):
        return successMap(value, restOfInput)
      case .Failure(let msg):
        return .Failure(msg)
      default:
        preconditionFailure("Unhandled enum: " + String(describing: self))
    }
  }

  func mapValue<B>(_ mapFunc: ((A) -> B)) -> ParseResult<B> {
    switch self {
      case .Success(let value, let rest): 
        return .Success(mapFunc(value), rest)
      case .Failure(let msg):
        return .Failure(msg)
      default:
        preconditionFailure("Unhandled enum: " + String(describing: self))
    }
  }
}
