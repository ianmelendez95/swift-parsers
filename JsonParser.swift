enum Json {
  case Number(Int)
  case String(String)
  case Boolean(Bool)
  case Array([Json])
  case Object([(String, Json)])
}

func testJsonParser() {
  let input = """
    { \"hello\": \"world\"
    , \"answer\": 42
    , \"question\": [ \"I\", \"would\", \"walk\", 500, \"miles\" ]
    , \"from\": { \"me\": \"you\" }
    }
    """
  print("number", JsonParsers.jsonParser().parse("42"))
  print("string", JsonParsers.jsonParser().parse("\"question\""))
  print("boolean", JsonParsers.jsonParser().parse("true"))
  print("array", JsonParsers.jsonParser().parse("[1,2,]"))
  print("object", JsonParsers.jsonParser().parse("{\"walk\": 500,}"))
  print("object2", JsonParsers.jsonParser().parse("{\"walk\": 500,\"run\":100}"))
  print(Parsers.spaces().then(JsonParsers.jsonParser()).parse(input))
}

class JsonParsers {
  private static var jsonParserInstance: Parser<Json>? = nil

  static func jsonParser() -> Parser<Json> {
    if let parser = jsonParserInstance {
      return parser
    }

    let numberParser: Parser<Json> = {
      return Parsers.natural().map({ num in Json.Number(num) })
    }()

    let stringParser: Parser<Json> = {
      return Parsers.stringLiteral().map({ strContent in Json.String(strContent) })
    }()

    let booleanParser: Parser<Json> = {
      let trueParser = Parsers.string("true").map({ _ in Json.Boolean(true) })
      let falseParser = Parsers.string("false").map({ _ in Json.Boolean(false) })
      return Parsers.alternate(trueParser, falseParser)
    }()

    func arrayParser() -> Parser<Json> {
      let arrayContent: Parser<[Json]> = 
        JsonParsers.jsonParser().token()
                   .skipOptional(Parsers.char(",").token()).many()
      return arrayContent.between(Parsers.char("[").token(), Parsers.char("]"))
                         .map({ items in Json.Array(items) })
    }

    func objectParser() -> Parser<Json> {
      let valuePair: Parser<(String, Json)> = {
        let key: Parser<String> = Parsers.stringLiteral()

        return key.flatMap({ keyStr in 
          Parsers.char(":").token()
                           .then(JsonParsers.jsonParser().token())
                           .skipOptional(Parsers.char(","))
                           .map({ jsonValue in (keyStr, jsonValue) })
        })
      }()

      return valuePair.token().many().between(Parsers.char("{").token(), 
                                              Parsers.char("}"))
                      .map({ pairs in Json.Object(pairs) })
    }

    let parser = Parsers.choice(
      [ numberParser.token()
      , stringParser.token()
      , booleanParser.token()
      , Parsers.delayed({ arrayParser().token() })
      , Parsers.delayed({ objectParser().token() })
      ])
    jsonParserInstance = parser
    return parser
  }
}
