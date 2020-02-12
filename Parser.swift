class Parser<A> {
  let parseFunc: ((String) -> ParseResult<A>)

  init(_ parseFunc: @escaping ((String) -> ParseResult<A>)) {
    self.parseFunc = parseFunc
  }

  /**
   * Manifests a name for the parser, primarily 
   * for the purpose of reporting parse failures
   */
  func name(_ message: String) -> Parser<A> {
    return Parser({ input in
      return self.parse(input)
                 .mapFailure({ msg in message + " >> " + msg })
    })
  }

  func parse(_ input: String) -> ParseResult<A> {
    return self.parseFunc(input)
  }

  /**
   * Returns a new parser that returns the parse result of this
   * parser of the contents within the provided bounds
   * 
   *    Parsers.char("a").surroundedBy(Parsers.char("^")) 
   *
   * will parse 'a' in "^a^"
   */
  func surroundedBy<B>(_ bound: Parser<B>) -> Parser<A> {
    return self.between(bound, bound)
  }

  /**
   * Returns a new parser that returns the parse result of this
   * parser of the contents within the provided bounds
   * 
   * e.g. Parsers.char("a").between(Parsers.char("<"), Parsers.char(">")) will parse 'a' in "<a>"
   */
  func between<B,C>(_ bra: Parser<B>, _ ket: Parser<C>) -> Parser<A> {
    return bra.then(self).precedes(ket)
  }

  /**
   * Returns a new parser that returns the parse result of this
   * parser, discarding any following whitespace   
   * 
   *     Parsers.char("a").token() 
   *
   * will parse 'a' in "a  b", and leave "b" as the 
   * rest of the string
   */
  func token() -> Parser<A> {
    return self.skipOptional(Parsers.spaces())
  }

  /**
   * Returns a new parser that parses according 
   * to this parser, then the next parser, 
   * returning the next parsers value
   * 
   *     Parsers.char("a").then(Parsers.char("b")) 
   *
   * will parse 'b' in "ab"   
   */
  func then<B>(_ parser: Parser<B>) -> Parser<B> {
    return Parser<B>({ input in
      self.parse(input).flatMapSuccess({ _, restOfInput in 
        parser.parse(restOfInput)
      })
    })
  }

  /**
   * returns a new parser that parses according 
   * to this parser, then optionally the next parser, 
   * returning this parsers value
   * 
   *     Parsers.char("a").skipOptionally(parsers.char("b")) 
   *
   * will return 'a' in "abc", leaving "c" as the rest of the input
   * to parse - this is also true for the input "ac"
   * 
   */
  func skipOptional<B>(_ parser: Parser<B>) -> Parser<A> {
    return self.precedes(Parsers.alternate(parser.void(), 
                                           Parsers.null()))
  }

  /**
   * returns a new parser that parses according 
   * to this parser, discarding the value   
   * 
   *     Parsers.char("a").void() 
   *
   * will discard 'a' in "ab", returning (), leaving "b" 
   * as the rest of the input to parse
   * 
   * this is primarily useful when the value of the 
   * parsing is not desired, as different parsers
   * of different value types can be coerced to void 
   * and used with a combinator such as 'choice'
   */
  func void() -> Parser<Void> {
    return self.then(Parsers.null())
  }

  /**
   * returns a new parser that parses according 
   * to this parser, ensuring that the following
   * parser succeeds, returning this value
   * 
   *     Parsers.char("a").precedes(Parsers.char("b")) 
   *
   * will return 'a' in "abc", leaving "c" 
   * as the rest of the input to parse
   */
  func precedes<B>(_ follows: Parser<B>) -> Parser<A> {
    return Parser<A>({ input in 
      self.parse(input).flatMapSuccess({ value, restOfInput in 
        follows.parse(restOfInput).mapValue({ _ in value })
      })
    })
  }

  /**
   * returns a new parser that parses according 
   * to this parser, with the value mapped according 
   * to the provided function
   * 
   *     Parsers.char("h").map({ c in String(c) + "ello" }) 
   *
   * will return 'hello' in "h"
   */
  func map<B>(_ mapFunc: @escaping ((A) -> B)) -> Parser<B> {
    return Parser<B>({ input in
      self.parse(input).mapValue(mapFunc)
    })
  }

  /**
   * returns a new parser that parses according 
   * to this parser, and binds the value in the 
   * provided function that returns another parser,
   * which is then used to parse the rest of the input
   * 
   *     Parsers.natural().token().flatMap({ value1 in
   *       return Parsers.natural().map({ value2 in  
   *         return value1 + value2
   *       })
   *     }) 
   *
   * will return '123' in "100 23"
   */
  func flatMap<B>(_ boundParserFunc: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return Parser<B>({ input in 
      self.parse(input).flatMapSuccess({ value, restOfInput in
        boundParserFunc(value).parse(restOfInput)
      })
    })
  }

  /**
   * returns a new parser that parses according 
   * to this parser zero or more times, returning 
   * an array of the parse results
   * 
   *     Parsers.natural().token().many()   
   *
   * will return [1,12,123] in "1 12 123"
   * while it returns [] in "abc"
   */
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

  /**
   * returns a new parser that parses according 
   * to this parser at least one or more times, returning 
   * an array of the parse results
   * 
   *     Parsers.natural().token().many()   
   *
   * will return [1,12,123] in "1 12 123"
   */
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

  /**
   * returns a new array with the provided element as the head
   * and the rest of the list as the tail
   */
  static func cons<A>(_ elem: A, _ arr: [A]) -> [A] {
    var newArr = arr
    newArr.insert(elem, at: 0)
    return newArr
  }
}

class Parsers {
  /**
   * Parser for string literals of the form "<content>"
   * where <content> is returned
   */
  static func stringLiteral() -> Parser<String> {
    let escapedQuotes = Parsers.string("\\\"")
    let nonQuote = Parsers.satisfy({ c in c != "\"" }).map(charToString)
    let content = 
      Parsers.alternate(escapedQuotes, nonQuote).many().map(strConcat)

    return content.surroundedBy(Parsers.char("\""))
  }

  /**
   * A lazy constructor for parsers
   *
   * Allows clients to specify which parser to use 
   * without immediately invoking the code to create it
   *
   * Particularly useful when there is a recursive parser dependency
   * with lazy initialization
   * (e.g.: a json object can have any json component as the value,
   *        thus a parser for a json object will need to use a parser 
   *        for json objects!)
   */
  static func delayed<A>(_ parserFunc: @escaping (() -> Parser<A>)) -> Parser<A> {
    return Parser<A>({ input in 
      return parserFunc().parse(input)
    })
  }

  /**
   * Parses 'natural' numbers, here strictly just positive integers and 0
   */
  static func natural() -> Parser<Int> {
    return Parsers.digit().some()
                  .map(charsToString)
                  .map({ numStr in Int(numStr)! })
  }

  /**
   * Attempts to parse with each parser provided in order
   */
  static func choice<A>(_ parsers: [Parser<A>]) -> Parser<A> {
    return foldr( { parser, acc in Parsers.alternate(parser, acc) }
                , Parsers.fail()
                , parsers)
  }

  /**
   * Attempts to parse with parsers provided in order
   */
  static func alternate<A>(_ parser1: Parser<A>, _ parser2: Parser<A>) 
                          -> Parser<A> {
    return Parser<A>({ input in
      return parser1.parse(input)
                    .flatMapFailure({ _ in parser2.parse(input) })
    })
  }

  /**
   * Attempts to parse the provided string as-is
   */
  static func string(_ str: String) -> Parser<String> {
    return Parser<String>({ input in 
      return input.hasPrefix(str) ? .Success(str, strDrop(input, str.count))
                                  : .Failure(genFailureMessage(input))
    })
  }

  /**
   * Discards zero or more whitespace characters
   */
  static func spaces() -> Parser<Void> {
    return space().many().then(null())
  }

  /**
   * Parses a whitespace character
   */
  static func space() -> Parser<Character> {
    return satisfy({ c in c.isWhitespace })
  }

  /**
   * Parses at least one or more letters   
   */
  static func letters() -> Parser<String> {
    return asString(letter().some())
  }

  static func letter() -> Parser<Character> {
    return satisfy({ c in c.isLetter })
  }

  static func digit() -> Parser<Character> { 
    return satisfy({ c in c.isNumber })
  }

  /**
   * Parses the provided char
   */
  static func char(_ char: Character) -> Parser<Character> {
    return satisfy({ c in c == char })
  }

  /**
   * The most primitive parser constructor available,
   * parsing the next character if it satisfies the provided predicate
   */
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

  /**
   * A parser that unconditionally fails to parse any input
   * Useful as a default failing 'terminator' for certain combinators
   */
  static func fail<A>() -> Parser<A> {
    return Parser({ input in .Failure(genFailureMessage(input)) })
  }

  /**
   * A parser that unconditionally succeeds to parse no input
   * Useful as a default success 'terminator' for certain combinators
   */
  static func null() -> Parser<Void> {
    return Parser({ input in .Success((), input) })
  }

  /**
   * Coerces character array parsers to return the related string
   */
  static func asString(_ parser: Parser<[Character]>) -> Parser<String> {
    return parser.map(charsToString)
  }

  /**
   * Generates an error message displaying the current state of the 
   * input
   */
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
