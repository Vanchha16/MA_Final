import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api } from '../api';
import OrderDrawer from '../components/OrderDrawer';
import { useToast } from '../components/toast';
import { Button, Card, Chip, Empty, ErrorBox, FilterChips, Icon, PageTitle, Photo, SearchBox, StatusChip } from '../components/ui';
import { STEP_DONE, STEP_LABEL, dateTime, money, nextStep, paymentName, paymentText } from '../lib/format';
import { useStats } from '../stats';

const FILTERS = [
  ['handle', 'To handle', (o) => ['pending', 'confirmed'].includes(o.status)],
  ['pending', 'Pending', (o) => o.status === 'pending'],
  ['confirmed', 'Confirmed', (o) => o.status === 'confirmed'],
  ['shipped', 'Shipped', (o) => o.status === 'shipped'],
  ['delivered', 'Delivered', (o) => o.status === 'delivered'],
  ['cancelled', 'Cancelled', (o) => o.status === 'cancelled'],
  ['refund', 'Refund to send', (o) => o.payment_status === 'refund_pending'],
  ['all', 'All', () => true],
];

export default function Orders() {
  const { id } = useParams();
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const toast = useToast();
  const { refresh, tick } = useStats();
  const [orders, setOrders] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const q = params.get('q') || '';
  const filter = params.get('status') || (q ? 'all' : 'handle');

  const load = useCallback(async () => {
    try {
      setOrders((await api.get('/admin/orders', { per_page: 100 })).items);
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
    return (orders || []).filter((o) => test(o) && (!needle || `${o.order_number} ${o.customer.full_name} ${o.customer.email}`.toLowerCase().includes(needle)));
  }, [orders, filter, q]);

  const move = async (o, status) => {
    setBusy(o.id);
    try {
      const updated = await api.put(`/admin/orders/${o.id}/status`, { status });
      toast(`${updated.order_number} ${STEP_DONE[status]} · the customer was told`);
      await Promise.all([load(), refresh()]);
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <PageTitle title="Orders" sub="Move orders on one step at a time; the customer is told each time.">
        <SearchBox value={q} onChange={(v) => set('q', v)} placeholder="Order number, customer or email" />
      </PageTitle>
      <FilterChips
        items={FILTERS.map(([key, label, test]) => [key, label, orders ? orders.filter(test).length : null])}
        value={filter}
        onChange={(v) => set('status', v)}
      />
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {orders === null ? <div className="p-10 text-center text-muted">Loading…</div> : shown.length === 0 ? (
          <Empty icon="receipt_long" text="No orders here." />
        ) : (
          <table className="data">
            <thead><tr><th>Order</th><th>Placed</th><th>Customer</th><th>Items</th><th>Total</th><th>Payment</th><th>Status</th><th /></tr></thead>
            <tbody>
              {shown.map((o) => {
                const step = nextStep(o);
                return (
                  <tr key={o.id} className="clickable" onClick={() => navigate(`/orders/${o.id}?${params}`)} data-testid={`orders-row-${o.id}`}>
                    <td className="font-bold text-brand">{o.order_number}</td>
                    <td className="text-muted">{dateTime(o.created_at)}</td>
                    <td><div className="font-semibold">{o.customer.full_name}</div><div className="text-[12px] text-muted">{o.customer.email}</div></td>
                    <td><div className="flex items-center gap-2"><Photo src={o.image_url} size={32} /><span className="text-muted">{o.item_count}</span></div></td>
                    <td className="font-bold">{money(o.total)}</td>
                    <td className="text-muted">{paymentText(o)}</td>
                    <td><StatusChip status={o.status} /></td>
                    <td className="text-right" onClick={(ev) => ev.stopPropagation()}>
                      {step ? (
                        <Button small loading={busy === o.id} onClick={() => move(o, step)} data-testid={`orders-step-${o.id}`}>{STEP_LABEL[step]}</Button>
                      ) : o.payment_status === 'refund_pending' ? <Chip className="bg-amber-100 text-amber-700"><Icon name="currency_exchange" size={13} />Refund to send</Chip>
                        : o.status === 'pending' ? <Chip className="bg-amber-100 text-amber-700">Waiting for {paymentName(o)}</Chip> : null}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>
      <OrderDrawer
        orderId={id ? Number(id) : null}
        onClose={() => navigate(`/orders?${params}`)}
        onChanged={() => Promise.all([load(), refresh()])}
      />
    </>
  );
}
