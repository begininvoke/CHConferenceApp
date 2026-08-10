import Fluent
import Vapor

func routes(_ app: Application) throws {
  // App-authentication layer (§6): API key first, then App Attest assertion.
  let apiKeyGated = app.grouped(APIKeyMiddleware())
  let appAuthenticated = apiKeyGated.grouped(AppAttestMiddleware())

  // App Attest registration sits behind the API key only — a device cannot
  // assert before it has registered a key.
  try apiKeyGated.register(collection: AttestController())

  let appleAuth = AppleAuthService()
  try appAuthenticated.register(collection: AuthController(appleAuth: appleAuth))
  try appAuthenticated.register(collection: MeController(appleAuth: appleAuth))
  try appAuthenticated.register(
    collection: ScrapingController(firecrawl: FirecrawlService())
  )
}
