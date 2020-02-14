class HtmlParsers {
  typealias EmptyHtmlTag = (String, [String: String]) // (tag name, attributes)

  static func testEmptyHtmlTag() {
    print(emptyHtmlTag.parse("<input type=\"text\" value=\"hello world\"/>"))
  }

  static let emptyHtmlTag: Parser<EmptyHtmlTag> = {
    let openBracket = Parsers.char("<").token().name("open bracket")
    let attributes: Parser<[String: String]> = 
      tagAttribute.token().many().map(pairsToDict)
    let closeBracket = Parsers.string("/>").token().name("close bracket")

    let tagName = Parsers.letters().token().name("tag name")

    let tagContent = 
      tagName.flatMap({ tagName in 
        attributes.map({ attrs in (tagName, attrs) }) }).token()

    return tagContent.between(openBracket, closeBracket)
                     .name("empty html tag")
  }()

  static let tagAttribute: Parser<(String, String)> = {
    let key = Parsers.letters().token()
    let equals = Parsers.char("=")
    
    return key.flatMap({ keyStr in 
              equals.then(Parsers.stringLiteral()
                                 .map({ valueStr in (keyStr, valueStr) }))
            }).name("tag attribute")
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
