typealias Parser = ((String) -> (Character, String)?)

func char(_ char: Character) -> Parser {
  return satisfy({ c in c == char })
}

func satisfy(_ predicate: @escaping ((Character) -> Bool)) -> Parser {
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

func strHead(_ str: String) -> Character? {
  return str.first
}

func strTail(_ str: String) -> String {
  return String(str.dropFirst(1))
}

