import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { STEP_DONE, STEP_LABEL, cancelledByText, dateTime, money, nextStep, paymentName, paymentText } from '../lib/format';
import { useToast } from './toast';
import { Button, ConfirmDialog, Drawer, ErrorBox, Icon, Photo, Spinner, StatusChip } from './ui';

/** One order: items, customer, delivery, totals, and the next step / Cancel.
 *  A cancelled paid order shows the refund to send and Mark refunded. */
export default function OrderDrawer({ orderId, onClose, onChanged }) {
  const toast = useToast();
  const [order, setOrder] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const [askCancel, setAskCancel] = useState(false);
  const [askRefund, setAskRefund] = useState(false);

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

  const refund = async () => {
    setBusy('refund');
    try {
      const updated = await api.post(`/admin/orders/${orderId}/refund`);
      setOrder(updated);
      toast(`${updated.order_number} marked refunded · the customer was told`, { icon: 'currency_exchange' });
      onChanged?.(updated);
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setBusy(null);
      setAskRefund(false);
    }
  };

  const next = order && nextStep(order);
  const refundPending = order?.payment_status === 'refund_pending';
  const canCancel = order?.next_statuses?.includes('cancelled');
  return (
    <>
      <Drawer
        open={!!orderId}
        onClose={onClose}
        width={520}
        title={order ? order.order_number : 'Order'}
        footer={
          refundPending ? (
            <Button className="w-full" icon="currency_exchange" loading={busy === 'refund'} onClick={() => setAskRefund(true)} data-testid="drawer-refund">
              Mark refunded
            </Button>
          ) : order && (next || canCancel) ? (
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
            {order.status === 'cancelled' && (
              <section className={`rounded-2xl p-3.5 ${refundPending ? 'bg-amber-100' : order.payment_status === 'refunded' ? 'bg-green-100' : 'bg-soft'}`} data-testid="drawer-cancel-info">
                <div className="font-bold">{cancelledByText(order)}{order.cancel_reason ? ` · ${order.cancel_reason}` : ''}</div>
                {refundPending && <div className="mt-1 text-amber-700">Paid by {paymentName(order)}: send {money(order.total)} back to the customer, then press Mark refunded.</div>}
                {order.payment_status === 'refunded' && <div className="mt-1 text-green-700">Refunded {money(order.total)}{order.refunded_at ? ` on ${dateTime(order.refunded_at)}` : ''}.</div>}
              </section>
            )}
            <section>
              <h3 className="mb-2 text-[11px] font-bold tracking-wider text-muted">CUSTOMER</h3>
              <div className="flex items-center gap-3 rounded-2xl bg-soft p-3.5">
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
            <section className="rounded-2xl bg-soft p-3.5">
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
            {!next && !canCancel && !refundPending && <div className="text-center text-muted">This order is finished.</div>}
          </div>
        )}
      </Drawer>
      <ConfirmDialog
        open={askCancel}
        title="Cancel this order?"
        message={order?.payment_status === 'paid' && order?.payment_method !== 'cod'
          ? `The customer is told, and the items go back on sale. It is paid, so you will need to send ${money(order.total)} back.`
          : 'The customer is told, and the items go back on sale.'}
        confirmLabel="Cancel order"
        busy={busy === 'cancelled'}
        onCancel={() => setAskCancel(false)}
        onConfirm={() => move('cancelled')}
      />
      <ConfirmDialog
        open={askRefund}
        title="Mark as refunded?"
        message={order ? `Only after you have sent ${money(order.total)} back to ${order.customer.full_name}. They get a notification.` : ''}
        confirmLabel="Mark refunded"
        danger={false}
        busy={busy === 'refund'}
        onCancel={() => setAskRefund(false)}
        onConfirm={refund}
      />
    </>
  );
}

export { STEP_LABEL };
