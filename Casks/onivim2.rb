# frozen_string_literal: true

require 'open-uri'
require 'net/http'
require 'json'

class InvalidLicenseError < StandardError
end

# Custom Download strategy to fix @cached_location name length limitation
class OniVimDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    @cached_location = Pathname.new("#{HOMEBREW_CACHE}/downloads/OniVim2-stable.app")
    @symlink_location = Pathname.new("#{@cache}/#{name}.app")
    @temporary_path = Pathname.new("#{@cached_location}.incomplete")
  end
end

# Defined in the website js
FIREBASE_API_KEY = 'AIzaSyDxflsfyd2gloxgWJ-GFtPM46tz-TtOXh8'

cask 'onivim2' do
  app 'OniVim2.app'
  name 'OniVim2'
  version '0.5.4'
  sha256 'e1725689c51d5636892f385e9de53b88005c0ed57c7b370c7f04c3f95d4961c3'
  conflicts_with cask: 'onivim2-nightly'
  homepage 'https://v2.onivim.io/'

  # Verify license key
  serial_key = ENV.fetch('HOMEBREW_ONIVIM_SERIAL')
  is_valid_response = URI("https://v2.onivim.io/api/isLicenseKeyValid?licenseKey=#{serial_key}").open.read
  is_valid = JSON.parse(is_valid_response)
  raise InvalidLicenseError unless is_valid.to_s == 'true'

  # Get a temporary download token
  token_response = URI("https://v2.onivim.io/auth/licenseKey?licenseKey=#{serial_key}").open.read
  token = JSON.parse(token_response)['token']
  custom_token_url = URI.parse('https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken' \
                                   "?key=#{FIREBASE_API_KEY}")

  params = {'returnSecureToken' => 'true', 'token' => token}
  custom_token_response = Net::HTTP.post_form(custom_token_url, params)
  id_token = JSON.parse(custom_token_response.body)['idToken']

  url "https://v2.onivim.io/downloads/Onivim2.dmg?channel=stable&token=#{id_token}", using: OniVimDownloadStrategy
end
