// product-tags.queries.ts — react-slice worked example: "Product Tags"
//
// Query-key factory + useQuery + mutation hooks that each own their own
// cache invalidation. `{ signal }` is destructured from TanStack Query's
// queryFn context and threaded into the api call, so navigating away from a
// product's tag panel actually cancels the in-flight request instead of
// letting it resolve into a query that's no longer mounted.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { productTagsApi } from './product-tags.api';
import { ProductTagTransformers } from './product-tags.transformers';

export const PRODUCT_TAG_KEYS = {
  all: ['product-tags'] as const,
  list: (productId: string) => [...PRODUCT_TAG_KEYS.all, 'list', productId] as const,
};

export function useProductTags(productId: string) {
  return useQuery({
    queryKey: PRODUCT_TAG_KEYS.list(productId),
    queryFn: async ({ signal }) => {
      const response = await productTagsApi.listTags(productId, signal);
      return response.tags.map(ProductTagTransformers.toModel);
    },
    enabled: !!productId,
  });
}

export function useAddProductTag(productId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ tagCode, signal }: { tagCode: string; signal?: AbortSignal }) => {
      const request = ProductTagTransformers.toCreateRequest(tagCode);
      return productTagsApi.createTag(productId, request, signal);
    },
    // Owns its own invalidation — the panel that calls this hook doesn't need
    // to know which query key backs the list it's about to go stale.
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PRODUCT_TAG_KEYS.list(productId) });
    },
    // Surface `error` via your project's own notification/toast mechanism
    // here (an onError handler) — this template shows the invalidation
    // contract, not a specific UI feedback implementation.
  });
}

export function useRemoveProductTag(productId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ tagId, signal }: { tagId: number; signal?: AbortSignal }) => {
      return productTagsApi.removeTag(productId, tagId, signal);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PRODUCT_TAG_KEYS.list(productId) });
    },
  });
}
