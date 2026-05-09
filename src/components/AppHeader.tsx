import { Search, Info, Sun, Moon, Heart } from "lucide-react";
import { IconButton, Input, Button } from "@/components/ui";
import { Box, Flex, HStack, styled } from "styled-system/jsx";
import { useFiltersStore } from "@/store/filters";
import { useColorMode } from "@/lib/colorMode";
import { config } from "@/data/config";

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
          <Button variant="outline" size="sm" asChild>
            <a href={config.donateUrl} target="_blank" rel="noreferrer">
              <Heart size={14} />
              <Box display={{ base: "none", md: "inline" }}>Donate</Box>
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
