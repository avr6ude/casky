import { Button, IconButton, Input } from "@/components/ui";
import { config } from "@/data/config";
import { useColorMode } from "@/lib/colorMode";
import { useFiltersStore } from "@/store/filters";
import { Beer, Heart, Info, Moon, Search, Sun } from "lucide-react";
import { Box, Flex, HStack, styled } from "styled-system/jsx";

const Logo = styled("span", {
  base: {
    fontFamily: '"Pacifico", cursive',
    fontSize: "xl",
    color: "fg.default",
    lineHeight: "1",
    pb: "1",
  },
});

const BeerMark = styled("span", {
  base: {
    color: "violet.10",
    display: "inline-flex",
    alignItems: "center",
  },
});

const Brand = styled("a", {
  base: {
    display: "inline-flex",
    alignItems: "center",
    gap: "1.5",
    textDecoration: "none",
    color: "fg.default",
    _hover: { color: "violet.11" },
  },
});

interface AppHeaderProps {
  onAboutOpen: () => void;
}

export function AppHeader({ onAboutOpen }: AppHeaderProps) {
  const query = useFiltersStore((s) => s.query);
  const setQuery = useFiltersStore((s) => s.setQuery);
  const { mode, toggle } = useColorMode();

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
        direction={{ base: "column", md: "row" }}
        align={{ base: "stretch", md: "center" }}
        justify="space-between"
        gap={{ base: "2", md: "4" }}
        w="full"
        px={{ base: "3", md: "6" }}
        py="3"
      >
        <Flex align="center" justify="space-between" gap="2">
          <Brand href="/">
            <BeerMark>
              <Beer size={22} strokeWidth={2} />
            </BeerMark>
            <Logo>casky</Logo>
          </Brand>

          <HStack gap="2" display={{ base: "flex", md: "none" }}>
            <IconButton variant="outline" size="sm" aria-label="Tip jar" asChild>
              <a href={config.donateUrl} target="_blank" rel="noreferrer">
                <Heart size={14} />
              </a>
            </IconButton>
            <IconButton
              variant="outline"
              size="sm"
              aria-label={`Switch to ${mode === "dark" ? "light" : "dark"} mode`}
              onClick={toggle}
            >
              {mode === "dark" ? <Sun size={16} /> : <Moon size={16} />}
            </IconButton>
            <IconButton
              variant="outline"
              size="sm"
              aria-label="About casky"
              onClick={onAboutOpen}
            >
              <Info size={16} />
            </IconButton>
          </HStack>
        </Flex>

        <Box flex="1" maxW={{ base: "full", md: "lg" }} position="relative">
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
            placeholder="Search"
            pl="9"
            aria-label="Search casks"
          />
        </Box>

        <HStack gap="2" display={{ base: "none", md: "flex" }}>
          <Button variant="outline" size="sm" asChild>
            <a href={config.donateUrl} target="_blank" rel="noreferrer">
              <Heart size={14} />
              Tip jar
            </a>
          </Button>

          <IconButton
            variant="outline"
            size="sm"
            aria-label={`Switch to ${mode === "dark" ? "light" : "dark"} mode`}
            onClick={toggle}
          >
            {mode === "dark" ? <Sun size={16} /> : <Moon size={16} />}
          </IconButton>

          <IconButton
            variant="outline"
            size="sm"
            aria-label="About casky"
            onClick={onAboutOpen}
          >
            <Info size={16} />
          </IconButton>
        </HStack>
      </Flex>
    </Box>
  );
}
