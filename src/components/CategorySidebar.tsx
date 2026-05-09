import { Stack, Box, styled } from "styled-system/jsx";
import { useFiltersStore } from "@/store/filters";
import type { CaskCategory } from "@/lib/caskTypes";
import {
  Globe,
  MessageSquare,
  Code2,
  Palette,
  Music,
  Video,
  Gamepad2,
  Briefcase,
  Shield,
  Wrench,
  Pencil,
  LayoutGrid,
  Sparkles,
  DollarSign,
  Cpu,
  Network,
  FolderOpen,
  GraduationCap,
  type LucideIcon,
} from "lucide-react";

const CATS: Array<{ id: CaskCategory | "all"; label: string; icon: LucideIcon }> = [
  { id: "all", label: "All apps", icon: LayoutGrid },
  { id: "ai", label: "AI", icon: Sparkles },
  { id: "browsers", label: "Browsers", icon: Globe },
  { id: "communication", label: "Communication", icon: MessageSquare },
  { id: "developer", label: "Developer", icon: Code2 },
  { id: "design", label: "Design", icon: Palette },
  { id: "audio", label: "Audio", icon: Music },
  { id: "video", label: "Video", icon: Video },
  { id: "games", label: "Games", icon: Gamepad2 },
  { id: "productivity", label: "Productivity", icon: Briefcase },
  { id: "writing", label: "Writing & Notes", icon: Pencil },
  { id: "privacy", label: "Privacy", icon: Shield },
  { id: "finance", label: "Finance", icon: DollarSign },
  { id: "system", label: "System", icon: Cpu },
  { id: "network", label: "Network", icon: Network },
  { id: "files", label: "Files", icon: FolderOpen },
  { id: "education", label: "Education", icon: GraduationCap },
  { id: "utilities", label: "Utilities", icon: Wrench },
];

const NavItem = styled("button", {
  base: {
    display: "flex",
    alignItems: "center",
    gap: "3",
    w: "full",
    px: "3",
    py: "2",
    borderRadius: "l2",
    color: "fg.muted",
    textAlign: "left",
    fontSize: "sm",
    cursor: "pointer",
    transition: "background 120ms ease, color 120ms ease",
    _hover: { bg: "gray.3", color: "fg.default" },
  },
  variants: {
    active: {
      true: { bg: "violet.3", color: "violet.11", fontWeight: "medium" },
    },
  },
});

export function CategorySidebar() {
  const category = useFiltersStore((s) => s.category);
  const setCategory = useFiltersStore((s) => s.setCategory);

  return (
    <Box as="nav" aria-label="Categories" p="2">
      <Stack gap="1">
        {CATS.map((c) => {
          const Icon = c.icon;
          return (
            <NavItem
              key={c.id}
              active={category === c.id}
              onClick={() => setCategory(c.id)}
            >
              <Icon size={16} />
              {c.label}
            </NavItem>
          );
        })}
      </Stack>
    </Box>
  );
}
