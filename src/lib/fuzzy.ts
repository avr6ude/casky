import Fuse from "fuse.js";
import type { Cask } from "./caskTypes";

export type FuseInstance = Fuse<Cask>;

export function createFuse(casks: Cask[]): FuseInstance {
  return new Fuse(casks, {
    keys: [
      { name: "token", weight: 2 },
      { name: "name", weight: 1.5 },
    ],
    threshold: 0.3,
    ignoreLocation: true,
    minMatchCharLength: 2,
    shouldSort: true,
    findAllMatches: false,
    distance: 50,
  });
}
