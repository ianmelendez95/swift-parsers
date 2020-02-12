enum Json {
  case Number(Int)
  case String(String)
  case Boolean(Bool)
  case Array([Json])
  case Object([(String, Json)])
}

func testJsonParser() {
  /* let input = """ */
  /*   { \"hello\": \"world\" */
  /*   , \"answer\": 42 */
  /*   , \"question\": [\"tell\", \"you\", \"later\"] */
  /*   , */
  /*   } */
  /*   """ */
  print("number", JsonParsers.jsonParser().parse("42"))
  print("string", JsonParsers.jsonParser().parse("\"question\""))
  print("boolean", JsonParsers.jsonParser().parse("true"))
  print("array", JsonParsers.jsonParser().parse("[1,2,]"))
  print("object", JsonParsers.jsonParser().parse("{\"walk\": 500,}"))
  /* print(Parsers.spaces().then(JsonParsers.jsonParser()).parse(input)) */
}

class JsonParsers {
  static var jsonParserInstance: Parser<Json>? =  nil 

  static func jsonParser() -> Parser<Json> {
    if let parser = jsonParserInstance {
      return parser
    } else {
      let parser = Parsers.choice(
        [ JsonParsers.numberParser.token()
        , JsonParsers.stringParser.token()
        , JsonParsers.booleanParser.token()
        , Parsers.delayed({ JsonParsers.arrayParser().token() })
        , Parsers.delayed({ JsonParsers.objectParser().token() })
        ])
      jsonParserInstance = parser
      return parser
    }
  }

  static let numberParser: Parser<Json> = {
    return Parsers.natural().map({ num in Json.Number(num) })
  }()

  static let stringParser: Parser<Json> = {
    return Parsers.stringLiteral().map({ strContent in Json.String(strContent) })
  }()

  static let booleanParser: Parser<Json> = {
    let trueParser = Parsers.string("true").map({ _ in Json.Boolean(true) })
    let falseParser = Parsers.string("false").map({ _ in Json.Boolean(false) })
    return Parsers.alternate(trueParser, falseParser)
  }()

  static func arrayParser() -> Parser<Json> {
    let arrayContent: Parser<[Json]> = 
      JsonParsers.jsonParser().token()
                 .precedes(Parsers.char(",").token()).many()
    return arrayContent.between(Parsers.char("["), Parsers.char("]"))
                       .map({ items in Json.Array(items) })
  }

  static func objectParser() -> Parser<Json> {
    let valuePair: Parser<(String, Json)> = {
      let key: Parser<String> = Parsers.stringLiteral()

      return key.flatMap({ keyStr in 
        Parsers.char(":").token()
                         .then(JsonParsers.jsonParser())
                         .precedes(Parsers.char(",").token())
                         .map({ jsonValue in (keyStr, jsonValue) })
      })
    }()

    return valuePair.token().many().between(Parsers.char("{"), 
                                            Parsers.char("}"))
                    .map({ pairs in Json.Object(pairs) })
  }
}
