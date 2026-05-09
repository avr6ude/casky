import Fuse from "fuse.js";
import type { Cask } from "./caskTypes";

export type FuseInstance = Fuse<Cask>;

export function createFuse(casks: Cask[]): FuseInstance {
  return new Fuse(casks, {
    keys: [
      { name: "token", weight: 2 },
      { name: "name", weight: 1.5 },
      { name: "desc", weight: 0.7 },
    ],
    threshold: 0.35,
    ignoreLocation: true,
    minMatchCharLength: 2,
  });
}
