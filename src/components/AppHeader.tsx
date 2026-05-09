import { Search, BookOpen } from "lucide-react";
import { IconButton, Input } from "@/components/ui";
import { Box, Flex, styled } from "styled-system/jsx";
import { useFiltersStore } from "@/store/filters";

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

export function AppHeader() {
  const query = useFiltersStore((s) => s.query);
  const setQuery = useFiltersStore((s) => s.setQuery);

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

        <IconButton variant="outline" aria-label="About casky" asChild>
          <a href="/about">
            <BookOpen size={18} />
          </a>
        </IconButton>
      </Flex>
    </Box>
  );
}
