import { useMemo, useState } from "react";
import { Drawer, Button, IconButton, CloseButton } from "@/components/ui";
import { Box, Flex, Stack, styled } from "styled-system/jsx";
import { Trash2, X, Sparkles } from "lucide-react";
import { useCartStore } from "@/store/cart";
import { useCatalogStore } from "@/store/catalog";
import { OutputModal } from "./OutputModal";

const Row = styled("li", {
  base: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: "3",
    p: "3",
    border: "1px solid",
    borderColor: "border",
    borderRadius: "l2",
    bg: "gray.1",
  },
});

const Empty = styled("div", {
  base: {
    p: "12",
    textAlign: "center",
    color: "fg.muted",
  },
});

const Token = styled("code", {
  base: {
    fontFamily: "mono",
    fontSize: "xs",
    color: "fg.subtle",
  },
});

interface CartDrawerProps {
  open: boolean;
  onClose: () => void;
}

export function CartDrawer({ open, onClose }: CartDrawerProps) {
  const tokens = useCartStore((s) => s.tokens);
  const remove = useCartStore((s) => s.remove);
  const clear = useCartStore((s) => s.clear);
  const casks = useCatalogStore((s) => s.casks);
  const [outputOpen, setOutputOpen] = useState(false);

  const items = useMemo(() => {
    const map = new Map(casks.map((c) => [c.token, c]));
    return tokens.map((t) => ({ token: t, name: map.get(t)?.name[0] ?? t }));
  }, [tokens, casks]);

  return (
    <>
      <Drawer.Root open={open} onOpenChange={(d) => !d.open && onClose()}>
        <Drawer.Backdrop />
        <Drawer.Positioner>
          <Drawer.Content>
            <Drawer.Header>
              <Stack gap="0.5">
                <Drawer.Title>Your cart</Drawer.Title>
                <Drawer.Description>
                  {tokens.length === 0
                    ? "No apps yet — pick some."
                    : `${tokens.length} app${tokens.length === 1 ? "" : "s"} ready to brew.`}
                </Drawer.Description>
              </Stack>
              <Drawer.CloseTrigger asChild>
                <CloseButton size="sm" aria-label="Close cart" />
              </Drawer.CloseTrigger>
            </Drawer.Header>

            <Drawer.Body>
              {items.length === 0 ? (
                <Empty>
                  <Stack gap="1" align="center">
                    <Box fontSize="3xl">🍺</Box>
                    <Box>Your cart is fresh.</Box>
                    <Box fontSize="sm" color="fg.subtle">
                      Tap + on any app to add it.
                    </Box>
                  </Stack>
                </Empty>
              ) : (
                <Stack as="ul" gap="2" listStyle="none" p="0" m="0">
                  {items.map((it) => (
                    <Row key={it.token}>
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
                        <X size={16} />
                      </IconButton>
                    </Row>
                  ))}
                </Stack>
              )}
            </Drawer.Body>

            <Drawer.Footer>
              <Flex gap="2" w="full">
                <Button
                  variant="plain"
                  disabled={tokens.length === 0}
                  onClick={clear}
                >
                  <Trash2 size={16} />
                  Clear
                </Button>
                <Box flex="1" />
                <Button
                  variant="solid"
                  disabled={tokens.length === 0}
                  onClick={() => setOutputOpen(true)}
                >
                  <Sparkles size={16} />
                  Generate command
                </Button>
              </Flex>
            </Drawer.Footer>
          </Drawer.Content>
        </Drawer.Positioner>
      </Drawer.Root>

      <OutputModal
        open={outputOpen}
        onClose={() => setOutputOpen(false)}
        tokens={tokens}
      />
    </>
  );
}
