# casky

A native macOS app for setting up a Mac: pick a kit or search, then install apps (Homebrew casks), command-line tools (formulae) and Mac App Store apps in one go. Homebrew and [`mas`](https://github.com/mas-cli/mas) do the installing; casky is the friendly layer on top.

- Kits, saved setups, and "Save This Mac" snapshots
- Dotfiles in saved setups: load a Git repository, choose files or folders, and preview a link or copy restore with backups
- Mac preferences in saved setups: capture or edit Dock, Finder, keyboard, screenshot and custom settings, then preview and apply with backups
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

## Dotfiles

Open a saved setup and select **Dotfiles**. Enter an HTTPS or SSH Git URL (optionally a branch or tag), or choose a local Git repository. Load it, add files or folders, and set their destinations relative to your home folder, such as `.zshrc` or `.config/nvim`.

**Link** points to the repository copy Casky keeps on this Mac; **Copy** makes an independent copy. **Preview Restore** saves the configuration and shows what will be created, replaced, or skipped. **Restore** applies those changes. Replaced originals are kept under `~/Library/Application Support/casky/dotfile-backups/`; the result offers **Show Backups**. Folder restores replace the entire folder, rather than merging it.

Repository scripts are never run. Source symlinks, Git submodules and destinations inside linked folders are rejected. SSH uses existing keys without an interactive password prompt. Refreshing reuses a clean checkout of the same revision; new revisions or local edits get a separate checkout so existing links keep their contents until you restore again. Checkouts are retained under `~/Library/Application Support/casky/dotfiles/`.

## Mac Preferences

Open a saved setup and select **Mac Preferences**. Dock, Finder, keyboard and screenshot settings are listed like System Settings; pick a value from each pop-up, or leave it at **Don't Change** to keep it out of the setup. **System Default** removes the explicit override. **Add Custom Setting** takes any domain and key with a Boolean, integer, decimal or text value. Changes save as you make them. **Use This Mac's Values** reads the chosen settings from this Mac; **Apply to This Mac** shows the current and new values before changing anything.

**Apply** saves the original values under `~/Library/Application Support/casky/preference-backups/` before writing current-user preferences. The result offers **Undo** and an explicit Dock and Finder restart when relevant. Other apps may need reopening or signing out. **More → Restore from Backup** previews a previous backup; values changed afterward by another app are protected. Capture only reads explicit values for the current user across all hosts; per-host and system-wide settings are outside this feature.

## License

MIT for the casky source. Package metadata comes from the Homebrew project and the App Store.
