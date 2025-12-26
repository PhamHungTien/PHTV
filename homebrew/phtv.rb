# typed: strict
# frozen_string_literal: true

cask "phtv" do
  version "1.2.7"
  sha256 "9b6e6cd452917c269d738ec71ba830d8234bb221acb77a5d78e98403262c4620"

  url "https://github.com/PhamHungTien/PHTV/releases/download/v#{version}/PHTV-#{version}.dmg",
      verified: "github.com/PhamHungTien/"
  name "PHTV"
  name "Precision Hybrid Typing Vietnamese"
  desc "Modern Vietnamese input method"
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
    "~/Library/Caches/com.phamhungtien.phtv",
    "~/Library/Logs/PHTV",
    "~/Library/Preferences/com.phamhungtien.phtv.plist",
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
