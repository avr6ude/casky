import type { Cask, CaskCategory } from "./caskTypes";

type Rule = {
  cat: CaskCategory;
  tests: Array<[RegExp, number]>;
};

const RULES: Rule[] = [
  {
    cat: "ai",
    tests: [
      [/\b(claude|chatgpt|gpt[- ]?\d?|copilot|cursor|cody|continue|aider|ollama|lm[- ]?studio|llamafile|gpt4all|jan|msty|chatbox|openai|anthropic|perplexity|mistral|llama|mlx|stable[- ]?diffusion|midjourney|comfyui|automatic1111|invokeai|drawthings|diffusion[- ]?bee|elsa|elevenlabs|whisper|witsy|pinokio|lobe[- ]?chat|enchanted|macai|pico[- ]?ai|sanctum|mochi[- ]?diffusion|fooocus|wonderdraft)\b/i, 3],
      [/\b(\bai\b|llm|machine[- ]?learning|deep[- ]?learning|neural|transcribe|transcription|generative|chatbot|nlp|inference|prompt[- ]?engineer|tensor|pytorch|tensorflow|huggingface|cogvideo)\b/i, 2],
    ],
  },
  {
    cat: "browsers",
    tests: [
      [/\b(browser|chromium|firefox|safari|webkit|chrome|edge|brave|arc|opera|vivaldi|orion|tor[- ]?browser|min|sidekick|ungoogled|librewolf|waterfox|zen|floorp|comet|island|sigmaos|wavebox|shift|coccoc|ghost[- ]?browser|polypane|rambox|stack|maxthon|epic|dot|seamonkey|pale[- ]?moon|midori|otter|qutebrowser|nyxt|yandex|duckduckgo)\b/i, 3],
      [/\b(web[- ]?browser|browse|browsing|html5)\b/i, 1],
    ],
  },
  {
    cat: "communication",
    tests: [
      [/\b(slack|discord|telegram|whatsapp|signal|zoom|teams|messenger|skype|webex|matrix|element|wire|threema|session|wickr|imessage|beeper|texts|cinny|fluffychat|nheko|gajim|pidgin|adium|ferdium|rambox|station|chatwork|line|kakao|wechat|viber|trillian|chatty|messages|fb-messenger|google[- ]?meet|google[- ]?chat|jitsi|talky|whereby|tandem|gather|teamflow)\b/i, 3],
      [/\b(email|mail-?client|spark|airmail|edison|mailspring|thunderbird|canary|mimestream|kiwi|newton|hey|polymail|spike|mail\.app|outlook|protonmail|tutanota|notmuch|mailmate|mimemail|fluent|n1|maildrop)\b/i, 3],
      [/\b(chat|irc|conference|video[- ]?call|video[- ]?conferenc|messaging|sms|fax|voip|softphone|im[- ]?client|jabber|xmpp)\b/i, 2],
      [/\b(twitter|mastodon|bluesky|reddit|tweetbot|tweetdeck|twidere|mona|ivory|ice[- ]?cubes|mammoth)\b/i, 2],
    ],
  },
  {
    cat: "developer",
    tests: [
      [/\b(ide|editor|vscode|visual[- ]?studio|sublime|textmate|atom|nova|zed|fleet|jetbrains|intellij|webstorm|pycharm|phpstorm|rubymine|goland|clion|rider|datagrip|appcode|aqua|xcode|android-studio|emacs|vim|neovim|kakoune|micro|helix|lapce)\b/i, 3],
      [/\b(terminal|iterm|warp|alacritty|kitty|wezterm|tabby|hyper|fluent[- ]?terminal|tmux|byobu|ghostty|terminus|royal[- ]?ts)\b/i, 3],
      [/\b(docker|podman|lima|colima|orbstack|kubernetes|kubectl|k9s|minikube|rancher|portainer|lens|kompose|kustomize)\b/i, 3],
      [/\b(git\b|sourcetree|tower|fork|gitkraken|gitup|gitfox|gitnuro|sublime[- ]?merge|magit|lazygit|gh\b|gitlab|forgejo|gittower|gitless|githubdesktop|github)\b/i, 3],
      [/\b(database|postgres|mysql|mariadb|sqlite|redis|mongodb|cassandra|clickhouse|cockroach|sequel[- ]?(pro|ace)|tableplus|datagrip|dbgate|dbeaver|navicat|beekeeper|mongoclient|noco-?db|supabase|sqlitestudio|cosmosdb|robo3t)\b/i, 3],
      [/\b(api|rest|graphql|postman|insomnia|bruno|hoppscotch|paw|nightingale|apidog|httpie|rapidapi|thunder|kreya|stoplight|swagger|openapi)\b/i, 3],
      [/\b(devtools|developer|programming|sdk|simulator|emulator|virtual-?box|vmware|parallels|utm|qemu|burp|wireshark|charles|proxyman|ngrok|localtunnel|reqable|httptoolkit)\b/i, 2],
      [/\b(node|deno|bun|python|ruby|php|java|rust|go\b|swift|kotlin|elixir|nvm|pyenv|rbenv|asdf|cargo|composer|maven|gradle|npm|yarn|pnpm|webpack|vite|rollup|esbuild|cmake|make)\b/i, 2],
      [/\b(jupyter|notebook|datascience|conda|miniforge|mamba|spyder|rstudio|matlab|octave)\b/i, 2],
      [/\b(reverse[- ]?engineering|hex[- ]?editor|disassembl|debugger|profiler|reverser|hopper|ida[- ]?pro|ghidra|cutter|binary[- ]?ninja)\b/i, 2],
      [/-cli$|-tools?$|-sdk$|-dev$|^dev[- ]/i, 1],
    ],
  },
  {
    cat: "design",
    tests: [
      [/\b(figma|sketch|invision|framer|principle|protopie|origami|adobe|photoshop|illustrator|after[- ]?effects|premiere|xd|lightroom|affinity|pixelmator|acorn|gimp|krita|inkscape|blender|cinema-?4d|spline|tldraw|excalidraw|whimsical|miro|mural|drawio|drawing|moho|toon[- ]?boom|clip[- ]?studio|procreate)\b/i, 3],
      [/\b(color[- ]?picker|palette|sip|colorsnapper|pixel[- ]?picker|hex[- ]?fiend|fontbase|font[- ]?expl|rightfont|font[- ]?goggles|fontagent|fontlab|glyphs|font[- ]?creator|nucleo|iconjar|iconset)\b/i, 3],
      [/\b(icon|svg|vector|asset|wireframe|prototype|mockup|design[- ]?tool|ui[- ]?kit|font|typography|3d[- ]?model|gltf|usd|usdz|render|renderer)\b/i, 1],
    ],
  },
  {
    cat: "audio",
    tests: [
      [/\b(spotify|apple[- ]?music|tidal|deezer|soundcloud|qobuz|amazon-?music|youtube[- ]?music|sonos|airfoil|vox|swinsian|cog|colibri|doppler|audirvana|musicbox|sayonara|strawberry|nuclear|mpd)\b/i, 3],
      [/\b(logic-?pro|garageband|reaper|ableton|fl-?studio|cubase|studio-?one|protools|bitwig|reason|maschine|massive|serum|n-?track|tracktion|mixxx|traktor|virtual[- ]?dj|rekordbox|serato)\b/i, 3],
      [/\b(audacity|ocenaudio|amadeus|fission|wavepad|sound[- ]?forge|izotope|loopback|krisp|soundsource|background-?music|hush|microsnitch|amphetamine|autoeq|equalizer[- ]?apo|easyeq|airpods|airpods[- ]?pro)\b/i, 3],
      [/\b(audio|music|equalizer|mixer|microphone|midi|vst|au-?plugin|synth|metronome|tuner|guitar|piano|drum|sample[- ]?library|daw)\b/i, 2],
      [/\b(podcast|podcatcher|overcast|pocket-?casts|broadcasts|fission|hindenburg|farrago|piezo|capto[- ]?audio)\b/i, 3],
    ],
  },
  {
    cat: "video",
    tests: [
      [/\b(vlc|iina|mpv|elmedia|movist|infuse|plex|jellyfin|emby|kodi|stremio|netflix|youtube|disney|hulu|prime-?video|peacock|paramount|max\b)\b/i, 3],
      [/\b(obs|streamlabs|tella|loom|cleanshot|kap|gifox|gif-?brewery|capto|screenflow|camtasia|riverside|descript|recordit|gif[- ]?ski|licecap)\b/i, 3],
      [/\b(premiere|final-?cut|davinci|resolve|kdenlive|losslesscut|handbrake|ffmpeg|shotcut|filmora|hitfilm|imovie|motion|compressor|wondershare|aiseesoft|video[- ]?proc|adobe[- ]?premiere)\b/i, 3],
      [/\b(video|movie|film|player|streamer|recorder|screen[- ]?capture|camera|webcam|youtube[- ]?dl|yt[- ]?dlp|video[- ]?download)\b/i, 2],
      [/\b(subtitle|srt|aegisub|jubler|subler|videoinspector)\b/i, 2],
    ],
  },
  {
    cat: "games",
    tests: [
      [/\b(steam|epic-?games|gog|battle\.?net|ea\b|origin|ubisoft|riot|league|valorant|rocket-?league|world-?of|crossover|whisky|playcover|joystick|game-?porting|game[- ]?center|gamemaker|godot|unity|unreal|construct|defold|stencyl|playmaker)\b/i, 3],
      [/\b(emulator|openemu|retroarch|dolphin|cemu|ppsspp|mame|snes|nes|gameboy|playstation|xbox|nintendo|atari|amiga|fceux|pcsx|melon|duckstation|rpcs3|yuzu|ryujinx|citra|skyemu|n64)\b/i, 3],
      [/\b(minecraft|prismlauncher|atlauncher|multimc|world[- ]?of[- ]?warcraft|battle[- ]?net|moonlight|sunshine|parsec|stadia|geforce[- ]?now|xbox[- ]?cloud)\b/i, 3],
      [/\b(game|gaming|controller|gamepad|joystick|fighting|rpg|mmorpg|fps|shooter|simulator|sandbox|emu|emulation)\b/i, 1],
    ],
  },
  {
    cat: "writing",
    tests: [
      [/\b(obsidian|logseq|anytype|roam|tana|reflect|capacities|notion|appflowy|outline|bear|ulysses|ia[- ]?writer|drafts|simplenote|standard[- ]?notes|joplin|trilium|silverbullet|dendron|foam|amplenote|workflowy|supernotes|amplenote|noteplan|notesnook|inkdrop|mochi|mem|reflect|nimbus)\b/i, 3],
      [/\b(typora|marktext|zettlr|ghostwriter|inkdrop|cotedit|nota|pages|word|libreoffice|onlyoffice|scrivener|pretext|texshop|texstudio|mactex|texifier|focuswriter|byword|writeroom|writemonkey|fountain|highland)\b/i, 3],
      [/\b(markdown|markup|writer|note-?taking|journal|diary|essay|long-?form|wiki|outliner|second[- ]?brain|knowledge[- ]?base|zettelkasten)\b/i, 1],
      [/\b(grammarly|languagetool|prowritingaid|hemingway|antidote|deepl)\b/i, 2],
    ],
  },
  {
    cat: "privacy",
    tests: [
      [/\b(mullvad|mullvadvpn|protonvpn|nordvpn|expressvpn|surfshark|ivpn|cyberghost|windscribe|tunnelbear|tor\b|wireguard|openvpn|tailscale|netbird|zerotier|innernet|cloudflare-?warp|warp-?cli|hidemy|astrill|pia)\b/i, 3],
      [/\b(bitwarden|1password|keepass|enpass|lastpass|nordpass|dashlane|proton-?pass|strongbox|secrets|keychain|psono|2fa|authenticator|raivo|otpauth)\b/i, 3],
      [/\b(little-?snitch|lulu|micro-?snitch|oversight|do[- ]?not[- ]?disturb|ghostery|adblock|ublock|adguard|pi-?hole|blokada|nextdns|controld|hands[- ]?off)\b/i, 3],
      [/\b(privacy|encrypt|gpg|pgp|crypto[- ]?wallet|veracrypt|cryptomator|onionshare|bitwarden-?send|wormhole|magic[- ]?wormhole|tresorit|encrypted)\b/i, 2],
    ],
  },
  {
    cat: "productivity",
    tests: [
      [/\b(raycast|alfred|launchbar|spotlight|quicksilver|dropzone|hammerspoon|keyboard[- ]?maestro|better[- ]?touch[- ]?tool|karabiner|hyperkey|superkey|launcher)\b/i, 3],
      [/\b(things|omnifocus|todoist|tick[- ]?tick|reminder|microsoft-?to-?do|taskpaper|2do|cardhop|fantastical|busycal|cron|notion-?calendar|dato|itsycal|calendar|calendr|amie|akiflow|sunsama|motion|sorted|skedpal)\b/i, 3],
      [/\b(rectangle|magnet|loop|amethyst|mosaic|moom|divvy|tile|spectacle|window[- ]?manager|hazeover|lungo|amphetamine|caffeinate|tiles|swish|stay)\b/i, 3],
      [/\b(notion|airtable|coda|baserow|nocodb|trello|asana|monday|clickup|linear|height|jira|shortcut|basecamp|kanban|trickster|stickies|height|todoist)\b/i, 3],
      [/\b(focus|pomodoro|timer|toggl|clockify|harvest|rescuetime|timing|qbserve|tyme|hours|now-?then|productive|streaks|habit|habitica|forest|cold[- ]?turkey|self[- ]?control)\b/i, 2],
      [/\b(productivity|workflow|getting[- ]?things[- ]?done|gtd)\b/i, 1],
    ],
  },
  {
    cat: "finance",
    tests: [
      [/\b(quickbooks|freshbooks|wave|xero|gnucash|moneydance|banktivity|copilot[- ]?money|monarch|ynab|mint|simplifi|empower|fidelity|robinhood|coinbase|kraken|binance|trezor|ledger|exodus|metamask|wasabi|sparrow|electrum|trading-?view|bloomberg|invoice|receipt|tax|expense|budget|stripe|paypal|venmo|zelle|cashapp|revolut|wise|n26)\b/i, 3],
      [/\b(crypto|bitcoin|ethereum|defi|stock|portfolio|trading|invest|finance|accounting|payroll|taxes|tax[- ]?software|expense[- ]?tracker|bookkeeping)\b/i, 2],
      [/\b(wallet|hardware[- ]?wallet|cold[- ]?storage|hot[- ]?storage|seed[- ]?phrase|hd[- ]?wallet)\b/i, 1],
    ],
  },
  {
    cat: "system",
    tests: [
      [/\b(cleanmymac|onyx|app[- ]?cleaner|monolingual|maintenance|sensei|disk[- ]?utility|daisydisk|grandperspective|disk[- ]?inventory|omnidisksweeper|driveduck|drivedx|coconut[- ]?battery|battery|sleeper|insomniax|stats|istat|menubar|sensors|mac-?fan|fan[- ]?control|aldente|smcfancontrol|monitor[- ]?control|cscreen|hidden[- ]?bar|barbee|swift[- ]?defaults|defaults[- ]?write)\b/i, 3],
      [/\b(updater|cleaner|optimizer|memory|cpu|gpu|monitor|process|activity|launchd|plist|defaults|terminal-?notifier|brew\b|homebrew|cakebrew|applite|brewmate|latest)\b/i, 2],
      [/\b(system[- ]?prefs|control[- ]?center|spotlight|dock|menu[- ]?bar|menubar|tray|status[- ]?bar|widgets?|sidecar)\b/i, 1],
    ],
  },
  {
    cat: "network",
    tests: [
      [/\b(ssh|sftp|ftp|cyberduck|forklift|transmit|filezilla|mountain[- ]?duck|expandrive|nfs|samba|smb|webdav|rclone|rsync|cron|crontab|core[- ]?tunnel|secret[- ]?ts|royal[- ]?ts)\b/i, 3],
      [/\b(network|firewall|router|wifi|wifi-?explorer|inssider|netspot|wireshark|charles|proxyman|tcp|ping|traceroute|whois|dns|dnscrypt|ngrok|cloudflared|reqable|fiddler)\b/i, 2],
      [/\b(remote[- ]?desktop|rdp|vnc|teamviewer|anydesk|chrome[- ]?remote|jump[- ]?desktop|royal[- ]?ts|microsoft-?remote-?desktop)\b/i, 3],
    ],
  },
  {
    cat: "files",
    tests: [
      [/\b(the-?unarchiver|keka|betterzip|stuffit|archive|zip|7zip|rar|tar|gzip|p7zip|unrarx|izip|archiver)\b/i, 3],
      [/\b(yoink|dropover|unclutter|hookmark|hook|paw|airdroid|sync\b|syncthing|resilio|dropbox|onedrive|google-?drive|icloud|mega|pcloud|nextcloud|owncloud|seafile|tresorit|cryptomator|backblaze|arq|carbon[- ]?copy|chronosync|time[- ]?machine|hazel|file-?juicer|forklift|path-?finder|default[- ]?folder|finder|nimble[- ]?commander|commander[- ]?one|marta|xtrafinder)\b/i, 3],
      [/\b(file[- ]?manager|file[- ]?browser|file[- ]?sync|cloud[- ]?storage|file[- ]?share|backup|restore|snapshot|encrypt[- ]?file|secure[- ]?delete|trash|shredder)\b/i, 2],
      [/\b(pdf|preview|skim|pdfpen|adobe[- ]?acrobat|nitro[- ]?pdf|highlight|annotate|sign[- ]?pdf|combinepdfs|pdfsam)\b/i, 2],
    ],
  },
  {
    cat: "education",
    tests: [
      [/\b(anki|memrise|duolingo|quizlet|babbel|drops|languagetool|grammarly|reverso|deepl|linguee|wordbook|dictionary|thesaurus|wikipedia|kiwix|zotero|paperpile|mendeley|readcube|onyx|goodnotes|notability|paper|liquidtext|kindle|ibooks|apple[- ]?books|calibre|alfred-?bookends|busuu|rosetta|lingq|clozemaster|fluent[- ]?u|eikaiwa|readwise|pocket|instapaper|matter|reeder)\b/i, 3],
      [/\b(study|learn|flashcard|course|tutorial|reference|encyclopedia|atlas|textbook|education|teaching|classroom|coursework|homework|mooc)\b/i, 1],
    ],
  },
  {
    cat: "utilities",
    tests: [
      [/\b(menu[- ]?bar|hot[- ]?key|hotkey|shortcut|launcher|workflow|automate|service|popclip|paste|copyclip|maccy|clipboard|pastebot|alfred-?clipboard|copyless|clipy|flycut|copilot|pasta)\b/i, 3],
      [/\b(snippet|expansion|text[- ]?expander|atext|alfred-?snippet|espanso|rocket|typinator|keyboard-?cleantool|hidden-?bar|bartender|ice|barbee|dozer|vanilla|onepiece)\b/i, 3],
      [/\b(utility|tool|widget|tweak|customize|control|toggle|switcher|indicator|fan[- ]?speed)\b/i, 1],
      [/\b(screenshot|screen[- ]?capture|screencap|grab|cleanshot|shottr|capto|skitch|monosnap|gyazo|annotate)\b/i, 3],
    ],
  },
];

function extractText(c: Cask): string {
  const artifactStr = JSON.stringify(c.artifacts ?? []).slice(0, 400);
  return [c.token, ...(c.name ?? []), c.desc ?? "", artifactStr]
    .join(" ")
    .toLowerCase();
}

export function categorize(c: Cask): CaskCategory {
  const haystack = extractText(c);
  let bestCat: CaskCategory = "other";
  let bestScore = 0;

  for (const rule of RULES) {
    let score = 0;
    for (const [re, weight] of rule.tests) {
      const flags = re.flags.includes("g") ? re.flags : re.flags + "g";
      const matches = haystack.match(new RegExp(re.source, flags));
      if (matches) score += matches.length * weight;
    }
    if (score > bestScore) {
      bestScore = score;
      bestCat = rule.cat;
    }
  }

  return bestCat;
}
