// ProductTagsPanel.tsx — react-slice worked example: "Product Tags"
//
// Terminal component of the slice: consumes the hooks, and never touches
// ProductTagDTO or a wire-format field. It renders all FOUR states, because
// skipping one is the most common defect in this layer:
//
//   loading | error | EMPTY | populated
//
// AN EMPTY LIST IS NOT AN ERROR. Rendering "failed to load" for a successful
// response with zero rows teaches users to distrust the app and hides the
// actual call to action. They are separate branches on purpose.
//
// It uses the shared primitives (Button, ErrorView, EmptyState, LoadingState)
// that react-bootstrap ships, rather than raw <button>/<div> — the same rule
// flutter-sdlc enforces when it requires AppButton over FilledButton. That is
// an ARCHITECTURE choice (states and semantics are decided once), not a visual
// one: spacing, color, typography and layout remain owned by
// sdlc-core:ui-ux-web and reviewed by sdlc-core:ui-ux-review, not by this
// skill. Copy your own feature's existing component conventions over this
// file's markup.
import { useState } from 'react';
import { Button } from '@/shared/ui/Button';
import { EmptyState, ErrorView } from '@/shared/ui/ErrorView';
import { LoadingState } from '@/shared/ui/Spinner';
import { useAddProductTag, useProductTags, useRemoveProductTag } from '../api/product-tags.queries';

interface ProductTagsPanelProps {
  productId: string;
}

export function ProductTagsPanel({ productId }: ProductTagsPanelProps): React.ReactElement {
  const [newTagCode, setNewTagCode] = useState('');
  // `isPending` (not `isLoading`) is the v5 flag for "there is no data yet".
  const { data: tags, isPending, error, refetch } = useProductTags(productId);
  const addTag = useAddProductTag(productId);
  const removeTag = useRemoveProductTag(productId);

  if (isPending) return <LoadingState label="Loading tags" />;

  // `error` is an ApiError, already mapped by BaseApiService — ErrorView reads
  // its `.detail` to decide whether offering "Try again" is even honest.
  if (error) {
    return (
      <ErrorView
        error={error}
        title="Could not load tags"
        onRetry={() => {
          void refetch();
        }}
      />
    );
  }

  return (
    <section>
      {tags.length === 0 ? (
        <EmptyState title="No tags yet" description="Tags you add will appear here." />
      ) : (
        <ul>
          {tags.map((tag) => (
            <li key={tag.id}>
              {tag.tagLabel}
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  removeTag.mutate({ tagId: tag.tagId });
                }}
                // Disabling only the row being removed, rather than every row,
                // keeps the rest of the list usable during the request.
                isLoading={removeTag.isPending && removeTag.variables?.tagId === tag.tagId}
              >
                Remove
              </Button>
            </li>
          ))}
        </ul>
      )}

      <form
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
          value={newTagCode}
          onChange={(e) => {
            setNewTagCode(e.target.value);
          }}
          placeholder="Tag code"
          aria-label="New tag code"
        />
        {/* type="submit" is explicit: Button defaults to type="button" so that
            an icon button elsewhere cannot accidentally submit its form. */}
        <Button type="submit" isLoading={addTag.isPending}>
          Add tag
        </Button>
      </form>

      {/* Mutation failures need their own surface — the query-level ErrorView
          above has already returned by this point, so a failed add would
          otherwise be completely silent. */}
      {addTag.error && <ErrorView error={addTag.error} title="Could not add tag" />}
    </section>
  );
}
