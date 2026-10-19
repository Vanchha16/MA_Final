import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bar, BarChart, Cell, LabelList, ResponsiveContainer, XAxis } from 'recharts';
import { api } from '../api';
import OrderDrawer from '../components/OrderDrawer';
import ReplyDrawer from '../components/ReplyDrawer';
import { useToast } from '../components/toast';
import { Button, Card, Chip, Empty, ErrorBox, Icon, Kpi, PageTitle, Photo, SearchBox, StatusChip } from '../components/ui';
import { useAuth } from '../auth';
import { STEP_DONE, STEP_LABEL, greeting, money, moneyShort, nextStep, paymentName, paymentText, timeAgo } from '../lib/format';
import { useStats } from '../stats';
import { useTheme } from '../theme';

const KIND = {
  paid: ['payments', 'bg-green-100 text-green-700'],
  order: ['shopping_bag', 'bg-brand-tint text-brand'],
  message: ['forum', 'bg-cyan-100 text-cyan-700'],
  review: ['star', 'bg-amber-100 text-amber-700'],
  sold_out: ['inventory_2', 'bg-red-100 text-red-700'],
};
const ACTION_LABEL = { confirm: 'Confirm', ship: 'Ship it', reply: 'Reply', restock: 'Restock' };

export default function Dashboard() {
  const { user } = useAuth();
  const { resolved } = useTheme();
  const dark = resolved === 'dark';
  const { stats, error: statsError, refresh, tick } = useStats();
  const toast = useToast();
  const navigate = useNavigate();
  const [orders, setOrders] = useState(null);
  const [events, setEvents] = useState(null);
  const [low, setLow] = useState(null);
  const [messages, setMessages] = useState([]);
  const [busy, setBusy] = useState(null);
  const [error, setError] = useState(null);
  const [openOrder, setOpenOrder] = useState(null);
  const [replyTo, setReplyTo] = useState(null);
  const [q, setQ] = useState('');
  const seen = useRef(null); // event ids already shown; newer ones glow
  const [fresh, setFresh] = useState(new Set());

  const load = useCallback(async () => {
    try {
      const [o, a, p, m] = await Promise.all([
        api.get('/admin/orders', { per_page: 50 }),
        api.get('/admin/activity', { limit: 8 }),
        api.get('/admin/products', { low_stock: 1, active: 1, per_page: 8 }),
        api.get('/admin/contact-messages', { status: 'open', per_page: 50 }),
      ]);
      setOrders(o.items.filter((x) => nextStep(x) || (x.status === 'pending' && x.payment_status !== 'paid')).slice(0, 6));
      if (seen.current) setFresh(new Set(a.filter((e) => !seen.current.has(e.id)).map((e) => e.id)));
      seen.current = new Set(a.map((e) => e.id));
      setEvents(a);
      setLow([...p.items].sort((x, y) => x.stock - y.stock));
      setMessages(m.items);
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => { load(); }, [load, tick]);

  const after = async () => { await refresh(); };

  const moveOrder = async (orderId, status, key) => {
    setBusy(key);
    try {
      const o = await api.put(`/admin/orders/${orderId}/status`, { status });
      toast(`${o.order_number} ${STEP_DONE[status]} · the customer was told`);
      await after();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(null);
    }
  };

  const restock = async (product, key) => {
    setBusy(key);
    try {
      const p = await api.put(`/admin/products/${product.id}`, { stock: Math.max(0, product.stock) + 5 });
      toast(`${p.name} restocked · ${p.stock} in stock`, { icon: 'inventory_2' });
      await after();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(null);
    }
  };

  const act = async (e) => {
    const key = `act-${e.id}`;
    if (e.action === 'confirm') return moveOrder(e.order_id, 'confirmed', key);
    if (e.action === 'ship') return moveOrder(e.order_id, 'shipped', key);
    if (e.action === 'reply') {
      const m = messages.find((x) => x.id === e.message_id) || (await api.get('/admin/contact-messages', { per_page: 100 })).items.find((x) => x.id === e.message_id);
      return m ? setReplyTo(m) : toast('That message was already answered', { error: true });
    }
    if (e.action === 'restock') {
      const p = await api.get(`/admin/products/${e.product_id}`);
      return restock(p, key);
    }
  };

  const week = (stats?.week || []).map((d) => ({
    day: new Date(`${d.date}T00:00:00Z`).toLocaleDateString('en-US', { weekday: 'short', timeZone: 'UTC' }),
    revenue: d.revenue,
  }));
  const today = week.at(-1)?.revenue || 0;

  return (
    <>
      <PageTitle
        title={`${greeting()}, ${user?.full_name?.split(' ')[0] || 'Admin'}`}
        sub={`${new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })} · updates every 20 seconds`}
      >
        <form onSubmit={(ev) => { ev.preventDefault(); navigate(`/orders?q=${encodeURIComponent(q.trim())}`); }}>
          <SearchBox value={q} onChange={setQ} placeholder="Find an order or customer" />
        </form>
        <Button icon="add" onClick={() => navigate('/products/new')}>Add product</Button>
      </PageTitle>

      {(statsError || error) && <ErrorBox message={statsError || error} onRetry={() => { refresh(); load(); }} />}

      <div className="flex gap-4">
        <Kpi icon="payments" tint="bg-green-100 text-green-700" value={stats ? moneyShort(stats.revenue) : '…'} label="Revenue (paid)" sub={today ? `+${moneyShort(today)} today` : null} testid="kpi-revenue" />
        <Kpi icon="receipt_long" tint="bg-amber-100 text-amber-700" value={stats?.orders_to_handle ?? '…'} label="Orders to handle" testid="kpi-orders" />
        <Kpi icon="inventory_2" tint="bg-red-100 text-red-700" value={stats?.low_stock ?? '…'} label="Low stock (3 or less)" testid="kpi-low" />
        <Kpi icon="forum" tint="bg-cyan-100 text-cyan-700" value={stats?.open_messages ?? '…'} label="Open messages" testid="kpi-messages" />
      </div>

      <div className="flex min-h-0 flex-1 gap-4">
        <div className="flex min-w-0 flex-[1.45] flex-col gap-4">
          <Card className="px-5 py-[18px]">
            <div className="flex items-center">
              <div className="flex-1">
                <div className="text-base font-bold">Revenue · last 7 days</div>
                <div className="text-[12.5px] text-muted">{stats ? `${money(stats.week_revenue)} this week` : ' '}</div>
              </div>
              <Chip>7 days</Chip>
            </div>
            <div className="h-[180px]" data-testid="revenue-chart">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={week} margin={{ top: 22, right: 4, left: 4, bottom: 0 }}>
                  <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{ fontSize: 11.5, fill: dark ? '#94A3B8' : '#64748B' }} />
                  <Bar dataKey="revenue" radius={[9, 9, 4, 4]} maxBarSize={36} animationDuration={700}>
                    {week.map((_, i) => <Cell key={i} fill={dark ? '#38BDF8' : '#0284C7'} fillOpacity={i === week.length - 1 ? 1 : dark ? 0.3 : 0.35} />)}
                    <LabelList dataKey="revenue" position="top" formatter={(v) => `$${Math.round(v)}`} style={{ fontSize: 11, fontWeight: 700, fill: dark ? '#E2E8F0' : '#0F172A' }} />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>

          <Card className="flex-1 px-2 py-3.5">
            <div className="flex items-center px-3 pb-1.5">
              <div className="flex-1 text-base font-bold">Orders to handle</div>
              <button type="button" onClick={() => navigate('/orders')} className="text-[13px] font-bold text-brand">See all orders</button>
            </div>
            {orders === null ? <div className="p-8 text-center text-muted">Loading…</div> : orders.length === 0 ? (
              <Empty icon="task_alt" text="Nothing to handle right now." />
            ) : (
              <table className="data">
                <thead><tr><th>Order</th><th>Customer</th><th>Items</th><th>Total</th><th>Payment</th><th>Status</th><th /></tr></thead>
                <tbody>
                  {orders.map((o) => {
                    const step = nextStep(o);
                    return (
                      <tr key={o.id} className="clickable rise" onClick={() => setOpenOrder(o.id)} data-testid={`order-row-${o.id}`}>
                        <td className="font-bold text-brand">{o.order_number}</td>
                        <td>{o.customer.full_name}</td>
                        <td><Photo src={o.image_url} size={32} /></td>
                        <td className="font-bold">{money(o.total)}</td>
                        <td className="text-muted">{paymentText(o)}</td>
                        <td><StatusChip status={o.status} /></td>
                        <td className="text-right" onClick={(ev) => ev.stopPropagation()}>
                          {step ? (
                            <Button small loading={busy === `row-${o.id}`} onClick={() => moveOrder(o.id, step, `row-${o.id}`)} data-testid={`order-step-${o.id}`}>
                              {STEP_LABEL[step]}
                            </Button>
                          ) : <Chip className="bg-amber-100 text-amber-700">Waiting for {paymentName(o)}</Chip>}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </Card>
        </div>

        <div className="flex min-w-0 flex-1 flex-col gap-4">
          <Card className="px-5 py-4">
            <div className="flex items-center gap-2">
              <div className="flex-1 text-base font-bold">Live activity</div>
              <Chip className="bg-green-100 text-green-700"><span className="h-2 w-2 animate-pulse rounded-full bg-green-600" />Live</Chip>
            </div>
            {events === null ? <div className="p-6 text-center text-muted">Loading…</div> : events.length === 0 ? <Empty icon="bolt" text="Nothing has happened yet." /> : (
              <div>
                {events.map((e) => {
                  const [icon, tint] = KIND[e.kind] || KIND.order;
                  return (
                    <div key={e.id} className={`flex items-center gap-3 border-b border-line/60 py-[11px] last:border-0 ${fresh.has(e.id) ? 'arrive -mx-2.5 rounded-xl px-2.5' : ''}`} data-testid={`event-${e.id}`}>
                      <div className={`grid h-9 w-9 shrink-0 place-items-center rounded-xl ${tint}`}><Icon name={icon} size={18} /></div>
                      <div className="min-w-0 flex-1">
                        <div className="text-[13.5px] font-bold">{e.title}</div>
                        <div className="truncate text-[12.5px] text-muted">{e.message}</div>
                      </div>
                      <div className="whitespace-nowrap text-[11.5px] text-muted">{timeAgo(e.at)}</div>
                      {e.action && (
                        <Button small loading={busy === `act-${e.id}`} onClick={() => act(e)} data-testid={`event-action-${e.id}`}>{ACTION_LABEL[e.action]}</Button>
                      )}
                      {!e.action && e.kind === 'message' && <Chip className="bg-green-100 text-green-700"><Icon name="check" size={13} />Answered</Chip>}
                    </div>
                  );
                })}
              </div>
            )}
          </Card>

          <Card className="flex-1 px-5 py-3.5">
            <div className="flex items-center">
              <div className="flex-1 text-base font-bold">Low stock</div>
              <button type="button" onClick={() => navigate('/products?filter=low')} className="text-[13px] font-bold text-brand">All products</button>
            </div>
            {low === null ? <div className="p-6 text-center text-muted">Loading…</div> : low.length === 0 ? <Empty icon="inventory" text="Every product has more than 3 in stock." /> : (
              low.map((p) => (
                <div key={p.id} className="flex items-center gap-3 py-2" data-testid={`low-${p.id}`}>
                  <Photo src={p.image_url} />
                  <div className="min-w-0 flex-1 truncate text-[13px] font-semibold">{p.name}</div>
                  <Chip className={p.stock === 0 ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'}>{p.stock === 0 ? 'Sold out' : `${p.stock} left`}</Chip>
                  <Button small variant="ghost" loading={busy === `low-${p.id}`} onClick={() => restock(p, `low-${p.id}`)} data-testid={`restock-${p.id}`}>+5</Button>
                </div>
              ))
            )}
          </Card>
        </div>
      </div>

      <OrderDrawer orderId={openOrder} onClose={() => setOpenOrder(null)} onChanged={after} />
      <ReplyDrawer message={replyTo} onClose={() => setReplyTo(null)} onSent={after} />
    </>
  );
}
