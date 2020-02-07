func parseChar(char: Character, input: String) -> (Character, String)? {
    if (input.count == 0 || input.first != char) {
        return nil
    }
        
    return (input.first, input.dropFirst(1))
}

func strHead(str: String) -> Character? {
    return str.first
}

func strTail(str: String) -> String? {
    return str.count == 0 ? nil : str.suffix(from: 1)
}

