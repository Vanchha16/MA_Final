import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Button, Card, Chip, ConfirmDialog, Empty, ErrorBox, FilterChips, Icon, PageTitle, Photo, SearchBox } from '../components/ui';
import { timeAgo } from '../lib/format';

const TAGS = { quality: 'Great quality', as_pictured: 'As pictured', packaging: 'Well packed', delivery: 'Fast delivery', value: 'Good value' };

const Stars = ({ n }) => (
  <span className="inline-flex text-amber-500" aria-label={`${n} stars`}>
    {[1, 2, 3, 4, 5].map((i) => <Icon key={i} name="star" size={15} className={i <= n ? '' : 'text-slate-300'} />)}
  </span>
);

/** Every review in the shop; remove spam or rude ones. */
export default function Reviews() {
  const toast = useToast();
  const [page, setPage] = useState(null);
  const [error, setError] = useState(null);
  const [rating, setRating] = useState('all');
  const [q, setQ] = useState('');
  const [deleting, setDeleting] = useState(null);

  const load = useCallback(async () => {
    try {
      setPage(await api.get('/admin/reviews', { per_page: 100, rating: rating === 'all' ? undefined : rating, q }));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, [rating, q]);
  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  const remove = async () => {
    try {
      await api.del(`/admin/reviews/${deleting.id}`);
      toast('Review deleted · the product rating is updated');
      load();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setDeleting(null);
    }
  };

  return (
    <>
      <PageTitle title="Reviews" sub="Only customers who received a product can review it.">
        <SearchBox value={q} onChange={setQ} placeholder="Product or customer" />
      </PageTitle>
      <FilterChips items={[['all', 'All'], ...[5, 4, 3, 2, 1].map((n) => [String(n), `${n} star${n === 1 ? '' : 's'}`])]} value={rating} onChange={setRating} />
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {page === null ? <div className="p-10 text-center text-muted">Loading…</div> : page.items.length === 0 ? <Empty icon="star" text="No reviews here." /> : (
          <table className="data">
            <thead><tr><th>Product</th><th>Customer</th><th>Rating</th><th>Review</th><th>When</th><th /></tr></thead>
            <tbody>
              {page.items.map((r) => (
                <tr key={r.id} data-testid={`review-${r.id}`}>
                  <td><div className="flex items-center gap-2.5"><Photo src={r.product.image_url} size={36} /><span className="max-w-[200px] truncate font-semibold">{r.product.name}</span></div></td>
                  <td><div className="font-semibold">{r.customer.full_name}</div><div className="text-[12px] text-muted">{r.customer.email}</div></td>
                  <td><Stars n={r.rating} /></td>
                  <td className="max-w-[340px]">
                    <div className="line-clamp-2">{r.comment || <span className="text-muted">Stars only</span>}</div>
                    {r.tags.length > 0 && <div className="mt-1 flex flex-wrap gap-1">{r.tags.map((t) => <Chip key={t} className="bg-slate-100 text-slate-600">{TAGS[t] || t}</Chip>)}</div>}
                  </td>
                  <td className="whitespace-nowrap text-muted">{timeAgo(r.created_at)}{r.edited ? ' · edited' : ''}</td>
                  <td className="text-right"><Button small variant="dangerOutline" icon="delete" onClick={() => setDeleting(r)} data-testid={`review-delete-${r.id}`}>Delete</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <ConfirmDialog open={!!deleting} title="Delete this review?" message={`${deleting?.customer.full_name}'s review of ${deleting?.product.name} is removed for everyone.`} confirmLabel="Delete" onCancel={() => setDeleting(null)} onConfirm={remove} />
    </>
  );
}
