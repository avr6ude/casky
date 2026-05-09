import { useMemo } from "react";
import { Plus, Check, Sparkles, Info } from "lucide-react";
import { Box, Flex, HStack, styled } from "styled-system/jsx";
import { IconButton, Tooltip } from "@/components/ui";
import { collections } from "@/data/collections";
import { useCatalogStore } from "@/store/catalog";
import { useCartStore } from "@/store/cart";
import { config } from "@/data/config";

const Strip = styled("div", {
  base: {
    display: "flex",
    alignItems: "stretch",
    gap: "3",
    overflowX: "auto",
    overflowY: "visible",
    pt: "2",
    pb: "3",
    px: "4",
    scrollSnapType: "x mandatory",
    scrollPaddingInlineStart: "4",
    scrollPaddingInlineEnd: "4",
    scrollbarWidth: "none",
    msOverflowStyle: "none",
    "&::-webkit-scrollbar": {
      display: "none",
    },
  } as never,
});

const Card = styled("div", {
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
    display: "flex",
    flexDirection: "column",
    transition:
      "border-color 120ms ease, background-color 120ms ease, box-shadow 120ms ease",
    _hover: {
      borderColor: "violet.7",
      boxShadow: "sm",
    },
    _focusVisible: {
      outline: "2px solid",
      outlineColor: "violet.9",
      outlineOffset: "2px",
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

const PrLink = styled("a", {
  base: {
    display: "inline-flex",
    alignItems: "center",
    color: "fg.subtle",
    _hover: { color: "violet.11" },
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

  const selectedKits = useMemo(
    () =>
      collections.filter((c) => {
        const v = validTokens(c.tokens);
        return v.length > 0 && v.every((t) => tokenSet.has(t));
      }),
    [validTokens, tokenSet],
  );

  if (casks.length === 0) return null;

  return (
    <Box mt="3">
      <Header>
        <HStack gap="2" color="fg.muted">
          <Sparkles size={14} />
          <SectionTitle>Curated kits</SectionTitle>
          <Tooltip
            content="Have a kit idea? Open a PR on GitHub."
            openDelay={150}
            closeDelay={0}
          >
            <PrLink
              href={config.repoUrl}
              target="_blank"
              rel="noreferrer"
              aria-label="Suggest a kit on GitHub"
            >
              <Info size={12} />
            </PrLink>
          </Tooltip>
        </HStack>
      </Header>
      <Strip>
        {collections.map((c) => {
          const valid = validTokens(c.tokens);
          const allAdded = selectedKits.includes(c);

          const handleClick = () => {
            if (!allAdded) {
              setAll([...new Set([...tokens, ...valid])]);
              return;
            }
            const keep = new Set(
              selectedKits.flatMap((o) =>
                o.slug === c.slug ? [] : validTokens(o.tokens),
              ),
            );
            setAll(tokens.filter((t) => !valid.includes(t) || keep.has(t)));
          };

          return (
            <Card
              key={c.slug}
              added={allAdded}
              onClick={handleClick}
              role="button"
              tabIndex={0}
              aria-pressed={allAdded}
              aria-label={`${allAdded ? "Remove" : "Add"} kit: ${c.title}`}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  handleClick();
                }
              }}
            >
              <Flex justify="space-between" align="flex-start" gap="3">
                <Box flex="1" minW="0">
                  <Title>{c.title}</Title>
                  <Desc>{c.desc}</Desc>
                </Box>
                <IconButton
                  size="sm"
                  variant={allAdded ? "solid" : "outline"}
                  tabIndex={-1}
                  aria-hidden="true"
                  asChild
                >
                  <span>
                    {allAdded ? <Check size={14} /> : <Plus size={14} />}
                  </span>
                </IconButton>
              </Flex>
              <Box mt="auto" pt="3">
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
