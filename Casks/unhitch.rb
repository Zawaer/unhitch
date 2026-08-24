cask "unhitch" do
  version "1.1.1"
  sha256 "dbe320d2296e18434f5d629e9a76e863b91e279d1708f9eb0e689547f3ff0899"

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
