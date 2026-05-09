import { useEffect, useState } from "react";
import { Box, Flex } from "styled-system/jsx";
import { AppHeader } from "@/components/AppHeader";
import { CategorySidebar } from "@/components/CategorySidebar";
import { CaskGrid } from "@/components/CaskGrid";
import { CartBar } from "@/components/CartBar";
import { AboutDialog } from "@/components/AboutDialog";
import { ListsDialog } from "@/components/ListsDialog";
import { Toaster } from "@/components/ui";
import { useCatalogStore } from "@/store/catalog";
import { useCartStore } from "@/store/cart";
import { readSharedTokensFromLocation, clearShareFromUrl } from "@/lib/sharePath";

export function App() {
  const load = useCatalogStore((s) => s.load);
  const cartCount = useCartStore((s) => s.tokens.length);
  const setAll = useCartStore((s) => s.setAll);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [listsOpen, setListsOpen] = useState(false);

  useEffect(() => {
    load();
    const shared = readSharedTokensFromLocation();
    if (shared) {
      setAll(shared);
      clearShareFromUrl();
    }
  }, [load, setAll]);

  return (
    <Flex
      direction="column"
      h="100vh"
      w="100vw"
      bg="gray.2"
      overflow="hidden"
    >
      <AppHeader
        onAboutOpen={() => setAboutOpen(true)}
        onListsOpen={() => setListsOpen(true)}
      />

      <Flex flex="1" minH="0" w="full">
        <Box
          w="240px"
          flexShrink="0"
          display={{ base: "none", lg: "block" }}
          overflowY="auto"
          bg="gray.1"
        >
          <CategorySidebar />
        </Box>

        <Box
          flex="1"
          minW="0"
          minH="0"
          h="full"
          bg="gray.2"
          pb={cartCount > 0 ? "16" : "0"}
        >
          <CaskGrid />
        </Box>
      </Flex>

      <CartBar />
      <AboutDialog open={aboutOpen} onClose={() => setAboutOpen(false)} />
      <ListsDialog open={listsOpen} onClose={() => setListsOpen(false)} />
      <Toaster />
    </Flex>
  );
}

export default App;
