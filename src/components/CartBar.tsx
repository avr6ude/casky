import { Badge, Button, IconButton, toaster } from "@/components/ui";
import { config } from "@/data/config";
import { faviconUrl } from "@/lib/format";
import {
    brewInstallCommand,
    brewfile,
    curlOneLiner,
    shareUrl,
} from "@/lib/outputFormatters";
import { encodeCart } from "@/lib/shareEncoding";
import { copyText } from "@/lib/clipboard";
import { useCartStore } from "@/store/cart";
import { useCatalogStore } from "@/store/catalog";
import { AnimatePresence, motion } from "framer-motion";
import {
    Check,
    ChevronDown,
    ChevronUp,
    Copy,
    Download,
    Link as LinkIcon,
    Package,
    Trash2,
    X,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { css } from "styled-system/css";
import { Box, Flex, Stack, styled } from "styled-system/jsx";

let tipNudgeShown = false;

const Wrapper = styled("div", {
  base: {
    position: "fixed",
    insetX: "0",
    bottom: "0",
    zIndex: "overlay",
  },
});

const backdropClass = css({
  position: "fixed",
  inset: "0",
  bottom: "16",
  bg: "black.a5",
  zIndex: "-1",
  cursor: "pointer",
});

const panelClass = css({
  bg: "gray.1",
  borderTop: "1px solid",
  borderColor: "border",
  overflow: "hidden",
  backdropFilter: "blur(12px)",
});

const PanelInner = styled("div", {
  base: {
    maxW: "5xl",
    mx: "auto",
    px: "4",
    py: "4",
    display: "grid",
    gridTemplateColumns: { base: "1fr", md: "1fr 1fr" },
    gap: "4",
    maxH: "60vh",
    overflowY: "auto",
  },
});

const Bar = styled("div", {
  base: {
    bg: "gray.1",
    backdropFilter: "blur(12px)",
  },
});

const BarInner = styled("div", {
  base: {
    display: "flex",
    alignItems: "center",
    gap: { base: "2", md: "3" },
    maxW: "7xl",
    mx: "auto",
    px: { base: "3", md: "4" },
    h: "16",
  },
});

const Preview = styled("code", {
  base: {
    fontFamily: "mono",
    fontSize: "sm",
    color: "fg.default",
    bg: "gray.2",
    h: "10",
    px: "3",
    display: "flex",
    alignItems: "center",
    borderRadius: "l2",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
    flex: "1",
    minW: "0",
    border: "1px solid",
    borderColor: "border",
  },
});

const SectionLabel = styled("h4", {
  base: {
    fontSize: "xs",
    fontWeight: "semibold",
    color: "fg.muted",
    textTransform: "uppercase",
    letterSpacing: "wider",
    mb: "2",
  },
});

const CodeBlock = styled("pre", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.default",
    bg: "gray.2",
    pl: "3",
    pr: "12",
    py: "3",
    borderRadius: "l2",
    overflow: "auto",
    whiteSpace: "pre-wrap",
    wordBreak: "break-word",
    maxH: "32",
    border: "1px solid",
    borderColor: "border",
    m: "0",
  },
});

function ItemFavicon({ src }: { src: string | null }) {
  const [failed, setFailed] = useState(false);
  return (
    <Box
      w="7"
      h="7"
      bg={src && !failed ? "white" : "gray.3"}
      color="fg.subtle"
      borderRadius="l1"
      p="1"
      display="inline-flex"
      alignItems="center"
      justifyContent="center"
      flexShrink="0"
    >
      {src && !failed ? (
        <img
          src={src}
          alt=""
          loading="lazy"
          onError={() => setFailed(true)}
          style={{ width: "100%", height: "100%", objectFit: "contain" }}
        />
      ) : (
        <Package size={12} />
      )}
    </Box>
  );
}

const ItemRow = styled("li", {
  base: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: "3",
    px: "3",
    py: "2",
    border: "1px solid",
    borderColor: "border",
    borderRadius: "l2",
    bg: "gray.2",
  },
});

const Token = styled("code", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.subtle",
  },
});

export function CartBar() {
  const tokens = useCartStore((s) => s.tokens);
  const remove = useCartStore((s) => s.remove);
  const clear = useCartStore((s) => s.clear);
  const casks = useCatalogStore((s) => s.casks);

  const [copied, setCopied] = useState(false);
  const [expanded, setExpanded] = useState(false);

  const command = useMemo(() => brewInstallCommand(tokens), [tokens]);
  const brewfileText = useMemo(() => brewfile(tokens), [tokens]);
  const curl = useMemo(() => curlOneLiner(tokens), [tokens]);
  const share = useMemo(() => {
    if (typeof window === "undefined") return "";
    return shareUrl(window.location.origin, encodeCart(tokens));
  }, [tokens]);

  const items = useMemo(() => {
    const map = new Map(casks.map((c) => [c.token, c]));
    return tokens.map((t) => {
      const c = map.get(t);
      return {
        token: t,
        name: c?.name[0] ?? t,
        icon: faviconUrl(c?.homepage ?? null),
      };
    });
  }, [tokens, casks]);

  useEffect(() => {
    if (!copied) return;
    const t = setTimeout(() => setCopied(false), 1500);
    return () => clearTimeout(t);
  }, [copied]);

  useEffect(() => {
    if (!expanded) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setExpanded(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [expanded]);

  useEffect(() => {
    if (tokens.length === 0) setExpanded(false);
  }, [tokens.length]);

  if (tokens.length === 0) return null;

  const handleCopy = async () => {
    const ok = await copyText(command);
    if (!ok) return;
    setCopied(true);
    if (!tipNudgeShown) {
      tipNudgeShown = true;
      toaster.create({
        title: "Copied — go install 🍺",
        description: "If casky helped you, drop a tip in the jar.",
        type: "success",
        duration: 8000,
        action: {
          label: "Tip jar",
          onClick: () =>
            window.open(config.donateUrl, "_blank", "noopener,noreferrer"),
        },
        closable: true,
      });
    }
  };

  return (
    <>
      <AnimatePresence>
        {expanded && (
          <motion.div
            key="backdrop"
            className={backdropClass}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            onClick={() => setExpanded(false)}
          />
        )}
      </AnimatePresence>

      <Wrapper>
        <AnimatePresence initial={false}>
          {expanded && (
            <motion.div
              key="panel"
              className={panelClass}
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.22, ease: [0.32, 0.72, 0, 1] }}
            >
              <PanelInner>
                <Box>
                  <SectionLabel>Items ({items.length})</SectionLabel>
                  <Box maxH="28rem" overflowY="auto" pr="1">
                    <Stack as="ul" gap="1.5" listStyle="none" p="0" m="0">
                      {items.map((it) => (
                        <ItemRow key={it.token}>
                          <ItemFavicon src={it.icon} />
                          <Box minW="0" flex="1">
                            <Box
                              fontSize="sm"
                              fontWeight="medium"
                              color="fg.default"
                              overflow="hidden"
                              textOverflow="ellipsis"
                              whiteSpace="nowrap"
                            >
                              {it.name}
                            </Box>
                            <Token>{it.token}</Token>
                          </Box>
                          <IconButton
                            size="sm"
                            variant="plain"
                            aria-label={`Remove ${it.name}`}
                            onClick={() => remove(it.token)}
                          >
                            <X size={14} />
                          </IconButton>
                        </ItemRow>
                      ))}
                    </Stack>
                  </Box>
                </Box>

                <Stack gap="4">
                  <Box>
                    <SectionLabel>Brewfile</SectionLabel>
                    <Stack gap="2">
                      <Box fontSize="xs" color="fg.muted" lineHeight="snug">
                        Download saves to <code>~/Downloads</code>. Then run{" "}
                        <code>cd ~/Downloads && brew bundle</code>.
                      </Box>
                      <BlockWithCopy text={brewfileText} />
                      <Box>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => downloadText("Brewfile", brewfileText)}
                        >
                          <Download size={14} />
                          Download
                        </Button>
                      </Box>
                    </Stack>
                  </Box>

                  <Box>
                    <SectionLabel>Curl</SectionLabel>
                    <BlockWithCopy text={curl} />
                  </Box>

                  <Box>
                    <SectionLabel>Share</SectionLabel>
                    <BlockWithCopy text={share} icon={<LinkIcon size={12} />} />
                  </Box>
                </Stack>
              </PanelInner>
            </motion.div>
          )}
        </AnimatePresence>

        <Bar>
          <BarInner>
            <Badge variant="solid" size="md" flexShrink="0">
              {tokens.length}
              <Box display={{ base: "none", sm: "inline" }} ml="1">
                {tokens.length === 1 ? "app" : "apps"}
              </Box>
            </Badge>

            <Box display={{ base: "none", sm: "flex" }} flex="1" minW="0">
              <Preview title={command}>{command}</Preview>
            </Box>

            <Flex align="center" gap="2" flexShrink="0">
              <Button onClick={handleCopy} variant="solid" size="md">
                {copied ? <Check size={16} /> : <Copy size={16} />}
                <Box display={{ base: "none", sm: "inline" }}>
                  {copied ? "Copied" : "Copy"}
                </Box>
              </Button>

              <Button
                onClick={() => setExpanded((v) => !v)}
                variant="outline"
                size="md"
                aria-expanded={expanded}
              >
                {expanded ? <ChevronDown size={16} /> : <ChevronUp size={16} />}
                <Box display={{ base: "none", lg: "inline" }}>
                  {expanded ? "Hide" : "Details"}
                </Box>
              </Button>

              <IconButton
                onClick={clear}
                variant="plain"
                size="md"
                aria-label="Clear cart"
              >
                <Trash2 size={16} />
              </IconButton>
            </Flex>
          </BarInner>
        </Bar>
      </Wrapper>
    </>
  );
}

function BlockWithCopy({
  text,
  icon,
}: {
  text: string;
  icon?: React.ReactNode;
}) {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const t = setTimeout(() => setCopied(false), 1500);
    return () => clearTimeout(t);
  }, [copied]);

  return (
    <Box position="relative">
      <CodeBlock>{text || "(empty)"}</CodeBlock>
      <Box position="absolute" top="1.5" right="1.5">
        <IconButton
          size="xs"
          variant="solid"
          aria-label="Copy to clipboard"
          onClick={async () => {
            const ok = await copyText(text);
            if (ok) setCopied(true);
          }}
        >
          {copied ? <Check size={12} /> : icon ?? <Copy size={12} />}
        </IconButton>
      </Box>
    </Box>
  );
}

function downloadText(filename: string, text: string) {
  const blob = new Blob([text], { type: "application/octet-stream" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
