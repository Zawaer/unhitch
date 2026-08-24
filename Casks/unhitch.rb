cask "unhitch" do
  version "1.2.0"
  sha256 "c111d6d2158764f85a497211814bcc73892c81486e69b239daba1f7b5dc063c4"

  url "https://github.com/Zawaer/unhitch/releases/download/v#{version}/Unhitch.zip"
  name "Unhitch"
  desc "Releases chosen Bluetooth devices on lid close without touching the radio"
  homepage "https://github.com/Zawaer/unhitch"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Unhitch.app"

  uninstall quit:       "com.zawaer.unhitch",
            login_item: "Unhitch"

  zap trash: [
    "~/Library/Caches/com.zawaer.unhitch",
    "~/Library/HTTPStorages/com.zawaer.unhitch",
    "~/Library/Preferences/com.zawaer.unhitch.plist",
  ]
end
