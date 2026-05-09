import { Dialog, Button, IconButton, Input, CloseButton, toaster } from "@/components/ui";
import { Box, Flex, Stack, styled } from "styled-system/jsx";
import { Bookmark, Plus, Trash2, Upload } from "lucide-react";
import { useState } from "react";
import { useListsStore } from "@/store/lists";
import { useCartStore } from "@/store/cart";

const ListRow = styled("li", {
  base: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: "3",
    px: "3",
    py: "2.5",
    border: "1px solid",
    borderColor: "border",
    borderRadius: "l2",
    bg: "gray.2",
  },
});

const ListName = styled("div", {
  base: {
    fontSize: "sm",
    fontWeight: "medium",
    color: "fg.default",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
});

const ListMeta = styled("div", {
  base: {
    fontSize: "xs",
    color: "fg.subtle",
    fontFamily: "mono",
  },
});

const Empty = styled("div", {
  base: {
    fontSize: "sm",
    color: "fg.muted",
    textAlign: "center",
    py: "6",
    border: "1px dashed",
    borderColor: "border",
    borderRadius: "l2",
  },
});

interface ListsDialogProps {
  open: boolean;
  onClose: () => void;
}

export function ListsDialog({ open, onClose }: ListsDialogProps) {
  const lists = useListsStore((s) => s.lists);
  const save = useListsStore((s) => s.save);
  const removeList = useListsStore((s) => s.remove);

  const tokens = useCartStore((s) => s.tokens);
  const setAll = useCartStore((s) => s.setAll);

  const [name, setName] = useState("");

  const handleSave = () => {
    if (tokens.length === 0) return;
    const list = save(name, tokens);
    setName("");
    toaster.create({
      title: `Saved "${list.name}"`,
      description: `${list.tokens.length} ${list.tokens.length === 1 ? "app" : "apps"}`,
      type: "success",
      duration: 3000,
      closable: true,
    });
  };

  const handleLoad = (id: string) => {
    const list = lists.find((l) => l.id === id);
    if (!list) return;
    setAll(list.tokens);
    onClose();
    toaster.create({
      title: `Loaded "${list.name}"`,
      type: "info",
      duration: 2500,
      closable: true,
    });
  };

  const handleMerge = (id: string) => {
    const list = lists.find((l) => l.id === id);
    if (!list) return;
    setAll([...new Set([...tokens, ...list.tokens])]);
    onClose();
    toaster.create({
      title: `Added "${list.name}"`,
      type: "info",
      duration: 2500,
      closable: true,
    });
  };

  return (
    <Dialog.Root open={open} onOpenChange={(d) => !d.open && onClose()}>
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content maxW="lg" w="full">
          <Stack gap="4" p="6">
            <Flex justify="space-between" align="flex-start">
              <Dialog.Title>Saved lists</Dialog.Title>
              <Dialog.CloseTrigger asChild>
                <CloseButton size="sm" aria-label="Close" />
              </Dialog.CloseTrigger>
            </Flex>

            <Stack gap="2">
              <Box fontSize="xs" color="fg.muted" textTransform="uppercase" letterSpacing="wider" fontWeight="semibold">
                Save current cart
              </Box>
              <Flex gap="2">
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder={tokens.length === 0 ? "Cart is empty" : "List name (e.g. New Mac setup)"}
                  disabled={tokens.length === 0}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSave();
                  }}
                />
                <Button
                  onClick={handleSave}
                  disabled={tokens.length === 0}
                  variant="solid"
                >
                  <Plus size={14} />
                  Save
                </Button>
              </Flex>
              {tokens.length > 0 && (
                <Box fontSize="xs" color="fg.subtle">
                  {tokens.length} {tokens.length === 1 ? "app" : "apps"} in cart
                </Box>
              )}
            </Stack>

            <Stack gap="2">
              <Box fontSize="xs" color="fg.muted" textTransform="uppercase" letterSpacing="wider" fontWeight="semibold">
                Your lists ({lists.length})
              </Box>
              {lists.length === 0 ? (
                <Empty>No saved lists yet.</Empty>
              ) : (
                <Box maxH="20rem" overflowY="auto" pr="1">
                  <Stack as="ul" gap="2" listStyle="none" p="0" m="0">
                    {lists.map((l) => (
                      <ListRow key={l.id}>
                        <Box minW="0" flex="1">
                          <ListName>{l.name}</ListName>
                          <ListMeta>
                            {l.tokens.length} {l.tokens.length === 1 ? "app" : "apps"}
                          </ListMeta>
                        </Box>
                        <Flex gap="1" flexShrink="0">
                          <IconButton
                            size="sm"
                            variant="outline"
                            aria-label={`Add "${l.name}" to cart`}
                            title="Add to cart"
                            onClick={() => handleMerge(l.id)}
                          >
                            <Plus size={14} />
                          </IconButton>
                          <IconButton
                            size="sm"
                            variant="solid"
                            aria-label={`Load "${l.name}" (replaces cart)`}
                            title="Load (replace cart)"
                            onClick={() => handleLoad(l.id)}
                          >
                            <Upload size={14} />
                          </IconButton>
                          <IconButton
                            size="sm"
                            variant="plain"
                            aria-label={`Delete "${l.name}"`}
                            title="Delete"
                            onClick={() => removeList(l.id)}
                          >
                            <Trash2 size={14} />
                          </IconButton>
                        </Flex>
                      </ListRow>
                    ))}
                  </Stack>
                </Box>
              )}
            </Stack>

            <Box
              fontSize="xs"
              color="fg.subtle"
              borderTop="1px solid"
              borderColor="border"
              pt="3"
              display="flex"
              alignItems="center"
              gap="1.5"
            >
              <Bookmark size={12} />
              Lists are stored in your browser only.
            </Box>
          </Stack>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
