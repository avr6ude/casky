import { Drawer, Button, Badge, CloseButton } from "@/components/ui";
import { Box, Flex, Stack, styled } from "styled-system/jsx";
import { ExternalLink, Plus, Check } from "lucide-react";
import { useCartStore } from "@/store/cart";
import type { Cask } from "@/lib/caskTypes";

const Section = styled("section", {
  base: {
    display: "flex",
    flexDirection: "column",
    gap: "1.5",
  },
});

const SectionLabel = styled("h4", {
  base: {
    fontSize: "xs",
    fontWeight: "semibold",
    color: "fg.muted",
    textTransform: "uppercase",
    letterSpacing: "wider",
  },
});

const Token = styled("code", {
  base: {
    fontFamily: "mono",
    fontSize: "sm",
    color: "violet.11",
    bg: "violet.3",
    px: "2",
    py: "0.5",
    borderRadius: "l1",
  },
});

interface CaskDetailDrawerProps {
  cask: Cask | null;
  onClose: () => void;
}

export function CaskDetailDrawer({ cask, onClose }: CaskDetailDrawerProps) {
  const has = useCartStore((s) => (cask ? s.tokens.includes(cask.token) : false));
  const toggle = useCartStore((s) => s.toggle);

  if (!cask) {
    return null;
  }

  const displayName = cask.name[0] ?? cask.token;

  return (
    <Drawer.Root open={!!cask} onOpenChange={(d) => !d.open && onClose()}>
      <Drawer.Backdrop />
      <Drawer.Positioner>
        <Drawer.Content>
          <Drawer.Header>
            <Stack gap="1">
              <Drawer.Title>{displayName}</Drawer.Title>
              <Flex gap="2" flexWrap="wrap">
                <Token>{cask.token}</Token>
                <Badge size="sm" variant="subtle">
                  v{cask.version || "—"}
                </Badge>
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
              </Flex>
            </Stack>
            <Drawer.CloseTrigger asChild>
              <CloseButton size="sm" aria-label="Close detail" />
            </Drawer.CloseTrigger>
          </Drawer.Header>

          <Drawer.Body>
            <Stack gap="5">
              {cask.desc && (
                <Section>
                  <SectionLabel>About</SectionLabel>
                  <Drawer.Description>{cask.desc}</Drawer.Description>
                </Section>
              )}

              {cask.deprecated && cask.deprecation_reason && (
                <Section>
                  <SectionLabel>Deprecation</SectionLabel>
                  <Box color="error">
                    {cask.deprecation_reason}
                    {cask.deprecation_date && ` (since ${cask.deprecation_date})`}
                  </Box>
                </Section>
              )}

              {cask.depends_on?.cask && cask.depends_on.cask.length > 0 && (
                <Section>
                  <SectionLabel>Depends on (casks)</SectionLabel>
                  <Flex gap="1.5" flexWrap="wrap">
                    {cask.depends_on.cask.map((d) => (
                      <Token key={d}>{d}</Token>
                    ))}
                  </Flex>
                </Section>
              )}

              {cask.depends_on?.formula && cask.depends_on.formula.length > 0 && (
                <Section>
                  <SectionLabel>Depends on (formulae)</SectionLabel>
                  <Flex gap="1.5" flexWrap="wrap">
                    {cask.depends_on.formula.map((d) => (
                      <Token key={d}>{d}</Token>
                    ))}
                  </Flex>
                </Section>
              )}

              {cask.caveats && (
                <Section>
                  <SectionLabel>Caveats</SectionLabel>
                  <Box
                    fontSize="sm"
                    color="fg.muted"
                    fontFamily="mono"
                    whiteSpace="pre-wrap"
                    bg="gray.2"
                    p="3"
                    borderRadius="l2"
                  >
                    {cask.caveats}
                  </Box>
                </Section>
              )}
            </Stack>
          </Drawer.Body>

          <Drawer.Footer>
            <Flex gap="2" justify="space-between" w="full">
              <Button variant="outline" asChild>
                <a href={cask.homepage} target="_blank" rel="noreferrer">
                  Homepage
                  <ExternalLink size={14} />
                </a>
              </Button>
              <Button variant="solid" onClick={() => toggle(cask.token)}>
                {has ? <Check size={16} /> : <Plus size={16} />}
                {has ? "In cart" : "Add to cart"}
              </Button>
            </Flex>
          </Drawer.Footer>
        </Drawer.Content>
      </Drawer.Positioner>
    </Drawer.Root>
  );
}
