## swift-parsers
Build your own parsers in Swift! 
A (not production ready!) parser combinator library.

| TOC                              |
| -------------------------------- |
| [Examples](#examples)            |
| Example Breakdown                |
| Combinatory Parsing From Scratch | 

### Combinatory Parsing

Combinatory Parsing is simply an extension of the age old process of 
tackling meaningful challenges - solving smaller problems 
(creating small localized parsers) and combining them to solve larger ones
(combining these parsers to handle more complex structures).

Anyways, onto combinatory parsing!

### Examples

#### My First Char

```swift
Parsers.char("h").parse("hello world!")

>> ParseResult.Success("h", "ello world!")
```

#### Simple String Literal

```swift
Parsers.stringLiteral().parse("\"hello\" \"world\"")
  
>> ParseResult.Success("hello", " \"world\"")
```

#### HTML Tag Attribute

```swift
Parsers.letters().flatMap({ attributeName in 
  Parsers.char("=")
         .then(Parsers.stringLiteral())
         .map({ attributeValue in (attributeName, attributeValue) })          
}).parse("hello=\"world\"")
  
>> ParseResult.Success(("hello", "world"), "")
```

#### Integer Number Array

```swift
Parsers.natural()
       .skipOptional(Parsers.char(","))
       .token()
       .many()
       .between(Parsers.char("["),
                Parsers.char("]"))
       .parse("[1,2,3,4]")

>> Success([1, 2, 3, 4], "")
```


### Example Breakdown 

#### HTML Tag Attribute

First we'll break down the components into as many individual parsers as possible.

We know a tag attribute has the form

> myattribute="myvalue"
  
Then we break it down to what a 'parser' might see

> \<series of letters\>\<equals sign\>\<string literal\>

Creating the constituent parsers

```swift
let tagNameParser: Parser<String> = Parsers.letters()
let equals: Parser<Character> = Parsers.char("=")
let valueParser: Parser<String> = Parsers.stringLiteral()
```

We can then try to combine them into a single parser.

```swift
let attributeParser: Parser<String> = tagNameParser.then(equals).then(valueParser)
```

Note that the resulting `attributeParser` type is just `Parser<String>`,
since `then(valueParser)` only keeps the value of the `valueParser`

Thus `attributeParser.parse("myattribute=\"myvalue\"")` 
would return `.Success("myvalue", "")`

This is where we identify that we must 'bind' the result of the tagNameParser to a variable
we can use, and then utilize that variable to return the final, proper value

Binding of the values, while continuing to develop the parser,
is accomplished through `Parser.flatMap`

```swift
let attributeParser: Parser<String> = 
  tagNameParser.flatMap({ tagName in 
    // we now have a handle on the tagName value in this closure
    return equals.then(valueParser)
  })
```

The above attributeParser behaves in the exact same way.
To roughly illustrate, we are saying 
"map tagNameParser to a new parser, which parses with equals and then valueParser"

Aside: 'flatMap' is not the ideal word as we aren't simply 
       'mapping' to a new parser, but threading the 'parse context' 
       (fancy word for the input string) through to the parser returned 
       by the closure - `equals.then(valueParser)`. 
       In FP this operation is called 'bind', but 
       my impression is that 'flatMap' is more idiomatic in OO contexts.

Here we can get a sense of where to go.
We have a handle on the value parsed by tagNameParser,
and valueParser will parse the value component of the 
attribute. Now we simply map the value parsed by the 
parser in the closure to our desired result.

```swift
let attributeParser: Parser<(String, String)> = 
  tagNameParser.flatMap({ tagName in 
    return equals.then(valueParser).map({ value in (tagName, value) })
  })
```

So, in rough words "parse according to the tagNameParser,
then bind that value to the 'tagName' variable, 
then parse according to equals, then valueParser,
and then bind the value of the valueParser to 'value'
and return the new value `(tagName, value)` - our attribute key value pair"

### Combinatory Parsing From Scratch

First - what is a parser? 

You'll find many definitions, but it truly feels quite simple.
It's something that will consume a string and (possibly) identify a value.

```swift
typealias Parser<A> = ((String) -> A?)
```

Where A is potentially anything, perhaps even a Parser! 
Why don't we make a parser that simply parses some input
and returns the first character.

```swift
let anyCharParser: Parser<Character> = { input in
  // if the string is non-empty
  if (input.count > 0) {
    // return the first character
    return input.first
  } 

  // otherwise, return nil
  return nil
}

parseChar("hello")
>> "h"
```

Note that the above declaration is equivalent to the formal declaration below

```swift
func anyCharParser(_ input: String) -> Character? {
  if (input.count > 0) {
    return input.first
  }
  
  return nil
}
```

So where does the 'combinatory' in 'combinatory parsing' come into play?
Right now, our parser gives us very little in the way of combining parsers,
but we can map a parsers value to get some sense of manipulating our parser to get
a new parser with different behavior.

```swift
func mapParser<A,B>(_ parser: Parser<A>, _ mapFunc: ((A) -> B)) -> Parser<B> {
  return { input in
    // we'll parse as normal
    if let val = parser(input) {
      // but return the value mapped appropriately
      return mapFunc(val)
    } else {
      return nil
    }
  }
}

let newParser = mapParser(anyCharParser, { c in String(c) + "i" })
newParser("h")
>> "hi"
```

We've about stretched out what we can do with our existing parser setup, 
so we clearly need to revisit it. The glaring component missing from our parser is 
a sense of what's left of our input. 
Thus, we simply return it as part of our parsing!

```swift
// we now return (A, String), a.k.a. (\<value\>, \<rest-of-input\>)
typealias Parser<A> = ((String) -> (A, String)?)

let anyCharParser: Parser<Character> = { input in
  if (input.count > 0) {
    // this time, we return the value AND the rest of the string
    return (input.first, String(str.dropFirst(1)))
  }  

  return nil
}

func mapParser<A,B>(_ parser: Parser<A>, _ mapFunc: ((A) -> B)) -> Parser<B> {
  return { input in
    // now we get a tuple with the rest of the input
    if let (value, restOfInput) = parser(input) {
      // and include the rest of the input in our return value
      return (mapFunc(val), restOfInput)
    } else {
      return nil
    }
  }
}

anyCharParser("hello")
>> ("h", "ello")

mapParser(anyCharParser, { c in String(c) + "i" })("hello")
>> ("hi", "ello")
```

Now we can try to thread two parsers together. We'll implement the simple 
`then` function to 'sequence' two parsers. (In fact, the operator
used in Haskell to represent this is `>>`, dubbed the 'sequence' 
operator) 

```swift
func then<A,B>(_ parser1: Parser<A>, _ parser2: Parser<B>) -> Parser<B> {
  return { input in
    // first we get the rest of the input from the first parser 
    // (discarding the value)
    if let (_, restOfInput1) = parser1(input) {

      // then we 'thread' the rest of the input from the first parser 
      // into the second parser, returning that result
      return parser2(restOfInput1)
    } 

    return nil
  }
}

then(anyCharParser, anyCharParser)("hello")
>> ("e", "llo")
```

This is nice, but we don't want to just discard values! Theres possible content 
we might be interested in going right down the drain! We need some way 
to bind intermediate parse results to variables we can use later on, so we'll 
create a function that allows us to use the values and still continue 
defining a parser in the chain.

```swift
func flatMap<A,B>(_ parser: Parser<A>, _ bindFunc: ((A) -> Parser<B>)) 
                 -> Parser<B> {
  return { input in
    if let (result, restOfInput) = parser(input) {
      // notice how unlike 'then', we use the result
      // to get our new parser from the bindFunc, and 
      // invoke that
      return bindFunc(result)(restOfInput)
    }

    return nil
  }
}

flatMap(anyCharParser, { c1 in 
  return map(anyCharParser, { c2 in  
    return String(c1) + String(c2)
  }) 
})("hello")
>> ("he", "llo")
```

Now the last step to getting a minimal combinator library is to be able to 
describe a simple parser without having to formally define one. 
In comes `satisfy`!

```swift
func satisfy(_ charPredicate: ((Character) -> Bool)) -> Parser<Character> {
  return { input in
    // notice the difference to the anyCharParser, 
    // where now we also check the predicate
    if (input.count > 0 && charPredicate(input.first)) {
      return (input.first, String(str.dropFirst(1)))
    } 

    return nil
  }
}

satisfy({ c in c == "h" })("hello")
>> ("h", "ello")

satisfy({ c in c == "b" })("hello")
>> nil
```

This combinator library is 'minimal' because (I'm fairly confident) 
this is theoretically minimal set of functionality needed to parse any possible 
string to any possible value. Though of course, that would be incredibly tedious.

From here we could start creating other fancier combinators to make our lives 
easier. Just as a taste, we'll make the `many` combinator.

```swift
func many<A>(_ parser: Parser<A>) -> Parser<[A]> {
  return { input in
    var result: [A] = []  // our array for collecting results
    var curInput = input  // our variable for holding the running input
    while let (nextResult, nextInput) = parser(curInput) {
      // while we get results, update the array and the input
      result.append(nextResult)
      curInput = nextInput
    }

    // return the array of results and rest of the input
    return (result, curInput)
  }
}

map(satisfy({ c in c.isLetter }), { chars in String(chars) })("hello123")
>> ("hello", "123")
```

From here you can easily extract the methods to a Parser class to take advantage
of Object Oriented semantics, where the first argument of the example combinators
is now the implicit class variable holding the parsers parsing function. 
Just to exemplify this:

```swift
class Parser<A> {
  let parserFunc: ((String) -> (A, String)?)

  init(_ parserFunc: ((String) -> (A, String)?)) {
    self.parserFunc = parserFunc
  }

  parse(_ input: String) -> (A, String)? {
    return self.parserFunc
  }

  // notice how we simply remove the fist parameter
  func flatMap<B>(_ bindFunc: ((A) -> Parser<B>)) -> Parser<B> {
    // wrap the function in the Parser initializer 
    return Parser<B>({ input in
      // and invoke the implicit class variable instead
      if let (result, restOfInput) = self.parserFunc(input) {
        return bindFunc(result)(restOfInput)
      }

      return nil
    })
  }
  
  func map<B>(_ mapFunc: ((A) -> B)) -> Parser<B> {
    return Parser<B>({ input in
      if let (value, restOfInput) = self.parserFunc(input) {
        return (mapFunc(value), restOfInput)
      } else {
        return nil
      }
    })
  }

  ...

}

// the age old OO utility class, the plural of the related class name
// (i.e. Path and Paths in Java)
class Parsers {
  static func satisfy(_ charPredicate: ((Character) -> Bool)) 
                     -> Parser<Character> {
    return { input in
      if (input.count > 0 && charPredicate(input.first)) {
        return (input.first, String(str.dropFirst(1)))
      } 

      return nil
    }
  }
}

Parsers.satisfy({ c in c.isLetter }).flatMap({ c1 in 
  Parsers.satisfy({ c in c.isNumber }).map({ c2 in String(c1) + String(c2) })
}).parse("a1 steak sauce")
>> ("a1", " steak sauce")
```


