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
let attributeParser: Parser<String> = 
  tagNameParser.flatMap({ tagName in 
    return equals.then(valueParser).map({ value in (tagName, value) })
  })
```

So, in rough words "parse according to the tagNameParser,
then bind that value to the 'tagName' variable, 
then parse according to equals, then valueParser,
and then bind the value of the valueParser to 'value'
and return the new value `(tagName, value)` - our attribute key value pair"





