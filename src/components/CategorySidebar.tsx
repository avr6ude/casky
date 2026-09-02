import { useState } from "react";
import { Stack, Box, Flex, styled } from "styled-system/jsx";
import { useFiltersStore } from "@/store/filters";
import { useTapsStore } from "@/store/taps";
import { Input, Spinner, toaster } from "@/components/ui";
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
  Package,
  Plus,
  X,
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

const TapRow = styled("div", {
  base: {
    position: "relative",
    "& [data-remove]": { opacity: 0 },
    _hover: { "& [data-remove]": { opacity: 1 } },
  },
});

const RemoveButton = styled("button", {
  base: {
    position: "absolute",
    right: "1.5",
    top: "50%",
    transform: "translateY(-50%)",
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    w: "5",
    h: "5",
    borderRadius: "l1",
    color: "fg.subtle",
    cursor: "pointer",
    transition: "opacity 120ms ease, background 120ms ease, color 120ms ease",
    _hover: { bg: "gray.4", color: "fg.default" },
  },
});

const AddButton = styled("button", {
  base: {
    display: "flex",
    alignItems: "center",
    gap: "3",
    w: "full",
    px: "3",
    py: "2",
    borderRadius: "l2",
    border: "1px dashed",
    borderColor: "border",
    color: "fg.subtle",
    textAlign: "left",
    fontSize: "sm",
    cursor: "pointer",
    transition: "background 120ms ease, color 120ms ease, border-color 120ms ease",
    _hover: { bg: "gray.3", color: "fg.default", borderColor: "fg.subtle" },
  },
});

function AddTap() {
  const add = useTapsStore((s) => s.add);
  const setCategory = useFiltersStore((s) => s.setCategory);
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reset = () => {
    setOpen(false);
    setValue("");
    setError(null);
  };

  const submit = async () => {
    const name = value.trim();
    if (!name || busy) return;
    setBusy(true);
    setError(null);
    try {
      const tap = await add(name);
      toaster.create({
        title: `Added ${tap.name}`,
        description: `${tap.tokens.length} cask${tap.tokens.length === 1 ? "" : "s"}`,
        type: "success",
      });
      setCategory(tap.name);
      reset();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  if (!open) {
    return (
      <AddButton type="button" onClick={() => setOpen(true)}>
        <Plus size={16} />
        Add tap
      </AddButton>
    );
  }

  return (
    <Stack
      as="form"
      gap="1.5"
      onSubmit={(e: React.FormEvent) => {
        e.preventDefault();
        submit();
      }}
    >
      <Flex gap="1.5" align="center">
        <Input
          size="sm"
          autoFocus
          placeholder="owner/tap-name"
          value={value}
          disabled={busy}
          onChange={(e) => {
            setValue(e.target.value);
            if (error) setError(null);
          }}
          onKeyDown={(e) => {
            if (e.key === "Escape") reset();
            if (e.key === "Enter") {
              e.preventDefault();
              submit();
            }
          }}
          aria-label="Homebrew tap name"
          aria-invalid={error ? true : undefined}
        />
        {busy && <Spinner size="sm" />}
      </Flex>
      {error && (
        <Box fontSize="xs" color="red.11" lineHeight="snug">
          {error}
        </Box>
      )}
      <Box fontSize="xs" color="fg.subtle" lineHeight="snug">
        Pulls the tap's casks from GitHub. Esc to cancel.
      </Box>
    </Stack>
  );
}

export function CategorySidebar() {
  const category = useFiltersStore((s) => s.category);
  const setCategory = useFiltersStore((s) => s.setCategory);
  const taps = useTapsStore((s) => s.taps);
  const removeTap = useTapsStore((s) => s.remove);

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

      {taps.length > 0 && (
        <>
          <Box borderTop="1px solid" borderColor="border" my="2" />
          <Stack gap="1">
            {taps.map((t) => (
              <TapRow key={t.name}>
                <NavItem
                  active={category === t.name}
                  onClick={() => setCategory(t.name)}
                  pr="8"
                  title={t.name}
                >
                  <Package size={16} />
                  <Box
                    as="span"
                    overflow="hidden"
                    textOverflow="ellipsis"
                    whiteSpace="nowrap"
                  >
                    {t.name}
                  </Box>
                </NavItem>
                <RemoveButton
                  type="button"
                  data-remove
                  aria-label={`Remove ${t.name}`}
                  onClick={() => {
                    removeTap(t.name);
                    if (category === t.name) setCategory("all");
                  }}
                >
                  <X size={12} />
                </RemoveButton>
              </TapRow>
            ))}
          </Stack>
        </>
      )}

      <Box mt="2">
        <AddTap />
      </Box>
    </Box>
  );
}
