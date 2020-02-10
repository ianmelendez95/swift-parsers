class HtmlParserExample {
  typealias EmptyHtmlTag = (String, [String: String]) // (tag name, attributes)

  static func testEmptyHtmlTag() {
    print(emptyHtmlTag.parse("<input type=\"text\" value=\"hello world!\"/>"))
  }

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
}
