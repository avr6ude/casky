import { Skeleton } from "@/components/ui";
import { useFilteredCasks } from "@/lib/selectCasks";
import { useCatalogStore } from "@/store/catalog";
import type { ComponentPropsWithRef } from "react";
import { forwardRef, useMemo } from "react";
import { VirtuosoGrid } from "react-virtuoso";
import { Box, Stack, styled } from "styled-system/jsx";
import { CaskCard } from "./CaskCard";
import { Collections } from "./Collections";

const GridListInner = styled("div", {
  base: {
    display: "grid",
    gridTemplateColumns: {
      base: "repeat(1, minmax(0, 1fr))",
      sm: "repeat(2, minmax(0, 1fr))",
      lg: "repeat(3, minmax(0, 1fr))",
      xl: "repeat(4, minmax(0, 1fr))",
    },
    gap: "3",
    px: "4",
  },
});

const GridList = forwardRef<HTMLDivElement, ComponentPropsWithRef<"div">>(
  function GridList(props, ref) {
    return <GridListInner ref={ref} {...props} />;
  },
);

function TopSlot() {
  return (
    <div style={{ paddingTop: 16, paddingBottom: 16 }}>
      <Collections />
    </div>
  );
}

function BottomSpacer() {
  return <div style={{ height: 24 }} />;
}

const Empty = styled("div", {
  base: {
    p: "12",
    textAlign: "center",
    color: "fg.muted",
  },
});

export function CaskGrid() {
  const status = useCatalogStore((s) => s.status);
  const filtered = useFilteredCasks();

  const skeletons = useMemo(() => Array.from({ length: 12 }, (_, i) => i), []);

  if (status === "loading" || status === "idle") {
    return (
      <GridList>
        {skeletons.map((i) => (
          <Skeleton key={i} height="36" borderRadius="l3" />
        ))}
      </GridList>
    );
  }

  if (status === "error") {
    return (
      <Empty>
        <p>Couldn't load the cask catalog. Refresh to retry.</p>
      </Empty>
    );
  }

  if (filtered.length === 0) {
    return (
      <Empty>
        <Stack gap="2" align="center">
          <p>No matches.</p>
          <Box fontSize="sm" color="fg.subtle">
            Try a different search or clear filters.
          </Box>
        </Stack>
      </Empty>
    );
  }

  return (
    <Box h="full" minH="0">
      <VirtuosoGrid
        style={{ height: "100%" }}
        data={filtered}
        components={{
          List: GridList,
          Header: TopSlot,
          Footer: BottomSpacer,
        }}
        itemContent={(_, cask) => <CaskCard cask={cask} />}
        overscan={400}
      />
    </Box>
  );
}
