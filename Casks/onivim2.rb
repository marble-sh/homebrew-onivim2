require 'open-uri'
require 'net/http'
require 'json'

class InvalidLicenseError < StandardError
end

class OniVimDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    @cached_location = Pathname.new(HOMEBREW_CACHE/"downloads/OniVim2-nightly.app")
    @symlink_location = @cache/"#{name}.app"
  end
end

# Definied in the website js
FIREBASE_API_KEY = "AIzaSyDxflsfyd2gloxgWJ-GFtPM46tz-TtOXh8"

cask 'onivim2' do
  version :latest
  sha256 :no_check

  # Verify license key
  serialKey = ENV.fetch('HOMEBREW_ONIVIM_SERIAL')
  isValidResponse = URI("https://v2.onivim.io/api/isLicenseKeyValid?licenseKey=#{serialKey}").open.read
  isValid = JSON.parse(isValidResponse)
  raise InvalidLicenseError.new unless isValid.to_s == "true"

  # Get a temporary download token
  tokenResponse = URI("https://v2.onivim.io/auth/licenseKey?licenseKey=#{serialKey}").open.read
  token = JSON.parse(tokenResponse)["token"]
  customTokenURL = URI.parse("https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=#{FIREBASE_API_KEY}")
  params = {"token" => token, "returnSecureToken" => "true"}
  customTokenResponse = Net::HTTP.post_form(customTokenURL, params)
  idToken = JSON.parse(customTokenResponse.body)["idToken"]

  url "https://v2.onivim.io/downloads/Onivim2.dmg?channel=nightly&token=#{idToken}", using: OniVimDownloadStrategy
  name 'OniVim2'
  homepage 'https://v2.onivim.io/'
  app 'OniVim2.app'
end
