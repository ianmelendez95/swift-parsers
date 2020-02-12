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

#### HTML Tag

```swift
Parsers.letters().flatMap({ tagName in 
  Parsers.char("=")
         .then(Parsers.stringLiteral())
         .map({ value in (tagName, value) })          
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
