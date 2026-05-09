import { useMemo } from "react";
import { Plus, Sparkles } from "lucide-react";
import { Box, Flex, HStack, styled } from "styled-system/jsx";
import { Button } from "@/components/ui";
import { collections } from "@/data/collections";
import { useCatalogStore } from "@/store/catalog";
import { useCartStore } from "@/store/cart";

const Strip = styled("div", {
  base: {
    display: "flex",
    gap: "3",
    overflowX: "auto",
    overflowY: "hidden",
    pb: "2",
    px: "4",
    scrollSnapType: "x mandatory",
    scrollbarWidth: "thin",
  },
});

const Card = styled("button", {
  base: {
    flexShrink: "0",
    w: "64",
    p: "4",
    bg: "gray.1",
    border: "1px solid",
    borderColor: "border",
    borderRadius: "l3",
    textAlign: "left",
    cursor: "pointer",
    scrollSnapAlign: "start",
    transition: "border-color 120ms ease, transform 120ms ease, box-shadow 120ms ease",
    _hover: {
      borderColor: "violet.7",
      transform: "translateY(-1px)",
      boxShadow: "sm",
    },
  },
});

const Emoji = styled("span", {
  base: {
    fontSize: "2xl",
    lineHeight: "1",
  },
});

const Title = styled("h3", {
  base: {
    fontSize: "md",
    fontWeight: "semibold",
    color: "fg.default",
    mt: "2",
  },
});

const Desc = styled("p", {
  base: {
    fontSize: "xs",
    color: "fg.muted",
    mt: "1",
    overflow: "hidden",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical",
  } as never,
});

const Count = styled("span", {
  base: {
    fontSize: "xs",
    color: "fg.subtle",
    fontFamily: "mono",
  },
});

const Header = styled("div", {
  base: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    px: "4",
    pb: "2",
  },
});

const SectionTitle = styled("h2", {
  base: {
    fontSize: "sm",
    fontWeight: "semibold",
    color: "fg.default",
    textTransform: "uppercase",
    letterSpacing: "wider",
  },
});

export function Collections() {
  const casks = useCatalogStore((s) => s.casks);
  const setAll = useCartStore((s) => s.setAll);
  const tokens = useCartStore((s) => s.tokens);

  const validTokens = useMemo(() => {
    const set = new Set(casks.map((c) => c.token));
    return (cs: string[]) => cs.filter((t) => set.has(t));
  }, [casks]);

  if (casks.length === 0) return null;

  const handleAddAll = (cs: string[]) => {
    const valid = validTokens(cs);
    const merged = Array.from(new Set([...tokens, ...valid]));
    setAll(merged);
  };

  return (
    <Box mt="3">
      <Header>
        <HStack gap="2" color="fg.muted">
          <Sparkles size={14} />
          <SectionTitle>Curated kits</SectionTitle>
        </HStack>
        <Box fontSize="xs" color="fg.subtle">
          one-click to add all
        </Box>
      </Header>
      <Strip>
        {collections.map((c) => {
          const valid = validTokens(c.tokens);
          return (
            <Card key={c.slug} onClick={() => handleAddAll(c.tokens)}>
              <Flex justify="space-between" align="flex-start">
                <Emoji>{c.emoji}</Emoji>
                <Button size="xs" variant="solid" tabIndex={-1}>
                  <Plus size={12} />
                  Add
                </Button>
              </Flex>
              <Title>{c.title}</Title>
              <Desc>{c.desc}</Desc>
              <Count>
                {valid.length} {valid.length === 1 ? "app" : "apps"}
              </Count>
            </Card>
          );
        })}
      </Strip>
    </Box>
  );
}
