import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Button, Card, Chip, Empty, ErrorBox, FilterChips, PageTitle, Photo, SearchBox, Toggle } from '../components/ui';
import { money } from '../lib/format';
import { useStats } from '../stats';

const FILTERS = [
  ['all', 'All', () => true],
  ['low', 'Low stock', (p) => p.is_active && p.stock <= 3],
  ['soldout', 'Sold out', (p) => p.stock === 0],
  ['hidden', 'Hidden', (p) => !p.is_active],
];

export default function Products() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const toast = useToast();
  const { refresh, tick } = useStats();
  const [products, setProducts] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const filter = params.get('filter') || 'all';
  const q = params.get('q') || '';

  const load = useCallback(async () => {
    try {
      setProducts((await api.get('/admin/products', { per_page: 100 })).items);
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load, tick]);

  const set = (key, value) => {
    const next = new URLSearchParams(params);
    value ? next.set(key, value) : next.delete(key);
    setParams(next, { replace: true });
  };

  const shown = useMemo(() => {
    const test = FILTERS.find((f) => f[0] === filter)?.[2] || (() => true);
    const needle = q.trim().toLowerCase();
    return (products || []).filter((p) => test(p) && (!needle || `${p.name} ${p.brand || ''} ${p.category.name}`.toLowerCase().includes(needle)));
  }, [products, filter, q]);

  const update = async (p, body, message, key) => {
    setBusy(key);
    try {
      const saved = await api.put(`/admin/products/${p.id}`, body);
      setProducts((list) => list.map((x) => (x.id === saved.id ? saved : x)));
      toast(message(saved), { icon: 'inventory_2' });
      refresh();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <PageTitle title="Products" sub={products ? `${products.filter((p) => p.is_active).length} in the shop · ${products.length} in total` : ' '}>
        <SearchBox value={q} onChange={(v) => set('q', v)} placeholder="Name, brand or category" />
        <Button icon="add" onClick={() => navigate('/products/new')}>Add product</Button>
      </PageTitle>
      <FilterChips items={FILTERS.map(([k, l, t]) => [k, l, products ? products.filter(t).length : null])} value={filter} onChange={(v) => set('filter', v)} />
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {products === null ? <div className="p-10 text-center text-muted">Loading…</div> : shown.length === 0 ? (
          <Empty icon="inventory_2" text="No products here." />
        ) : (
          <table className="data">
            <thead><tr><th>Product</th><th>Category</th><th>Price</th><th>Stock</th><th>In shop</th><th /></tr></thead>
            <tbody>
              {shown.map((p) => (
                <tr key={p.id} className={`clickable ${p.is_active ? '' : 'opacity-60'}`} onClick={() => navigate(`/products/${p.id}`)} data-testid={`product-row-${p.id}`}>
                  <td>
                    <div className="flex items-center gap-3">
                      <Photo src={p.image_url} size={44} />
                      <div className="min-w-0">
                        <div className="font-semibold">{p.name}</div>
                        <div className="text-[12px] text-muted">{p.brand || '—'}{p.is_featured ? ' · Featured' : ''}</div>
                      </div>
                    </div>
                  </td>
                  <td className="text-muted">{p.category.name}</td>
                  <td>
                    <span className="font-bold">{money(p.discount_price ?? p.price)}</span>
                    {p.discount_price != null && <span className="ml-1.5 text-[12px] text-muted line-through">{money(p.price)}</span>}
                  </td>
                  <td>
                    <Chip className={p.stock === 0 ? 'bg-red-100 text-red-700' : p.stock <= 3 ? 'bg-amber-100 text-amber-700' : 'bg-green-100 text-green-700'}>
                      {p.stock === 0 ? 'Sold out' : `${p.stock} left`}
                    </Chip>
                  </td>
                  <td onClick={(e) => e.stopPropagation()}>
                    <Toggle
                      checked={p.is_active}
                      label={`${p.name} in the shop`}
                      disabled={busy === `shop-${p.id}`}
                      onChange={(on) => update(p, { is_active: on }, (s) => (on ? `${s.name} is back in the shop` : `${s.name} is hidden from the shop`), `shop-${p.id}`)}
                    />
                  </td>
                  <td className="text-right" onClick={(e) => e.stopPropagation()}>
                    <Button small variant="ghost" loading={busy === `stock-${p.id}`} onClick={() => update(p, { stock: p.stock + 5 }, (s) => `${s.name} restocked · ${s.stock} in stock`, `stock-${p.id}`)} data-testid={`products-restock-${p.id}`}>
                      +5
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </>
  );
}
