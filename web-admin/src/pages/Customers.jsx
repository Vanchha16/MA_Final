import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Button, Card, Chip, ConfirmDialog, Drawer, Empty, ErrorBox, FilterChips, PageTitle, SearchBox, Spinner, StatusChip } from '../components/ui';
import { dateTime, money } from '../lib/format';

const FILTERS = [['all', 'All', () => true], ['active', 'Active', (c) => c.is_active], ['blocked', 'Blocked', (c) => !c.is_active]];

export default function Customers() {
  const toast = useToast();
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [q, setQ] = useState('');
  const [openId, setOpenId] = useState(null);
  const [detail, setDetail] = useState(null);
  const [askBlock, setAskBlock] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setItems((await api.get('/admin/customers', { per_page: 100 })).items);
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load]);
  useEffect(() => {
    setDetail(null);
    if (openId) api.get(`/admin/customers/${openId}`).then(setDetail).catch((e) => toast(e.message, { error: true }));
  }, [openId, toast]);

  const shown = useMemo(() => {
    const test = FILTERS.find((f) => f[0] === filter)[2];
    const needle = q.trim().toLowerCase();
    return (items || []).filter((c) => test(c) && (!needle || `${c.full_name} ${c.email} ${c.phone || ''}`.toLowerCase().includes(needle)));
  }, [items, filter, q]);

  const setActive = async (active) => {
    setBusy(true);
    try {
      const c = await api.put(`/admin/customers/${detail.id}`, { is_active: active });
      setDetail({ ...detail, is_active: c.is_active });
      toast(active ? `${c.full_name} can log in again` : `${c.full_name} is blocked and signed out`, { icon: active ? 'check_circle' : 'block' });
      load();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(false);
      setAskBlock(false);
    }
  };

  return (
    <>
      <PageTitle title="Customers" sub="Blocking signs a customer out at once.">
        <SearchBox value={q} onChange={setQ} placeholder="Name, email or phone" />
      </PageTitle>
      <FilterChips items={FILTERS.map(([k, l, t]) => [k, l, items ? items.filter(t).length : null])} value={filter} onChange={setFilter} />
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {items === null ? <div className="p-10 text-center text-muted">Loading…</div> : shown.length === 0 ? <Empty icon="group" text="No customers here." /> : (
          <table className="data">
            <thead><tr><th>Customer</th><th>Phone</th><th>Orders</th><th>Spent</th><th>Joined</th><th>Status</th></tr></thead>
            <tbody>
              {shown.map((c) => (
                <tr key={c.id} className="clickable" onClick={() => setOpenId(c.id)} data-testid={`customer-${c.id}`}>
                  <td>
                    <div className="flex items-center gap-3">
                      <div className={`grid h-9 w-9 place-items-center rounded-full font-bold ${c.is_active ? 'bg-brand-tint text-brand' : 'bg-red-100 text-red-700'}`}>{c.full_name[0]}</div>
                      <div><div className="font-semibold">{c.full_name}</div><div className="text-[12px] text-muted">{c.email}</div></div>
                    </div>
                  </td>
                  <td className="text-muted">{c.phone || '—'}</td>
                  <td>{c.order_count}</td>
                  <td className="font-bold">{money(c.total_spent)}</td>
                  <td className="text-muted">{dateTime(c.created_at).split(',')[0]}</td>
                  <td>{c.is_active ? <Chip className="bg-green-100 text-green-700">Active</Chip> : <Chip className="bg-red-100 text-red-700">Blocked</Chip>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Drawer
        open={openId !== null}
        onClose={() => setOpenId(null)}
        width={480}
        title="Customer"
        footer={detail && (detail.is_active
          ? <Button variant="danger" className="w-full" icon="block" onClick={() => setAskBlock(true)} data-testid="customer-block">Block customer</Button>
          : <Button className="w-full" icon="check_circle" loading={busy} onClick={() => setActive(true)} data-testid="customer-unblock">Unblock customer</Button>)}
      >
        {!detail ? <div className="grid place-items-center py-16 text-brand"><Spinner /></div> : (
          <div className="flex flex-col gap-5 text-[13.5px]">
            <div className="flex flex-col items-center text-center">
              <div className="mb-2 grid h-16 w-16 place-items-center rounded-full bg-brand-tint text-2xl font-bold text-brand">{detail.full_name[0]}</div>
              <div className="text-lg font-bold">{detail.full_name}</div>
              <div className="text-muted">{detail.email}{detail.phone ? ` · ${detail.phone}` : ''}</div>
              <div className="mt-2 flex gap-2">{detail.is_active ? <Chip className="bg-green-100 text-green-700">Active</Chip> : <Chip className="bg-red-100 text-red-700">Blocked</Chip>}</div>
            </div>
            <div className="grid grid-cols-2 gap-3 text-center">
              <div className="rounded-2xl bg-soft p-3"><div className="text-xl font-extrabold">{detail.order_count}</div><div className="text-muted">orders</div></div>
              <div className="rounded-2xl bg-soft p-3"><div className="text-xl font-extrabold">{money(detail.total_spent)}</div><div className="text-muted">spent</div></div>
            </div>
            {detail.addresses?.length > 0 && (
              <section>
                <h3 className="mb-2 text-[11px] font-bold tracking-wider text-muted">ADDRESSES</h3>
                {detail.addresses.map((a) => <div key={a.id} className="py-1">{a.label} · {a.recipient_name}, {a.one_line}</div>)}
              </section>
            )}
            {detail.orders?.length > 0 && (
              <section>
                <h3 className="mb-2 text-[11px] font-bold tracking-wider text-muted">ORDERS</h3>
                {detail.orders.map((o) => (
                  <div key={o.id} className="flex items-center gap-3 py-1.5">
                    <span className="flex-1 font-semibold">{o.order_number}</span><StatusChip status={o.status} /><span className="w-20 text-right font-bold">{money(o.total)}</span>
                  </div>
                ))}
              </section>
            )}
          </div>
        )}
      </Drawer>
      <ConfirmDialog
        open={askBlock}
        title={`Block ${detail?.full_name}?`}
        message="They are signed out at once and cannot log in until you unblock them."
        confirmLabel="Block"
        busy={busy}
        onCancel={() => setAskBlock(false)}
        onConfirm={() => setActive(false)}
      />
    </>
  );
}
