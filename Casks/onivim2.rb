VERSION = "0.5.6".freeze
SHA_256 = "252837b2553d18c1dfc68cdb88da7cc49210d0461b2db93f90b402bf7047d36d".freeze

# Defined in the website js
FIREBASE_API_KEY = "AIzaSyDxflsfyd2gloxgWJ-GFtPM46tz-TtOXh8".freeze
ONIVIM_BASE_URL = "https://v2.onivim.io".freeze
LICENSE_KEY_ENV = "HOMEBREW_ONIVIM_SERIAL".freeze
ZAP_LIST = [
  "~/.config/oni2",
  "~/Library/Preferences/com.outrunlabs.onivim2.plist",
  "~/Library/Saved Application State/com.outrunlabs.onivim2.savedState",
].freeze

# Custom Download strategy to bypass @cached_location name length limitation
class OniVimDownloadStrategy < CurlDownloadStrategy
  # noinspection RubyArgCount
  def initialize(url, name, version, **meta)
    super
    @cached_location = Pathname.new("#{HOMEBREW_CACHE}/downloads/OniVim2-#{version}.app")
    @symlink_location = Pathname.new("#{@cache}/#{name}.app")
    @temporary_path = Pathname.new("#{@cached_location}.incomplete")
  end
end

class NoLicenseFoundError < StandardError
  def initialize(msg = nil)
    super msg || "No license was found"
  end
end

class InvalidLicenseError < StandardError
  def initialize(msg = nil)
    super msg || "License key is invalid"
  end
end

# Handle authentication for downloading OniVim2
class AuthenticationProvider
  # @raise NoLicenseFoundError if no license key is found
  def initialize(serial_key: nil)
    @serial_key = serial_key || ENV.fetch(LICENSE_KEY_ENV, nil)
    raise NoLicenseFoundError if @serial_key.nil?
  end

  # @return true if the license key is valid
  def valid_serial
    response = URI("#{ONIVIM_BASE_URL}/api/isLicenseKeyValid?licenseKey=#{@serial_key}").open.read
    JSON.parse(response).to_s == "true"
  end

  # @return a token to allow downloading the OniVim2 binary
  # @raise InvalidLicenseError
  def download_token
    require "open-uri"
    require "net/http"
    require "json"

    # Verify license key
    raise InvalidLicenseError unless valid_serial

    # Get a temporary download token
    token_response = URI("#{ONIVIM_BASE_URL}/auth/licenseKey?licenseKey=#{@serial_key}").open.read
    token = JSON.parse(token_response)["token"]
    custom_token_url = URI.parse("https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken" \
                                   "?key=#{FIREBASE_API_KEY}")

    custom_token_response = Net::HTTP.post_form(custom_token_url, { "returnSecureToken" => "true", "token" => token })
    JSON.parse(custom_token_response.body)["idToken"]
  end
end

cask "onivim2" do
  version VERSION.to_s
  sha256 SHA_256.to_s

  url do
    [
      "#{ONIVIM_BASE_URL}/downloads/Onivim2.dmg?channel=stable&token=#{AuthenticationProvider.new.download_token}",
      { using: OniVimDownloadStrategy, referer: "https://github.com/marblenix/homebrew-onivim2" },
    ]
  end
  name "OniVim2"
  desc "Native, lightweight modal code editor"
  homepage ONIVIM_BASE_URL.to_s

  conflicts_with cask: "onivim2-nightly"

  app "OniVim2.app"
  shim_script = "#{staged_path}/oni2.wrapper.sh"
  binary shim_script, target: "oni2"

  preflight do
    IO.write shim_script, <<~EOS
      #!/bin/sh
      exec "#{appdir}/OniVim2.app/Contents/MacOS/Oni2" "$@"
    EOS
  end

  zap trash: ZAP_LIST
end
