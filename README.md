## swift-parsers
Build your own parsers in Swift! A (not production ready!) parser combinator library.

### examples

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

### example breakdowns 

#### HTML Tag Attribute

First we'll break down the components into as many individual parsers as possible.

We know a tag attribute has the form

> myattribute="myvalue"
  
Then we break it down to what a 'parser' might see

> <series of letters><equals sign><string literal>

Creating the constituent parsers

```swift
let tagNameParser: Parser<String> = Parsers.letters()
let equals: Parser<Character> = Parsers.char("=")
let valueParser: Parser<String> = Parsers.stringLiteral()
```

We can then try to combine them into a single parser.

```swift
let attributeParser = tagNameParser.then(equals).then(valueParser)
```

But note that the resulting `attributeParser` type is `Parser<String>`,
since the `then(Parser<?>)` method 




