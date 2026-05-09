import { useEffect } from "react";
import { Box, Flex } from "styled-system/jsx";
import { AppHeader } from "@/components/AppHeader";
import { CategorySidebar } from "@/components/CategorySidebar";
import { CaskGrid } from "@/components/CaskGrid";
import { CartBar } from "@/components/CartBar";
import { Toaster } from "@/components/ui";
import { useCatalogStore } from "@/store/catalog";
import { useCartStore } from "@/store/cart";

export function App() {
  const load = useCatalogStore((s) => s.load);
  const cartCount = useCartStore((s) => s.tokens.length);

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
      <AppHeader />

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
          pb={cartCount > 0 ? "24" : "0"}
        >
          <CaskGrid />
        </Box>
      </Flex>

      <CartBar />
      <Toaster />
    </Flex>
  );
}

export default App;
