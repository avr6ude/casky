# Cask for avr6ude/homebrew-tap. After each release, copy this file to
# Casks/casky.rb in the tap and set version and sha256 from release.sh output.
cask "casky" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE_SH"

  url "https://github.com/avr6ude/casky/releases/download/v#{version}/casky-#{version}.dmg"
  name "casky"
  desc "Set up a Mac with Homebrew apps, command-line tools and App Store apps"
  homepage "https://casky.app/"

  depends_on macos: ">= :tahoe"

  app "Casky.app"

  zap trash: [
    "~/Library/Application Support/casky",
    "~/Library/Caches/casky",
  ]
end
