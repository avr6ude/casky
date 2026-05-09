import { useMemo } from "react";
import { Plus, Check, Sparkles } from "lucide-react";
import { Box, Flex, HStack, styled } from "styled-system/jsx";
import { IconButton } from "@/components/ui";
import { collections } from "@/data/collections";
import { useCatalogStore } from "@/store/catalog";
import { useCartStore } from "@/store/cart";

const Strip = styled("div", {
  base: {
    display: "flex",
    gap: "3",
    overflowX: "auto",
    overflowY: "visible",
    pt: "2",
    pb: "3",
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
    transition:
      "border-color 120ms ease, background-color 120ms ease, box-shadow 120ms ease",
    _hover: {
      borderColor: "violet.7",
      boxShadow: "sm",
    },
  },
  variants: {
    added: {
      true: {
        borderColor: "violet.9",
        bg: "violet.2",
      },
    },
  },
});

const Title = styled("h3", {
  base: {
    fontSize: "md",
    fontWeight: "semibold",
    color: "fg.default",
    lineHeight: "tight",
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
    pb: "1",
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

  const tokenSet = useMemo(() => new Set(tokens), [tokens]);

  if (casks.length === 0) return null;

  return (
    <Box mt="3">
      <Header>
        <HStack gap="2" color="fg.muted">
          <Sparkles size={14} />
          <SectionTitle>Curated kits</SectionTitle>
        </HStack>
      </Header>
      <Strip>
        {collections.map((c) => {
          const valid = validTokens(c.tokens);
          const allAdded =
            valid.length > 0 && valid.every((t) => tokenSet.has(t));

          const handleClick = () => {
            if (allAdded) {
              setAll(tokens.filter((t) => !valid.includes(t)));
            } else {
              setAll(Array.from(new Set([...tokens, ...valid])));
            }
          };

          return (
            <Card key={c.slug} added={allAdded} onClick={handleClick}>
              <Flex justify="space-between" align="flex-start" gap="3">
                <Box flex="1" minW="0">
                  <Title>{c.title}</Title>
                  <Desc>{c.desc}</Desc>
                </Box>
                <IconButton
                  size="sm"
                  variant={allAdded ? "solid" : "outline"}
                  tabIndex={-1}
                  aria-label={allAdded ? "Remove kit" : "Add kit"}
                >
                  {allAdded ? <Check size={14} /> : <Plus size={14} />}
                </IconButton>
              </Flex>
              <Box mt="3">
                <Count>
                  {valid.length} {valid.length === 1 ? "app" : "apps"}
                </Count>
              </Box>
            </Card>
          );
        })}
      </Strip>
    </Box>
  );
}
