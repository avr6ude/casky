export type Collection = {
  slug: string;
  emoji: string;
  title: string;
  desc: string;
  tokens: string[];
};

export const collections: Collection[] = [
  {
    slug: "essentials",
    emoji: "🛠",
    title: "New Mac essentials",
    desc: "What you install first on a fresh Mac.",
    tokens: [
      "google-chrome",
      "firefox",
      "1password",
      "the-unarchiver",
      "rectangle",
      "raycast",
      "vlc",
      "spotify",
      "iina",
      "appcleaner",
    ],
  },
  {
    slug: "designer",
    emoji: "🎨",
    title: "Designer kit",
    desc: "Tools for a working designer Mac.",
    tokens: [
      "figma",
      "linear-linear",
      "slack",
      "raycast",
      "sip",
      "cleanshot",
      "pixelmator-pro",
      "blender",
      "iterm2",
    ],
  },
  {
    slug: "dev",
    emoji: "👩‍💻",
    title: "Developer kit",
    desc: "Battle-tested dev environment.",
    tokens: [
      "iterm2",
      "visual-studio-code",
      "docker",
      "orbstack",
      "bruno",
      "rectangle",
      "raycast",
      "fork",
      "tableplus",
      "warp",
    ],
  },
  {
    slug: "writer",
    emoji: "✍️",
    title: "Writer kit",
    desc: "For long-form writers and note nerds.",
    tokens: [
      "obsidian",
      "ia-writer",
      "bear",
      "grammarly-desktop",
      "hazeover",
      "raycast",
      "logseq",
    ],
  },
  {
    slug: "privacy",
    emoji: "🛡",
    title: "Privacy power user",
    desc: "Lock it down end-to-end.",
    tokens: [
      "mullvadvpn",
      "proton-pass",
      "bitwarden",
      "signal",
      "mullvad-browser",
      "oversight",
      "micro-snitch",
      "tor-browser",
    ],
  },
  {
    slug: "streamer",
    emoji: "🎙",
    title: "Streamer / podcaster",
    desc: "Capture, mix, and ship audio + video.",
    tokens: [
      "obs",
      "discord",
      "loopback",
      "krisp",
      "shottr",
      "audacity",
      "blackhole-2ch",
    ],
  },
  {
    slug: "ai",
    emoji: "🧠",
    title: "AI workstation",
    desc: "Local LLMs and AI dev tools.",
    tokens: [
      "ollama",
      "lm-studio",
      "cursor",
      "claude",
      "raycast",
      "msty",
      "iterm2",
    ],
  },
];
