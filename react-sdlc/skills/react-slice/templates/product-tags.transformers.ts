// product-tags.transformers.ts — react-slice worked example: "Product Tags"
//
// Wire format <-> domain model, the ONLY place this translation happens for
// this slice. Components and hooks in this slice only ever see ProductTag,
// never ProductTagDTO.
import type { ProductTagDTO, CreateProductTagRequest } from '../types/product-tag-dto.types';

export interface ProductTag {
  id: string;
  tagId: number;
  tagCode: string;
  tagLabel: string;
  createdBy: number;
  createdByName: string;
  createdAt: string;
}

export const ProductTagTransformers = {
  toModel(dto: ProductTagDTO): ProductTag {
    return {
      id: dto.tag_id.toString(),
      tagId: dto.tag_id,
      tagCode: dto.tag_code,
      tagLabel: dto.tag_label || dto.tag_code, // fall back to the code if a label lookup missed
      createdBy: dto.created_by,
      createdByName: dto.created_by_name || 'Unknown',
      createdAt: dto.created_at,
    };
  },

  // Domain -> wire, for the create mutation.
  toCreateRequest(tagCode: string): CreateProductTagRequest {
    return { tag_code: tagCode };
  },
};
