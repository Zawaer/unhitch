cask "unhitch" do
  version "1.2.1"
  sha256 "78b548fd20e78a9c227ba8330df87aa611fe45579fbb125019a57c85dadf5574"

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
