import type { Cask, CaskCategory } from "./caskTypes";

type Rule = {
  cat: CaskCategory;
  tests: Array<[RegExp, number]>;
};

const RULES: Rule[] = [
  {
    cat: "ai",
    tests: [
      [/\b(claude|chatgpt|gpt-4|copilot|cursor|cody|continue|aider|ollama|lm-?studio|llamafile|gpt4all|jan|msty|chatbox|openai|anthropic|perplexity|mistral|llama|mlx)\b/i, 3],
      [/\b(ai\b|llm|machine[- ]?learning|neural|transcription|whisper|stable[- ]?diffusion|midjourney|comfyui|automatic1111|flux)\b/i, 2],
    ],
  },
  {
    cat: "browsers",
    tests: [
      [/\b(browser|chromium|firefox|safari|webkit|chrome|edge|brave|arc|opera|vivaldi|orion|tor[- ]?browser|min|sidekick|ungoogled|librewolf|waterfox|zen|floorp|comet|island|sigmaos|wavebox|shift)\b/i, 3],
    ],
  },
  {
    cat: "communication",
    tests: [
      [/\b(slack|discord|telegram|whatsapp|signal|zoom|teams|messenger|skype|webex|matrix|element|wire|threema|session|wickr|imessage|beeper|texts|cinny|fluffychat|nheko|gajim|pidgin|adium|ferdium|rambox|station)\b/i, 3],
      [/\b(email|mail-?client|spark|airmail|edison|mailspring|thunderbird|canary|mimestream|kiwi|newton|hey|polymail|spike|mail\.app|outlook|protonmail|tutanota|notmuch)\b/i, 3],
      [/\b(chat|irc|conference|video[- ]?call|messaging|sms|fax)\b/i, 1],
    ],
  },
  {
    cat: "developer",
    tests: [
      [/\b(ide|editor|vscode|visual[- ]?studio|sublime|textmate|atom|nova|zed|fleet|jetbrains|intellij|webstorm|pycharm|phpstorm|rubymine|goland|clion|rider|datagrip|appcode|aqua|xcode|android-studio)\b/i, 3],
      [/\b(terminal|iterm|warp|alacritty|kitty|wezterm|tabby|hyper|fluent[- ]?terminal|tmux|byobu|ghostty)\b/i, 3],
      [/\b(docker|podman|lima|colima|orbstack|kubernetes|kubectl|k9s|minikube|rancher|portainer|lens)\b/i, 3],
      [/\b(git\b|sourcetree|tower|fork|gitkraken|gitup|gitfox|gitnuro|sublime[- ]?merge|magit|lazygit|gh\b|gitlab|forgejo)\b/i, 3],
      [/\b(database|postgres|mysql|mariadb|sqlite|redis|mongodb|cassandra|clickhouse|cockroach|sequel[- ]?(pro|ace)|tableplus|datagrip|dbgate|dbeaver|navicat|beekeeper|mongoclient|noco-?db|supabase)\b/i, 3],
      [/\b(api|rest|graphql|postman|insomnia|bruno|hoppscotch|paw|nightingale|apidog|httpie|rapidapi|thunder)\b/i, 3],
      [/\b(devtools|developer|programming|sdk|simulator|emulator|virtual-?box|vmware|parallels|utm|qemu|burp|wireshark|charles|proxyman|ngrok|localtunnel)\b/i, 2],
      [/\b(node|deno|bun|python|ruby|php|java|rust|go\b|swift|kotlin|elixir|nvm|pyenv|rbenv|asdf|cargo|composer)\b/i, 1],
    ],
  },
  {
    cat: "design",
    tests: [
      [/\b(figma|sketch|invision|framer|principle|protopie|origami|adobe|photoshop|illustrator|after[- ]?effects|premiere|xd|lightroom|affinity|pixelmator|acorn|gimp|krita|inkscape|blender|cinema-?4d|spline|tldraw|excalidraw|whimsical|miro|mural|drawio)\b/i, 3],
      [/\b(color[- ]?picker|palette|sip|colorsnapper|pixel[- ]?picker|hex[- ]?fiend|fontbase|font[- ]?expl|rightfont|font-?goggles|fontagent)\b/i, 3],
      [/\b(icon|svg|asset|wireframe|prototype|mockup|design-?tool|ui[- ]?kit|font|typography)\b/i, 1],
    ],
  },
  {
    cat: "audio",
    tests: [
      [/\b(spotify|apple[- ]?music|tidal|deezer|soundcloud|qobuz|amazon-?music|youtube[- ]?music|sonos|airfoil|vox|swinsian|cog|colibri|doppler|audirvana)\b/i, 3],
      [/\b(logic-?pro|garageband|reaper|ableton|fl-?studio|cubase|studio-?one|protools|bitwig|reason|maschine|massive|serum)\b/i, 3],
      [/\b(audacity|ocenaudio|amadeus|fission|wavepad|sound[- ]?forge|izotope|loopback|krisp|soundsource|background-?music|hush|microsnitch|amphetamine|autoeq)\b/i, 3],
      [/\b(audio|music|equalizer|mixer|podcast|microphone|midi|vst|au-?plugin|synth)\b/i, 1],
    ],
  },
  {
    cat: "video",
    tests: [
      [/\b(vlc|iina|mpv|elmedia|movist|infuse|plex|jellyfin|emby|kodi|stremio|netflix|youtube|disney|hulu|prime-?video)\b/i, 3],
      [/\b(obs|streamlabs|tella|loom|cleanshot|kap|gifox|gif-?brewery|capto|screenflow|camtasia|riverside|descript)\b/i, 3],
      [/\b(premiere|final-?cut|davinci|resolve|kdenlive|losslesscut|handbrake|ffmpeg|shotcut|filmora|hitfilm|imovie)\b/i, 3],
      [/\b(video|movie|film|player|streamer|recorder|screen[- ]?capture|camera)\b/i, 1],
    ],
  },
  {
    cat: "games",
    tests: [
      [/\b(steam|epic-?games|gog|battle\.?net|ea\b|origin|ubisoft|riot|league|valorant|rocket-?league|world-?of|crossover|whisky|playcover|joystick|game-?porting|game[- ]?center)\b/i, 3],
      [/\b(emulator|openemu|retroarch|dolphin|cemu|ppsspp|mame|snes|nes|gameboy|playstation|xbox|nintendo)\b/i, 3],
      [/\b(minecraft|prismlauncher|atlauncher|multimc|world[- ]?of[- ]?warcraft)\b/i, 3],
    ],
  },
  {
    cat: "writing",
    tests: [
      [/\b(obsidian|logseq|anytype|roam|tana|reflect|capacities|notion|appflowy|outline|bear|ulysses|ia[- ]?writer|drafts|simplenote|standard[- ]?notes|joplin|trilium|silverbullet|dendron|foam)\b/i, 3],
      [/\b(typora|marktext|zettlr|ghostwriter|inkdrop|cotedit|nota|pages|word|libreoffice|onlyoffice|scrivener|pretext|texshop|texstudio|mactex)\b/i, 3],
      [/\b(markdown|markup|writer|editor|note-?taking|journal|diary|essay|long-?form)\b/i, 1],
    ],
  },
  {
    cat: "privacy",
    tests: [
      [/\b(mullvad|protonvpn|nordvpn|expressvpn|surfshark|ivpn|cyberghost|windscribe|tunnelbear|tor\b|wireguard|openvpn|tailscale|netbird|zerotier|innernet)\b/i, 3],
      [/\b(bitwarden|1password|keepass|enpass|lastpass|nordpass|dashlane|proton-?pass|strongbox|secrets|keychain|vault|psono|2fa|authenticator)\b/i, 3],
      [/\b(little-?snitch|lulu|micro-?snitch|oversight|do[- ]?not[- ]?disturb|ghostery|adblock|ublock|adguard|pi-?hole|blokada|nextdns|controld)\b/i, 3],
      [/\b(privacy|encrypt|gpg|pgp|crypto[- ]?wallet|veracrypt|cryptomator|onionshare|bitwarden-?send|wormhole|magic[- ]?wormhole)\b/i, 2],
    ],
  },
  {
    cat: "productivity",
    tests: [
      [/\b(raycast|alfred|launchbar|spotlight|quicksilver|dropzone|hammerspoon|keyboard[- ]?maestro|better[- ]?touch[- ]?tool|karabiner|hyperkey|superkey)\b/i, 3],
      [/\b(things|omnifocus|todoist|tick[- ]?tick|reminder|microsoft-?to-?do|taskpaper|2do|cardhop|fantastical|busycal|cron|notion-?calendar|dato|itsycal|calendar|calendr|amie)\b/i, 3],
      [/\b(rectangle|magnet|loop|amethyst|mosaic|moom|divvy|tile|spectacle|window[- ]?manager|hazeover|lungo|amphetamine|caffeinate)\b/i, 3],
      [/\b(notion|airtable|coda|baserow|nocodb|trello|asana|monday|clickup|linear|height|jira|shortcut|basecamp|kanban|trickster|stickies)\b/i, 3],
      [/\b(focus|pomodoro|timer|toggl|clockify|harvest|rescuetime|timing|qbserve|tyme|hours|now-?then|productive|streaks|habit)\b/i, 2],
    ],
  },
  {
    cat: "finance",
    tests: [
      [/\b(quickbooks|freshbooks|wave|xero|gnucash|moneydance|banktivity|copilot[- ]?money|monarch|ynab|mint|simplifi|empower|fidelity|robinhood|coinbase|kraken|binance|trezor|ledger|exodus|metamask|wasabi|sparrow|electrum|trading-?view|bloomberg|invoice|receipt|tax|expense|budget)\b/i, 3],
      [/\b(crypto|bitcoin|ethereum|wallet|defi|stock|portfolio|trading|invest|finance|accounting|payroll)\b/i, 1],
    ],
  },
  {
    cat: "system",
    tests: [
      [/\b(cleanmymac|onyx|app[- ]?cleaner|monolingual|maintenance|sensei|disk[- ]?utility|daisydisk|grandperspective|disk[- ]?inventory|omnidisksweeper|driveduck|drivedx|coconut[- ]?battery|battery|amphetamine|caffeine|sleeper|insomniax|stats|istat|menubar|sensors|mac-?fan|fan[- ]?control|aldente)\b/i, 3],
      [/\b(updater|cleaner|optimizer|memory|cpu|gpu|monitor|process|activity|launchd|plist|defaults|terminal-?notifier|brew\b|homebrew|cakebrew|applite)\b/i, 2],
    ],
  },
  {
    cat: "network",
    tests: [
      [/\b(ssh|sftp|ftp|cyberduck|forklift|transmit|filezilla|mountain[- ]?duck|expandrive|nfs|samba|smb|webdav|rclone|rsync|cron|crontab)\b/i, 3],
      [/\b(network|firewall|router|wifi|wifi-?explorer|inssider|netspot|wireshark|charles|proxyman|tcp|ping|traceroute|whois|dns|dnscrypt|ngrok|cloudflared)\b/i, 2],
    ],
  },
  {
    cat: "files",
    tests: [
      [/\b(the-?unarchiver|keka|betterzip|stuffit|archive|zip|7zip|rar|tar|gzip|p7zip)\b/i, 3],
      [/\b(yoink|dropover|unclutter|hookmark|hook|paw|airdroid|sync\b|syncthing|resilio|dropbox|onedrive|google-?drive|icloud|mega|pcloud|nextcloud|owncloud|seafile|tresorit|cryptomator|backblaze|arq|carbon[- ]?copy|chronosync|time[- ]?machine|hazel|file-?juicer|forklift|path-?finder|default[- ]?folder|finder|nimble[- ]?commander|commander[- ]?one)\b/i, 3],
    ],
  },
  {
    cat: "education",
    tests: [
      [/\b(anki|memrise|duolingo|quizlet|babbel|drops|languagetool|grammarly|reverso|deepl|linguee|wordbook|dictionary|thesaurus|wikipedia|kiwix|zotero|paperpile|mendeley|readcube|onyx|goodnotes|notability|paper|liquidtext|kindle|ibooks|apple[- ]?books|calibre|alfred-?bookends)\b/i, 3],
      [/\b(study|learn|flashcard|course|tutorial|reference|encyclopedia|atlas)\b/i, 1],
    ],
  },
  {
    cat: "utilities",
    tests: [
      [/\b(menu[- ]?bar|hot[- ]?key|hotkey|shortcut|launcher|workflow|automate|service|popclip|paste|copyclip|maccy|clipboard|pastebot|alfred-?clipboard|copyless|clipy|flycut)\b/i, 3],
      [/\b(snippet|expansion|text[- ]?expander|atext|alfred-?snippet|espanso|rocket|typinator|keyboard-?cleantool|hidden-?bar|bartender|ice|barbee|dozer|vanilla|onepiece)\b/i, 3],
      [/\b(utility|tool|widget|tweak|customize|control)\b/i, 1],
    ],
  },
];

export function categorize(c: Cask): CaskCategory {
  const haystack = [c.token, ...(c.name ?? []), c.desc ?? ""].join(" ").toLowerCase();
  let bestCat: CaskCategory = "other";
  let bestScore = 0;

  for (const rule of RULES) {
    let score = 0;
    for (const [re, weight] of rule.tests) {
      const matches = haystack.match(new RegExp(re.source, re.flags + (re.flags.includes("g") ? "" : "g")));
      if (matches) score += matches.length * weight;
    }
    if (score > bestScore) {
      bestScore = score;
      bestCat = rule.cat;
    }
  }

  return bestCat;
}
