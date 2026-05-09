import { useState, useMemo, useEffect } from "react";
import { Dialog, Button, Tabs, IconButton, CloseButton } from "@/components/ui";
import { Box, Flex, Stack, styled } from "styled-system/jsx";
import { Copy, Download, Check, Link as LinkIcon } from "lucide-react";
import {
  brewInstallCommand,
  brewfile,
  curlOneLiner,
  shareUrl,
} from "@/lib/outputFormatters";
import { encodeCart } from "@/lib/shareEncoding";

const CodeBlock = styled("pre", {
  base: {
    fontFamily: "mono",
    fontSize: "sm",
    color: "fg.default",
    bg: "gray.2",
    p: "4",
    borderRadius: "l2",
    overflow: "auto",
    whiteSpace: "pre-wrap",
    wordBreak: "break-word",
    maxH: "60",
    border: "1px solid",
    borderColor: "border",
  },
});

const Caption = styled("p", {
  base: {
    fontSize: "sm",
    color: "fg.muted",
    lineHeight: "snug",
  },
});

interface OutputModalProps {
  open: boolean;
  onClose: () => void;
  tokens: string[];
}

export function OutputModal({ open, onClose, tokens }: OutputModalProps) {
  const installCmd = useMemo(() => brewInstallCommand(tokens), [tokens]);
  const brewfileText = useMemo(() => brewfile(tokens), [tokens]);
  const curl = useMemo(() => curlOneLiner(tokens), [tokens]);
  const share = useMemo(() => {
    const enc = encodeCart(tokens);
    return shareUrl(window.location.origin, enc);
  }, [tokens]);

  return (
    <Dialog.Root open={open} onOpenChange={(d) => !d.open && onClose()}>
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content maxW="2xl" w="full">
          <Stack gap="4" p="6">
            <Flex justify="space-between" align="flex-start">
              <Stack gap="0.5">
                <Dialog.Title>Install your apps</Dialog.Title>
                <Dialog.Description>
                  Pick a format. Paste in Terminal or save the file.
                </Dialog.Description>
              </Stack>
              <Dialog.CloseTrigger asChild>
                <CloseButton size="sm" aria-label="Close" />
              </Dialog.CloseTrigger>
            </Flex>

            <Tabs.Root defaultValue="install" lazyMount unmountOnExit>
              <Tabs.List>
                <Tabs.Trigger value="install">Install command</Tabs.Trigger>
                <Tabs.Trigger value="brewfile">Brewfile</Tabs.Trigger>
                <Tabs.Trigger value="curl">Curl one-liner</Tabs.Trigger>
                <Tabs.Trigger value="share">Share link</Tabs.Trigger>
                <Tabs.Indicator />
              </Tabs.List>

              <Tabs.Content value="install">
                <Stack gap="3" pt="3">
                  <Caption>
                    Paste this into Terminal. Requires Homebrew (
                    <a href="https://brew.sh" target="_blank" rel="noreferrer">
                      brew.sh
                    </a>
                    ) installed.
                  </Caption>
                  <BlockWithCopy text={installCmd} />
                </Stack>
              </Tabs.Content>

              <Tabs.Content value="brewfile">
                <Stack gap="3" pt="3">
                  <Caption>
                    Save as <code>Brewfile</code>, then run{" "}
                    <code>brew bundle --file=./Brewfile</code>.
                  </Caption>
                  <BlockWithCopy text={brewfileText} />
                  <Box>
                    <Button
                      variant="outline"
                      onClick={() => downloadText("Brewfile", brewfileText)}
                    >
                      <Download size={16} />
                      Download Brewfile
                    </Button>
                  </Box>
                </Stack>
              </Tabs.Content>

              <Tabs.Content value="curl">
                <Stack gap="3" pt="3">
                  <Caption>
                    Bootstraps Homebrew if missing, then installs the apps. One paste,
                    no setup.
                  </Caption>
                  <BlockWithCopy text={curl} />
                </Stack>
              </Tabs.Content>

              <Tabs.Content value="share">
                <Stack gap="3" pt="3">
                  <Caption>Send this link. Opens with your cart pre-filled.</Caption>
                  <BlockWithCopy text={share} icon={<LinkIcon size={16} />} />
                </Stack>
              </Tabs.Content>
            </Tabs.Root>
          </Stack>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
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
      <Box position="absolute" top="2" right="2">
        <IconButton
          size="sm"
          variant="solid"
          aria-label="Copy to clipboard"
          onClick={async () => {
            await navigator.clipboard.writeText(text);
            setCopied(true);
          }}
        >
          {copied ? <Check size={16} /> : icon ?? <Copy size={16} />}
        </IconButton>
      </Box>
    </Box>
  );
}

function downloadText(filename: string, text: string) {
  const blob = new Blob([text], { type: "text/plain" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
