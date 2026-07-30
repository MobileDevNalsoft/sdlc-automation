// product-tags.api.ts — react-slice worked example: "Product Tags"
//
// Extends your project's shared HTTP client base class the same way every
// other feature's *.api.ts does — this template doesn't assume axios vs
// fetch specifically (see react-bootstrap/SKILL.md's "HTTP client choice"),
// only that the base class's methods accept and forward an options object
// that includes an AbortSignal.
//
// EVERY method here accepts and forwards an AbortSignal, so a query's
// cancellation actually reaches the network call instead of the request
// continuing after the component/hook that started it has gone away. This
// does NOT require changing the shared base class — most HTTP client
// wrappers already accept a per-request signal; the usual gap is that no
// feature's *.api.ts actually passes one through (see the SKILL.md's
// "Threading { signal }" section).
import { BaseApiService } from '../../../shared/api/base-api.service';
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
