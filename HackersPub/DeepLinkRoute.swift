enum HackersPubDeepLinkRoute: Equatable {
    case profile(handle: String)
    case postURL(String)
    case newsStory(id: String)
    case signInVerification(token: String, code: String)
    case tagSearch(String)
}
