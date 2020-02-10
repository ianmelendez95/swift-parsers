typealias Parser<A> = ((String) -> (A, String)?)

/* ************ *
 * HTML PARSING *
 * ************ */

typealias EmptyHtmlTag = (String, [String: String]) // (tag name, attributes)

func emptyHtmlTag() -> Parser<EmptyHtmlTag> {
  let openBracket = char("<")
  let attributes: Parser<[String: String]> = 
    fmap(many(token(tagAttribute())), { attributes in pairsToDict(attributes) })
  let closeBracket = sequence(char("/"), char(">"))

  return sequence(openBracket, 
          bind(token(letters()), { tagName in
            keepFirst(fmap(attributes, { attrs in (tagName, attrs) }), closeBracket)
          }))
}

func testEmptyHtmlTag() {
  print(emptyHtmlTag()("<input type=\"text\" value=\"hello world!\"/>"))
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

// TODO - handle escaped quotes
func tagAttribute() -> Parser<(String, String)> {
  let key = token(letters())

  let equals = char("=")

  let valueContent = asString(many(satisfy({ c in c != "\"" })))
  let value = quoted(valueContent)

  return 
    bind(key, { keyStr in
      sequence(equals, 
        fmap(value, { valueStr in (keyStr, valueStr) }))
    })
}

func testTagAttribute() { 
  print(tagAttribute()("type=\"text\""))
}

/* **************** *
 * PARSER INSTANCES *
 * **************** */ 

func token<A>(_ parser: @escaping Parser<A>) -> Parser<A> {
  return keepFirst(parser, spaces())
}

func quoted<A>(_ parser: @escaping Parser<A>) -> Parser<A> {
  let quote = char("\"")
  return sequence(quote, keepFirst(parser, quote))
}

func testQuoted() {
  print(quoted(letters())("\"quotedstuff\""))
}

func letters() -> Parser<String> {
  return asString(many(letter()))
}

func letter() -> Parser<Character> {
  return satisfy({ char in char.isLetter })
}

func spaces() -> Parser<Void> {
  return sequence(many(space()), nullParser())
}

func nonSpace() -> Parser<Character> {
  return satisfy({ char in !char.isWhitespace })
}

func space() -> Parser<Character> {
  return satisfy({ char in char.isWhitespace })
}

func char(_ char: Character) -> Parser<Character> {
  return satisfy({ c in c == char })
}

func nullParser() -> Parser<Void> {
  return { input in ((), input) }
}

func asString(_ parser: @escaping Parser<[Character]>) -> Parser<String> {
  return fmap(parser, charsToString)
}

func testWord() {
  print(word()("hello world")) // ("hello", "world")
}

// word = any sequential set of characters that are not whitespace
func word() -> Parser<String> {
  return fmap(many(nonSpace()), charsToString)
}

func many<A>(_ parser: @escaping Parser<A>) -> Parser<[A]> {
  return { input in
    var result: [A] = [] 
    var curInput = input
    while let (nextResult, nextInput) = parser(curInput) {
      result.append(nextResult)
      curInput = nextInput
    }

    return (result, curInput)
  }
}

func keepFirst<A,B>
( _ firstParser: @escaping Parser<A>
, _ secondParser: @escaping Parser<B>) 
-> Parser<A> {
  return { input in 
    if let (result1, rest1) = firstParser(input) {
      if let (_, rest2) = secondParser(rest1) {
        return (result1, rest2)
      }
    }

    return nil
  }
}

func testKeepFirst() {
  let hParser = char("h")
  let eParser = char("e")

  let parsed = keepFirst(hParser, eParser)("hello")

  print(parsed)
}

func lift<A,B,C>
( _ parser1: @escaping Parser<A>
, _ parser2: @escaping Parser<B>
, _ liftedFunction: @escaping ((A, B) -> C)) 
-> Parser<C> {
  return { input in
    if let (result1, rest1) = parser1(input) {
      if let (result2, rest2) = parser2(rest1) {
        return (liftedFunction(result1, result2), rest2)
      }
    }

    return nil
  }
}

func bind<A,B>
(_ parser: @escaping Parser<A>, _ bindFunction: @escaping ((A) -> Parser<B>)) 
-> Parser<B> {
  return { input in 
    if let (result, rest) = parser(input) {
      return bindFunction(result)(rest)
    } else {
      return nil
    }
  }
}

func fmap<A,B>(_ parser: @escaping Parser<A>, _ fmapFunction: @escaping ((A) -> B)) 
-> Parser<B> {
  return { input in
    if let (result, rest) = parser(input) {
      return (fmapFunction(result), rest)
    } else {
      return nil
    }
  }
}

func sequence<A,B>(_ parser1: @escaping Parser<A>, _ parser2: @escaping Parser<B>) 
-> Parser<B> {
  return { input in
    if let (_, rest1) = parser1(input) {
      return parser2(rest1)
    } else {
      return nil
    }
  }
}

func satisfy(_ predicate: @escaping ((Character) -> Bool)) -> Parser<Character> {
  return { input in
    if let first = strHead(input) {
      if (predicate(first)) {
        return (first, strTail(input))
      } else {
        return nil
      }
    } else {
      return nil
    }
  }
}

func strNull(_ str: String) -> Bool {
  return str.count == 0
}

func strHead(_ str: String) -> Character? {
  return str.first
}

func strTail(_ str: String) -> String {
  return String(str.dropFirst(1))
}

func charsToString(_ chars: [Character]) -> String {
  return String(chars)
}

func testSequenced() {
  let hParser = char("h")
  let eParser = char("e")
  let sequenced = sequence(hParser, eParser)
  
  print(sequenced("hello")) // '("e", "llo")'
}

func testBind() {
  let hParser = char("h")
  let eParser = char("e")
  let bound = bind(hParser, 
    { (letter: Character) in 
      fmap(eParser, { (result: Character) in String(letter) + String(result) })
    })

  let parsed = bound("hello")

  print(parsed)
}

func testLift() {
  let hParser = char("h")
  let eParser = char("e")
  let lifted = lift(hParser, eParser, { res1, res2 in String(res1) + String(res2) })

  let parsed = lifted("hello")

  print(parsed)
}

func testMany() {
  let aParser = char("a")
  let asParser = many(aParser)
  
  let parsed = asParser("aardvark")

  print(parsed) // (["a", "a"], "rdvark")
}
