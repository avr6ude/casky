import { Dialog, Button, CloseButton } from "@/components/ui";
import { Box, Flex, Stack, styled } from "styled-system/jsx";
import { Heart, Code2, ExternalLink } from "lucide-react";
import { config } from "@/data/config";

const Section = styled("section", {
  base: {
    display: "flex",
    flexDirection: "column",
    gap: "2",
  },
});

const SectionTitle = styled("h3", {
  base: {
    fontSize: "sm",
    fontWeight: "semibold",
    color: "fg.default",
    textTransform: "uppercase",
    letterSpacing: "wider",
  },
});

const Body = styled("p", {
  base: {
    fontSize: "sm",
    color: "fg.muted",
    lineHeight: "snug",
  },
});

const Code = styled("code", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    bg: "gray.3",
    px: "1.5",
    py: "0.5",
    borderRadius: "l1",
    color: "fg.default",
  },
});

interface AboutDialogProps {
  open: boolean;
  onClose: () => void;
}

export function AboutDialog({ open, onClose }: AboutDialogProps) {
  return (
    <Dialog.Root open={open} onOpenChange={(d) => !d.open && onClose()}>
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content maxW="2xl" w="full">
          <Stack gap="5" p="6">
            <Flex justify="space-between" align="flex-start">
              <Stack gap="0.5">
                <Dialog.Title>About casky</Dialog.Title>
                <Dialog.Description>
                  Pick Mac apps, get a one-line install command. Free forever.
                </Dialog.Description>
              </Stack>
              <Dialog.CloseTrigger asChild>
                <CloseButton size="sm" aria-label="Close" />
              </Dialog.CloseTrigger>
            </Flex>

            <Section>
              <SectionTitle>What is this?</SectionTitle>
              <Body>
                Casky is a modern revival of the old "Ninite for Mac" idea. Browse the
                full Homebrew Cask catalog (~7000+ apps), build a cart, get a one-line
                install command. No accounts. No tracking. Catalog cached locally.
              </Body>
            </Section>

            <Section>
              <SectionTitle>How to use it</SectionTitle>
              <Body>
                1. Search or browse. Tap <Code>+</Code> on any app to add to cart.
                <br />
                2. Bottom bar shows the install command — hit <Code>Copy</Code>.
                <br />
                3. Paste in Terminal. Need Homebrew first? See <Code>brew.sh</Code>.
                <br />
                4. Want a Brewfile, curl one-liner, or shareable link? Open the Details
                panel from the bar.
              </Body>
            </Section>

            <Section>
              <SectionTitle>FAQ</SectionTitle>
              <Stack gap="3">
                <Body>
                  <strong>Where does the data come from?</strong>
                  <br />
                  Live from{" "}
                  <a
                    href="https://formulae.brew.sh"
                    target="_blank"
                    rel="noreferrer"
                  >
                    formulae.brew.sh
                  </a>{" "}
                  on your first visit, then cached in IndexedDB and refreshed in the
                  background after 24 h.
                </Body>
                <Body>
                  <strong>Are categories official?</strong>
                  <br />
                  No — Homebrew has no category field. Casky derives them via keyword
                  scoring on tokens, names, and descriptions. Best-effort.
                </Body>
                <Body>
                  <strong>Do you collect anything?</strong>
                  <br />
                  No. Cart and preferences live in your browser only.
                </Body>
              </Stack>
            </Section>

            <Section>
              <SectionTitle>Support</SectionTitle>
              <Body>
                If casky saves you time, throw a coffee. Keeps the lights on, no
                strings.
              </Body>
              <Flex gap="2" wrap="wrap">
                <Button variant="solid" asChild>
                  <a href={config.donateUrl} target="_blank" rel="noreferrer">
                    <Heart size={16} />
                    Donate
                    <ExternalLink size={12} />
                  </a>
                </Button>
                <Button variant="outline" asChild>
                  <a
                    href={config.githubSponsorsUrl}
                    target="_blank"
                    rel="noreferrer"
                  >
                    GitHub Sponsors
                    <ExternalLink size={12} />
                  </a>
                </Button>
                <Button variant="outline" asChild>
                  <a href={config.repoUrl} target="_blank" rel="noreferrer">
                    <Code2 size={16} />
                    Source
                  </a>
                </Button>
              </Flex>
            </Section>

            <Box
              fontSize="xs"
              color="fg.subtle"
              borderTop="1px solid"
              borderColor="border"
              pt="3"
            >
              Built with React + Park UI + Panda CSS. Catalog data © Homebrew project,
              cask data licensed BSD-2-Clause.
            </Box>
          </Stack>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
