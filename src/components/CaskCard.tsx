import { useMemo } from "react";
import { Plus, Check, ExternalLink } from "lucide-react";
import { IconButton, Badge } from "@/components/ui";
import { Box, Flex, HStack, styled } from "styled-system/jsx";
import { useCartStore } from "@/store/cart";
import type { Cask } from "@/lib/caskTypes";

const Card = styled("article", {
  base: {
    display: "flex",
    flexDirection: "column",
    gap: "2",
    p: "4",
    bg: "gray.1",
    border: "1px solid",
    borderColor: "border",
    borderRadius: "l3",
    cursor: "pointer",
    minH: "44",
    transition: "border-color 120ms ease, transform 120ms ease, box-shadow 120ms ease",
    _hover: {
      borderColor: "violet.7",
      transform: "translateY(-1px)",
      boxShadow: "sm",
    },
  },
  variants: {
    selected: {
      true: { borderColor: "violet.9", bg: "violet.2" },
    },
  },
});

const Token = styled("code", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.muted",
    bg: "gray.3",
    px: "1.5",
    py: "0.5",
    borderRadius: "l1",
    display: "inline-block",
    maxW: "full",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
});

const Title = styled("h3", {
  base: {
    fontSize: "md",
    fontWeight: "semibold",
    color: "fg.default",
    lineHeight: "tight",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
});

const Desc = styled("p", {
  base: {
    fontSize: "sm",
    color: "fg.muted",
    lineHeight: "snug",
    overflow: "hidden",
    minH: "10",
    flex: "1",
    wordBreak: "break-word",
    overflowWrap: "anywhere",
  },
});

const Version = styled("span", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.subtle",
  },
});

interface CaskCardProps {
  cask: Cask;
  onOpen: (cask: Cask) => void;
}

export function CaskCard({ cask, onOpen }: CaskCardProps) {
  const has = useCartStore((s) => s.tokens.includes(cask.token));
  const toggle = useCartStore((s) => s.toggle);

  const displayName = useMemo(
    () => cask.name[0] ?? cask.token,
    [cask.name, cask.token],
  );

  return (
    <Card
      selected={has}
      onClick={() => onOpen(cask)}
      onKeyDown={(e) => {
        if (e.key === "Enter") onOpen(cask);
      }}
      tabIndex={0}
      aria-label={`${displayName} — open detail`}
    >
      <Flex justify="space-between" align="flex-start" gap="2">
        <Box minW="0" flex="1">
          <Title>{displayName}</Title>
          <Token title={cask.token}>{cask.token}</Token>
        </Box>
        <IconButton
          aria-label={has ? "Remove from cart" : "Add to cart"}
          variant={has ? "solid" : "outline"}
          size="sm"
          onClick={(e) => {
            e.stopPropagation();
            toggle(cask.token);
          }}
        >
          {has ? <Check size={16} /> : <Plus size={16} />}
        </IconButton>
      </Flex>

      <Desc>{cask.desc ?? "No description provided."}</Desc>

      <HStack justify="space-between" mt="auto" pt="1">
        <Version>v{cask.version || "—"}</Version>
        <HStack gap="1.5">
          {cask.deprecated && (
            <Badge size="sm" variant="outline">
              deprecated
            </Badge>
          )}
          {cask.auto_updates && (
            <Badge size="sm" variant="subtle">
              auto-updates
            </Badge>
          )}
          <a
            href={cask.homepage}
            target="_blank"
            rel="noreferrer"
            onClick={(e) => e.stopPropagation()}
            aria-label="Open homepage"
          >
            <ExternalLink size={14} />
          </a>
        </HStack>
      </HStack>
    </Card>
  );
}
