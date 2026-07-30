// product-tag-dto.types.ts — react-slice worked example: "Product Tags"
//
// Wire-shape types, matching templates/api-contract.md's field names exactly
// — this file's shape is the wire contract, not a place to pre-emptively
// camelCase anything. Translation to the domain model happens only in
// product-tags.transformers.ts.
//
// This example's wire format happens to use snake_case (common for many
// backend stacks); if your real backend already emits camelCase, this layer
// still exists — it just has less casing work to do. The point is having ONE
// seam for whatever translation IS needed, not the specific casing choice.

export interface ProductTagDTO {
  tag_id: number;
  tag_code: string;
  tag_label: string | null;
  created_by: number;
  created_by_name: string | null;
  created_at: string; // ISO 8601
}

export interface CreateProductTagRequest {
  tag_code: string;
}
