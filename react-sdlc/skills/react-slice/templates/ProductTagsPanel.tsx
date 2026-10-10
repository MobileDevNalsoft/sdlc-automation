// ProductTagsPanel.tsx — react-slice worked example: "Product Tags"
//
// Terminal component of the slice: consumes the hooks, and never touches
// ProductTagDTO or a wire-format field. It renders all FIVE states, because
// skipping one is the most common defect in this layer:
//
//   loading (Skeleton) | empty (EmptyState) | error (ErrorState) | gated (PermissionGate) | loaded
//
// AN EMPTY LIST IS NOT AN ERROR. Rendering "failed to load" for a successful
// response with zero rows teaches users to distrust the app and hides the
// actual call to action. They are separate branches on purpose.
//
// EVERY WRITE AFFORDANCE GOES THROUGH PermissionGate:
//   * Group absent    -> render nothing
//   * ACCESS_TYPE='V' -> render child disabled with reason visible
import { useState } from 'react';
import { Button } from '@/shared/ui/Button';
import { EmptyState } from '@/shared/ui/EmptyState';
import { ErrorState } from '@/shared/ui/ErrorState';
import { Skeleton } from '@/shared/ui/Skeleton';
import { PermissionGate } from '@/shared/ui/PermissionGate';
import { useAddProductTag, useProductTags, useRemoveProductTag } from '../api/product-tags.queries';

interface ProductTagsPanelProps {
  productId: string;
}

export function ProductTagsPanel({ productId }: ProductTagsPanelProps): React.ReactElement {
  const [newTagCode, setNewTagCode] = useState('');
  const { data: tags, isPending, error, refetch } = useProductTags(productId);
  const addTag = useAddProductTag(productId);
  const removeTag = useRemoveProductTag(productId);

  // State 1: Loading — reserved geometry via Skeleton
  if (isPending) {
    return (
      <div className="space-y-3 p-4">
        <Skeleton className="h-6 w-32" />
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-full" />
      </div>
    );
  }

  // State 2: Error — actionable failure with Retry
  if (error) {
    return (
      <ErrorState
        error={error}
        title="Could not load tags"
        onRetry={() => {
          void refetch();
        }}
      />
    );
  }

  // State 3 & 5: Empty vs Loaded
  return (
    <section className="space-y-4 p-4 rounded-card bg-surface border border-border">
      {tags.length === 0 ? (
        <EmptyState
          title="No tags assigned"
          description="Tags help organize and filter products across the catalog."
        />
      ) : (
        <ul className="divide-y divide-border">
          {tags.map((tag) => (
            <li key={tag.id} className="flex items-center justify-between py-2">
              <span className="text-sm font-medium text-fg">{tag.tagLabel}</span>
              <PermissionGate permission="PRODUCT_TAGS_WRITE" mode="write">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    removeTag.mutate({ tagId: tag.tagId });
                  }}
                  isLoading={removeTag.isPending && removeTag.variables?.tagId === tag.tagId}
                >
                  Remove
                </Button>
              </PermissionGate>
            </li>
          ))}
        </ul>
      )}

      {/* Write Affordance: Add Tag Form */}
      <PermissionGate permission="PRODUCT_TAGS_WRITE" mode="write">
        <form
          className="flex items-center gap-2 pt-2 border-t border-border"
          onSubmit={(e) => {
            e.preventDefault();
            const code = newTagCode.trim();
            if (code === '') return;
            addTag.mutate(
              { tagCode: code },
              {
                onSuccess: () => {
                  setNewTagCode('');
                },
              }
            );
          }}
        >
          <input
            className="flex-1 px-3 py-1.5 text-sm rounded-control bg-bg border border-border text-fg placeholder:text-fg-muted focus:outline-none focus:ring-2 focus:ring-primary/20"
            value={newTagCode}
            onChange={(e) => {
              setNewTagCode(e.target.value);
            }}
            placeholder="Tag code"
            aria-label="New tag code"
          />
          <Button type="submit" isLoading={addTag.isPending}>
            Add tag
          </Button>
        </form>
      </PermissionGate>

      {/* Mutation error alert */}
      {addTag.error && (
        <ErrorState
          error={addTag.error}
          title="Could not add tag"
          className="p-4"
        />
      )}
    </section>
  );
}
