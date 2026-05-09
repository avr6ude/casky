import { Search, ShoppingBag, BookOpen } from "lucide-react";
import { Button, IconButton, Input } from "@/components/ui";
import { Box, Flex, HStack, styled } from "styled-system/jsx";
import { useFiltersStore } from "@/store/filters";
import { useCartStore } from "@/store/cart";

const Logo = styled("span", {
  base: {
    fontFamily: "mono",
    fontWeight: "bold",
    fontSize: "lg",
    letterSpacing: "tight",
    color: "fg.default",
  },
});

const Brand = styled("a", {
  base: {
    display: "inline-flex",
    alignItems: "center",
    gap: "2",
    textDecoration: "none",
    color: "fg.default",
    _hover: { color: "violet.11" },
  },
});

const CartBadge = styled("span", {
  base: {
    position: "absolute",
    top: "-1",
    right: "-1",
    minW: "5",
    h: "5",
    px: "1",
    bg: "violet.9",
    color: "white",
    borderRadius: "full",
    fontSize: "xs",
    fontWeight: "bold",
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    lineHeight: "1",
  },
});

interface AppHeaderProps {
  onCartOpen: () => void;
}

export function AppHeader({ onCartOpen }: AppHeaderProps) {
  const query = useFiltersStore((s) => s.query);
  const setQuery = useFiltersStore((s) => s.setQuery);
  const cartCount = useCartStore((s) => s.tokens.length);

  return (
    <Box
      as="header"
      borderBottom="1px solid"
      borderColor="border"
      bg="gray.1"
      position="sticky"
      top="0"
      zIndex="docked"
      backdropFilter="blur(8px)"
    >
      <Flex
        align="center"
        justify="space-between"
        gap="4"
        w="full"
        px={{ base: "4", md: "6" }}
        py="3"
      >
        <Brand href="/">
          <Logo>🍺 casky</Logo>
        </Brand>

        <Box flex="1" maxW="lg" position="relative">
          <Box
            position="absolute"
            left="3"
            top="50%"
            transform="translateY(-50%)"
            color="fg.muted"
            pointerEvents="none"
          >
            <Search size={16} />
          </Box>
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search 7000+ Mac apps…"
            pl="9"
            aria-label="Search casks"
          />
        </Box>

        <HStack gap="2">
          <IconButton variant="outline" aria-label="About casky" asChild>
            <a href="/about">
              <BookOpen size={18} />
            </a>
          </IconButton>

          <Box position="relative">
            <Button onClick={onCartOpen} variant="solid" size="sm">
              <ShoppingBag size={16} />
              Cart
            </Button>
            {cartCount > 0 && <CartBadge>{cartCount}</CartBadge>}
          </Box>
        </HStack>
      </Flex>
    </Box>
  );
}
