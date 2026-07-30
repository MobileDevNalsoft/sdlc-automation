// ProductTagsPanel.tsx — react-slice worked example: "Product Tags"
//
// Terminal component of the slice — consumes the hooks, never touches
// ProductTagDTO or a wire-format field directly. Kept deliberately small:
// this template exists to show the wiring (loading/error states, mutation
// pending states, cache-invalidation-driven refetch), not to be a complete
// UI. Markup/styling is intentionally plain <div>/<button> — visual design
// (spacing, color, typography, layout) is owned by sdlc-core:ui-ux-web,
// reviewed by sdlc-core:ui-ux-review, not by this skill (see SKILL.md's
// "Presentation layer" section). Copy this slice's OWN feature's existing
// component/styling conventions instead of this file's markup.
import { useState } from 'react';
import { useProductTags, useAddProductTag, useRemoveProductTag } from '../api/product-tags.queries';

interface ProductTagsPanelProps {
  productId: string;
}

export function ProductTagsPanel({ productId }: ProductTagsPanelProps) {
  const [newTagCode, setNewTagCode] = useState('');
  const { data: tags, isLoading, isError } = useProductTags(productId);
  const addTag = useAddProductTag(productId);
  const removeTag = useRemoveProductTag(productId);

  if (isLoading) return <p>Loading tags…</p>;
  if (isError) return <p role="alert">Failed to load tags.</p>;

  return (
    <div>
      <ul>
        {(tags ?? []).map((tag) => (
          <li key={tag.id}>
            {tag.tagLabel}
            <button
              type="button"
              onClick={() => removeTag.mutate({ tagId: tag.tagId })}
              disabled={removeTag.isPending}
            >
              Remove
            </button>
          </li>
        ))}
      </ul>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!newTagCode.trim()) return;
          addTag.mutate({ tagCode: newTagCode.trim() }, { onSuccess: () => setNewTagCode('') });
        }}
      >
        <input
          value={newTagCode}
          onChange={(e) => setNewTagCode(e.target.value)}
          placeholder="Tag code"
          aria-label="New tag code"
        />
        <button type="submit" disabled={addTag.isPending}>
          Add tag
        </button>
      </form>
    </div>
  );
}
