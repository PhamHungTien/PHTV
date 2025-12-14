cask "phtv" do
  version "1.0.0"
  sha256 "6ff2f005a9e3d37efc9feea5a0c43310e46595c26db7204b19b02c9e3a0a96e1"

  url "https://github.com/PhamHungTien/PHTV/releases/download/v#{version}/PHTV_#{version}.dmg"
  name "PHTV"
  desc "Vietnamese Input Method for macOS - Bộ gõ tiếng Việt hiện đại"
  homepage "https://github.com/PhamHungTien/PHTV"

  app "PHTV.app"

  zap trash: [
    "~/Library/Preferences/com.phtv.app.plist",
    "~/Library/Caches/com.phtv.app",
    "~/Library/Application Support/PHTV"
  ]
end
