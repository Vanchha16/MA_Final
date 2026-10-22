// Money, dates and order statuses, the same way the mobile app shows them.

export const money = (v) =>
  `$${Number(v || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export const moneyShort = (v) => `$${Math.round(Number(v || 0)).toLocaleString('en-US')}`;

/** The API sends UTC times, sometimes without the "Z". */
export const parseTime = (s) => (s ? new Date(/[zZ]|[+-]\d\d:\d\d$/.test(s) ? s : `${s}Z`) : null);

export function timeAgo(s, now = Date.now()) {
  const d = parseTime(s);
  if (!d) return '';
  const sec = Math.max(0, Math.round((now - d.getTime()) / 1000));
  if (sec < 45) return 'just now';
  const min = Math.round(sec / 60);
  if (min < 60) return `${min} min`;
  const h = Math.round(min / 60);
  if (h < 24) return `${h} h`;
  const days = Math.round(h / 24);
  return days < 30 ? `${days} d` : d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

export const dateTime = (s) =>
  parseTime(s)?.toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) ?? '';

export const STATUS = {
  pending: { label: 'Pending', cls: 'bg-amber-100 text-amber-700' },
  confirmed: { label: 'Confirmed', cls: 'bg-cyan-100 text-cyan-700' },
  shipped: { label: 'Shipped', cls: 'bg-brand-tint text-brand' },
  delivered: { label: 'Delivered', cls: 'bg-green-100 text-green-700' },
  cancelled: { label: 'Cancelled', cls: 'bg-slate-100 text-slate-500' },
};

/** Button text for moving an order to [status]. */
export const STEP_LABEL = { confirmed: 'Confirm', shipped: 'Ship', delivered: 'Delivered', cancelled: 'Cancel' };
export const STEP_DONE = { confirmed: 'confirmed', shipped: 'marked shipped', delivered: 'marked delivered', cancelled: 'cancelled' };

/** The forward step of an order (not Cancel), or null. */
export const nextStep = (order) => (order.next_statuses || []).find((s) => s !== 'cancelled') || null;

const PAY_NAMES = { khqr: 'KHQR', aba: 'ABA PayWay', cod: 'Cash' };

export const paymentName = (o) => PAY_NAMES[o.payment_method] || 'Cash';

export const paymentText = (o) =>
  o.payment_status === 'refund_pending' ? `${paymentName(o)} · refund to send`
    : o.payment_status === 'refunded' ? `${paymentName(o)} · refunded`
      : `${paymentName(o)}${o.payment_status === 'paid' ? ' paid' : ''}`;

/** Who cancelled an order, in words. */
export const cancelledByText = (o) =>
  ({ customer: 'Cancelled by the customer', shop: 'Cancelled by the shop', system: 'Not paid in time' })[o.cancelled_by] || 'Cancelled';

export const greeting = (date = new Date()) => {
  const h = date.getHours();
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
};
