typealias Parser<A> = ((String) -> (A, String)?)

/* ************ *
 * HTML PARSING *
 * ************ */

typealias EmptyHtmlTag = (String, [String: String]) // (tag name, attributes)

func emptyHtmlTag() -> Parser<EmptyHtmlTag> {
  let leftAngle = char("<")
  let rightAngle = char(">")
  
  return sequence(leftAngle, fmap(word(), { tagName in (tagName, [:]) }))
}

/* func tagAttribute() -> Parser<(String, String)> { */
/*   let key = fmap(many(satisfy({ c in c != "=" })), charsToString) */
/*   let equals = char("=") */
/*   let value = quoted(word()) */ 

/*   return { input in (("not", "impl"), "stop") } */
/* } */

/* func quoted<A>(_ parser: Parser<A>) -> Parser<A> { */
/*   return sequence(char("\""), ) */
/* } */

func testEmptyHtmlTag() {
  print(emptyHtmlTag()("<input type=\"text\" value=\"hello world!\"/>"))
}

/* **************** *
 * PARSER INSTANCES *
 * **************** */ 

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

func nonSpace() -> Parser<Character> {
  return satisfy({ char in !char.isWhitespace })
}

func char(_ char: Character) -> Parser<Character> {
  return satisfy({ c in c == char })
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
