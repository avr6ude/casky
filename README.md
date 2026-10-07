# casky

A native macOS app for setting up a Mac: pick a kit or search, then install apps (Homebrew casks), command-line tools (formulae) and Mac App Store apps in one go. Homebrew and [`mas`](https://github.com/mas-cli/mas) do the installing; casky is the friendly layer on top.

- Kits, saved setups, and "Save This Mac" snapshots
- Brewfile export and import (import reads plain entries only and never executes the file)
- Shows what's already installed; installs one item at a time with live output, Stop and Retry
- Asks for your Mac password in a native dialog only when an install needs it
- Optional daily app updates (Settings), run by a launchd agent you can also turn off in Login Items

Requires macOS 26 and Homebrew (casky offers to download the official installer if it's missing).

## Develop

Open `Casky.xcodeproj` in Xcode 27, or from the command line:

```sh
xcodebuild -project Casky.xcodeproj -scheme Casky -destination 'platform=macOS' -derivedDataPath build test
```

The app is not sandboxed (it runs `brew`, `mas` and `sudo`) and uses the hardened runtime.

## Release

```sh
TEAM_ID=XXXXXXXXXX scripts/release.sh     # Developer ID signed, notarized DMG
scripts/release.sh --unsigned             # local dry run
```

Then update `packaging/casky.rb` with the new version and SHA-256 and copy it to the tap.

The retired web app lives in `legacy-web/` (gitignored) for reference.

## License

MIT for the casky source. Package metadata comes from the Homebrew project and the App Store.
