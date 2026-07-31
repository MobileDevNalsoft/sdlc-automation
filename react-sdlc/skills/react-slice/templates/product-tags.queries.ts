// product-tags.queries.ts — react-slice worked example: "Product Tags"
//
// Query-key factory + useQuery + mutation hooks that each own their own
// cache invalidation. `{ signal }` is destructured from TanStack Query's
// queryFn context and threaded into the api call, so navigating away from a
// product's tag panel actually cancels the in-flight request instead of
// letting it resolve into a query that's no longer mounted.
// The error type is ApiError everywhere, because BaseApiService maps before
// throwing. That is what lets a component do an exhaustive
// `switch (error.detail.kind)` instead of poking at an axios error shape.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { UseMutationResult, UseQueryResult } from '@tanstack/react-query';
import type { ApiError } from '@/shared/api/api-error';
import { productTagsApi } from './product-tags.api';
import { ProductTagTransformers } from './product-tags.transformers';
import type { ProductTag } from './product-tags.transformers';
import type { ProductTagDTO } from '../types/product-tag-dto.types';

export const PRODUCT_TAG_KEYS = {
  all: ['product-tags'] as const,
  list: (productId: string) => [...PRODUCT_TAG_KEYS.all, 'list', productId] as const,
};

export function useProductTags(productId: string): UseQueryResult<ProductTag[], ApiError> {
  return useQuery<ProductTag[], ApiError>({
    queryKey: PRODUCT_TAG_KEYS.list(productId),
    queryFn: async ({ signal }) => {
      const response = await productTagsApi.listTags(productId, signal);
      return response.tags.map(ProductTagTransformers.toModel);
    },
    enabled: !!productId,
  });
}

export function useAddProductTag(
  productId: string
): UseMutationResult<{ tag: ProductTagDTO }, ApiError, { tagCode: string; signal?: AbortSignal }> {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ tagCode, signal }) => {
      const request = ProductTagTransformers.toCreateRequest(tagCode);
      return productTagsApi.createTag(productId, request, signal);
    },
    // Owns its own invalidation — the panel calling this hook doesn't need to
    // know which query key backs the list it's about to make stale.
    //
    // `void` is deliberate: invalidateQueries returns a promise, and leaving
    // it unhandled is the kind of floating promise that only surfaces once
    // type-aware linting is switched on. Awaiting it instead would keep the
    // mutation in `isPending` until the refetch settles — sometimes what you
    // want (the list is the confirmation), usually not.
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: PRODUCT_TAG_KEYS.list(productId) });
    },
    // No onError here. The mutation's `error` is an ApiError and the component
    // renders it (see ProductTagsPanel) — a toast fired from this layer would
    // be a UI decision made in the data layer.
  });
}

export function useRemoveProductTag(
  productId: string
): UseMutationResult<void, ApiError, { tagId: number; signal?: AbortSignal }> {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ tagId, signal }) => productTagsApi.removeTag(productId, tagId, signal),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: PRODUCT_TAG_KEYS.list(productId) });
    },
  });
}
