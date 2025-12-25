cask "phtv" do
  version "1.2.6"
  sha256 "4241ef3043689e6b81f1b29e1fdbbcd5a105c61ffb44f8753386ebe38d97df74"

  url "https://github.com/PhamHungTien/PHTV/releases/download/v#{version}/PHTV-#{version}.zip"
  name "PHTV"
  name "Precision Hybrid Typing Vietnamese"
  desc "Modern Vietnamese input method for macOS"
  homepage "https://phamhungtien.com/PHTV/"

  # Universal Binary - supports both Intel and Apple Silicon
  livecheck do
    url :url
    strategy :github_latest
  end

  # System requirements
  depends_on macos: ">= :sonoma"

  app "PHTV.app"

  # Accessibility permission required
  postflight do
    system_command "/bin/launchctl",
                   args: ["load", "-w", "#{appdir}/PHTV.app/Contents/Library/LoginItems/PHTV.app"]
  end

  zap trash: [
    "~/Library/Application Support/PHTV",
    "~/Library/Preferences/com.phamhungtien.phtv.plist",
    "~/Library/Caches/com.phamhungtien.phtv",
    "~/Library/Logs/PHTV",
  ]

  caveats <<~EOS
    PHTV requires Accessibility permission to function.

    To grant permission:
    1. Open System Settings
    2. Go to Privacy & Security > Accessibility
    3. Enable PHTV

    For more information, visit: https://phamhungtien.com/PHTV/
  EOS
end
