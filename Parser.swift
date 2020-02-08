func parseChar(_ char: Character, _ input: String) -> (Character, String)? {
  if let first = strHead(input) {
    if (first == char) {
      return (first, strTail(input))
    } else {
      return nil
    }
  } else {
    return nil
  }
}

func strHead(_ str: String) -> Character? {
  return str.first
}

func strTail(_ str: String) -> String {
  return String(str.dropFirst(1))
}

