// product-tags.api.ts — react-slice worked example: "Product Tags"
//
// Extends BaseApiService, which react-bootstrap ships at
// templates/shared/api/base-api.service.ts. Inheriting it gets three things
// for free, so no feature re-implements them:
//   - the ONE configured axios instance (auth + retry interceptors attached)
//   - error mapping: every failure leaves as ApiError, never an AxiosError
//   - the basePath prefix applied to each call
//
// EVERY method accepts and forwards an AbortSignal, so a query's cancellation
// actually reaches the network instead of the request completing after the
// hook that started it has gone away. The capability is usually already
// present in a client wrapper; the common gap is that nothing passes one
// through (see the SKILL.md's "Threading { signal }" section).
import { BaseApiService } from '@/shared/api/base-api.service';
import type { ProductTagDTO, CreateProductTagRequest } from '../types/product-tag-dto.types';

class ProductTagsApiService extends BaseApiService {
  constructor() {
    super('/products');
  }

  async listTags(productId: string, signal?: AbortSignal): Promise<{ tags: ProductTagDTO[] }> {
    return this.get<{ tags: ProductTagDTO[] }>(`/${productId}/tags`, { signal });
  }

  async createTag(
    productId: string,
    request: CreateProductTagRequest,
    signal?: AbortSignal
  ): Promise<{ tag: ProductTagDTO }> {
    return this.post<{ tag: ProductTagDTO }>(`/${productId}/tags`, request, { signal });
  }

  async removeTag(productId: string, tagId: number, signal?: AbortSignal): Promise<void> {
    return this.delete<void>(`/${productId}/tags/${tagId}`, { signal });
  }
}

export const productTagsApi = new ProductTagsApiService();
