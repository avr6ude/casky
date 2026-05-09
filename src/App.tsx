import { useEffect, useState } from "react";
import { Box, Flex } from "styled-system/jsx";
import { AppHeader } from "@/components/AppHeader";
import { CategorySidebar } from "@/components/CategorySidebar";
import { CaskGrid } from "@/components/CaskGrid";
import { CartDrawer } from "@/components/CartDrawer";
import { Toaster } from "@/components/ui";
import { useCatalogStore } from "@/store/catalog";

export function App() {
  const load = useCatalogStore((s) => s.load);
  const [cartOpen, setCartOpen] = useState(false);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <Flex
      direction="column"
      h="100vh"
      w="100vw"
      bg="gray.2"
      overflow="hidden"
    >
      <AppHeader onCartOpen={() => setCartOpen(true)} />

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

        <Box flex="1" minW="0" minH="0" h="full" bg="gray.2">
          <CaskGrid />
        </Box>
      </Flex>

      <CartDrawer open={cartOpen} onClose={() => setCartOpen(false)} />
      <Toaster />
    </Flex>
  );
}

export default App;
