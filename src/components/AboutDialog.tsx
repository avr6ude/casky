import { Dialog, Button, CloseButton } from "@/components/ui";
import { Box, Flex, Stack, styled } from "styled-system/jsx";
import { Heart, ExternalLink, Code2 } from "lucide-react";
import { config } from "@/data/config";

const Body = styled("p", {
  base: {
    fontSize: "sm",
    color: "fg.muted",
    lineHeight: "snug",
  },
});

const Link = styled("a", {
  base: {
    color: "violet.11",
    textDecoration: "none",
    fontWeight: "medium",
    _hover: { color: "violet.10", textDecoration: "underline" },
  },
});

interface AboutDialogProps {
  open: boolean;
  onClose: () => void;
}

export function AboutDialog({ open, onClose }: AboutDialogProps) {
  const year = new Date().getFullYear();

  return (
    <Dialog.Root open={open} onOpenChange={(d) => !d.open && onClose()}>
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content maxW="lg" w="full">
          <Stack gap="4" p="6">
            <Flex justify="space-between" align="flex-start">
              <Dialog.Title>About casky</Dialog.Title>
              <Dialog.CloseTrigger asChild>
                <CloseButton size="sm" aria-label="Close" />
              </Dialog.CloseTrigger>
            </Flex>

            <Body>
              Browse all Homebrew Casks, drop ones you want into a cart, copy the
              install line, paste in Terminal. Need Homebrew first?{" "}
              <Link href="https://brew.sh" target="_blank" rel="noreferrer">
                brew.sh
              </Link>
              .
            </Body>

            <Body>
              Catalog comes live from{" "}
              <Link
                href="https://formulae.brew.sh"
                target="_blank"
                rel="noreferrer"
              >
                formulae.brew.sh
              </Link>{" "}
              on first visit, cached in your browser after.
            </Body>

            <Body>No tracking, no cookies.</Body>

            <Flex gap="2" wrap="wrap" pt="1">
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

            <Box
              fontSize="xs"
              color="fg.subtle"
              borderTop="1px solid"
              borderColor="border"
              pt="3"
            >
              © {year} avrdude
            </Box>
          </Stack>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
