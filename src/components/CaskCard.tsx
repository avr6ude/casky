import { useMemo, useState } from "react";
import { Plus, Check, ExternalLink, Download, Package } from "lucide-react";
import { IconButton, Badge, Tooltip } from "@/components/ui";
import { Box, Flex, styled } from "styled-system/jsx";
import { useCartStore } from "@/store/cart";
import type { Cask } from "@/lib/caskTypes";
import { formatVersion, formatCount, faviconUrl, safeExternalUrl } from "@/lib/format";

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
    minH: "44",
    transition: "border-color 80ms linear",
    willChange: "border-color",
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

const Meta = styled("span", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.subtle",
    display: "inline-flex",
    alignItems: "center",
    gap: "1",
    flexShrink: "0",
  },
});

const VersionPill = styled("span", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.subtle",
    display: "inline-block",
    w: "16",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
    flexShrink: "0",
  },
});

const HomepageLink = styled("a", {
  base: {
    color: "fg.subtle",
    display: "inline-flex",
    alignItems: "center",
    _hover: { color: "violet.11" },
  },
});

const FaviconFrame = styled("div", {
  base: {
    w: "12",
    h: "12",
    borderRadius: "l2",
    bg: "white",
    p: "1.5",
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: "0",
  },
  variants: {
    fallback: {
      true: {
        bg: "gray.3",
        color: "fg.subtle",
      },
    },
  },
});

const FaviconImg = styled("img", {
  base: {
    w: "full",
    h: "full",
    objectFit: "contain",
    display: "block",
  },
});

const CATEGORY_LABEL: Record<string, string> = {
  ai: "AI",
  browsers: "Browser",
  communication: "Comm",
  developer: "Dev",
  design: "Design",
  audio: "Audio",
  video: "Video",
  games: "Game",
  productivity: "Productivity",
  privacy: "Privacy",
  writing: "Writing",
  finance: "Finance",
  system: "System",
  network: "Network",
  files: "Files",
  education: "Edu",
  utilities: "Utility",
  other: "Other",
};

interface CaskCardProps {
  cask: Cask;
}

export function CaskCard({ cask }: CaskCardProps) {
  const has = useCartStore((s) => s.tokens.includes(cask.token));
  const toggle = useCartStore((s) => s.toggle);
  const [iconFailed, setIconFailed] = useState(false);

  const displayName = useMemo(
    () => cask.name[0] ?? cask.token,
    [cask.name, cask.token],
  );

  const icon = useMemo(() => faviconUrl(cask.homepage), [cask.homepage]);
  const safeHomepage = useMemo(() => safeExternalUrl(cask.homepage), [cask.homepage]);
  const versionLabel = formatVersion(cask.version);
  const countLabel = formatCount(cask.install_count);

  return (
    <Card selected={has} aria-label={displayName}>
      <Flex justify="space-between" align="center" gap="2">
        <Flex minW="0" flex="1" gap="2.5" align="center">
          {icon && !iconFailed ? (
            <FaviconFrame>
              <FaviconImg
                src={icon}
                alt=""
                loading="lazy"
                onError={() => setIconFailed(true)}
              />
            </FaviconFrame>
          ) : (
            <FaviconFrame fallback>
              <Package size={20} />
            </FaviconFrame>
          )}
          <Box minW="0" flex="1">
            <Title>{displayName}</Title>
            <Token title={cask.token}>{cask.token}</Token>
          </Box>
        </Flex>
        <IconButton
          aria-label={has ? "Remove from cart" : "Add to cart"}
          variant={has ? "solid" : "outline"}
          size="sm"
          onClick={() => toggle(cask.token)}
        >
          {has ? <Check size={16} /> : <Plus size={16} />}
        </IconButton>
      </Flex>

      <Desc>{cask.desc ?? "No description provided."}</Desc>

      <Flex justify="space-between" align="center" mt="auto" pt="1" gap="2">
        <Flex align="center" gap="2.5" minW="0" overflow="hidden">
          {cask.version ? (
            <Tooltip content={cask.version} openDelay={200} closeDelay={0}>
              <VersionPill>{versionLabel}</VersionPill>
            </Tooltip>
          ) : (
            <VersionPill>—</VersionPill>
          )}
          <Meta title={`${cask.install_count ?? 0} installs in last 365d`}>
            <Download size={12} />
            {countLabel}
          </Meta>
          {cask.category && cask.category !== "other" && (
            <Badge size="sm" variant="subtle" flexShrink="0">
              {CATEGORY_LABEL[cask.category]}
            </Badge>
          )}
        </Flex>
        <Flex align="center" gap="1.5" flexShrink="0">
          {cask.deprecated && (
            <Badge size="sm" variant="outline">
              deprecated
            </Badge>
          )}
          {safeHomepage && (
            <HomepageLink
              href={safeHomepage}
              target="_blank"
              rel="noreferrer"
              aria-label="Open homepage"
            >
              <ExternalLink size={14} />
            </HomepageLink>
          )}
        </Flex>
      </Flex>
    </Card>
  );
}
