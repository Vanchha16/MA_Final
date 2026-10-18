import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { STEP_DONE, STEP_LABEL, dateTime, money, nextStep, paymentText } from '../lib/format';
import { useToast } from './toast';
import { Button, ConfirmDialog, Drawer, ErrorBox, Icon, Photo, Spinner, StatusChip } from './ui';

/** One order: items, customer, delivery, totals, and the next step / Cancel. */
export default function OrderDrawer({ orderId, onClose, onChanged }) {
  const toast = useToast();
  const [order, setOrder] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const [askCancel, setAskCancel] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      setOrder(await api.get(`/admin/orders/${orderId}`));
    } catch (e) {
      setError(e.message);
    }
  }, [orderId]);

  useEffect(() => {
    setOrder(null);
    if (orderId) load();
  }, [orderId, load]);

  const move = async (status) => {
    setBusy(status);
    try {
      const updated = await api.put(`/admin/orders/${orderId}/status`, { status });
      setOrder(updated);
      toast(`${updated.order_number} ${STEP_DONE[status]} · the customer was told`);
      onChanged?.(updated);
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(null);
      setAskCancel(false);
    }
  };

  const next = order && nextStep(order);
  const canCancel = order?.next_statuses?.includes('cancelled');
  return (
    <>
      <Drawer
        open={!!orderId}
        onClose={onClose}
        width={520}
        title={order ? order.order_number : 'Order'}
        footer={
          order && (next || canCancel) ? (
            <div className="flex gap-3">
              {canCancel && <Button variant="dangerOutline" className="flex-1" onClick={() => setAskCancel(true)}>Cancel order</Button>}
              {next && (
                <Button className="flex-[2]" icon={next === 'shipped' ? 'local_shipping' : 'check'} loading={busy === next} onClick={() => move(next)} data-testid="drawer-next">
                  {next === 'confirmed' ? 'Confirm order' : next === 'shipped' ? 'Mark shipped' : 'Mark delivered'}
                </Button>
              )}
            </div>
          ) : null
        }
      >
        {error && <ErrorBox message={error} onRetry={load} />}
        {!order && !error && <div className="grid place-items-center py-16 text-brand"><Spinner /></div>}
        {order && (
          <div className="flex flex-col gap-5 text-[13.5px]">
            <div className="flex items-center gap-3">
              <StatusChip status={order.status} />
              <span className="text-muted">{dateTime(order.created_at)}</span>
              <span className="ml-auto text-xl font-extrabold text-brand">{money(order.total)}</span>
            </div>
            <section>
              <h3 className="mb-2 text-[11px] font-bold tracking-wider text-muted">CUSTOMER</h3>
              <div className="flex items-center gap-3 rounded-2xl bg-slate-50 p-3.5">
                <div className="grid h-10 w-10 place-items-center rounded-full bg-violet-100 font-bold text-violet-700">{order.customer.full_name[0]}</div>
                <div className="flex-1">
                  <div className="font-bold">{order.customer.full_name}</div>
                  <div className="text-muted">{order.customer.email}</div>
                </div>
                {order.customer.phone && (
                  <a href={`tel:${order.customer.phone}`} className="flex items-center gap-1 rounded-full bg-green-100 px-3 py-1.5 font-bold text-green-700">
                    <Icon name="call" size={16} />{order.customer.phone}
                  </a>
                )}
              </div>
              <div className="mt-2 flex gap-2 px-1 text-muted">
                <Icon name={order.delivery_method === 'pickup' ? 'storefront' : 'location_on'} size={18} />
                <span>{order.shipping?.address}{order.note ? ` · Note: ${order.note}` : ''}</span>
              </div>
            </section>
            <section>
              <h3 className="mb-2 text-[11px] font-bold tracking-wider text-muted">{order.item_count} ITEM{order.item_count === 1 ? '' : 'S'}</h3>
              <div className="flex flex-col gap-2.5">
                {order.items.map((i, n) => (
                  <div key={n} className="flex items-center gap-3">
                    <Photo src={i.image_url} size={48} />
                    <div className="flex-1">
                      <div className="font-semibold">{i.product_name}</div>
                      <div className="text-muted">{money(i.unit_price)} × {i.quantity}</div>
                    </div>
                    <div className="font-bold">{money(i.subtotal)}</div>
                  </div>
                ))}
              </div>
            </section>
            <section className="rounded-2xl bg-slate-50 p-3.5">
              {[
                ['Subtotal', money(order.subtotal)],
                order.discount > 0 ? [`Promo ${order.coupon_code || ''}`, `-${money(order.discount)}`] : null,
                [order.delivery_method === 'pickup' ? 'Store pickup' : 'Delivery', order.shipping_fee ? money(order.shipping_fee) : 'Free'],
                ['Payment', paymentText(order)],
              ].filter(Boolean).map(([k, v]) => (
                <div key={k} className="flex justify-between py-0.5"><span className="text-muted">{k}</span><span className="font-semibold">{v}</span></div>
              ))}
              <div className="mt-2 flex justify-between border-t border-line pt-2 text-[15px] font-bold"><span>Total</span><span className="text-brand">{money(order.total)}</span></div>
            </section>
            {!next && !canCancel && <div className="text-center text-muted">This order is finished.</div>}
          </div>
        )}
      </Drawer>
      <ConfirmDialog
        open={askCancel}
        title="Cancel this order?"
        message="The customer is told, and the items go back on sale."
        confirmLabel="Cancel order"
        busy={busy === 'cancelled'}
        onCancel={() => setAskCancel(false)}
        onConfirm={() => move('cancelled')}
      />
    </>
  );
}

export { STEP_LABEL };
