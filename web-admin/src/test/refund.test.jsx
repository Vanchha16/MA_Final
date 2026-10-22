import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';

const order = {
  id: 6, order_number: 'AWS-20261020-00006', status: 'cancelled', payment_method: 'khqr', payment_status: 'refund_pending',
  cancelled_by: 'customer', cancel_reason: 'Changed my mind', refunded_at: null, total: 60, subtotal: 60, shipping_fee: 0, discount: 0,
  item_count: 2, items: [], created_at: '2026-10-20T08:00:00Z', delivery_method: 'standard', shipping: { address: '#24 St. 271' },
  customer: { full_name: 'Demo Customer', email: 'demo@shop.com', phone: '012345678' }, next_statuses: [],
};
const calls = [];

vi.mock('../api', () => ({
  api: {
    get: vi.fn(async () => ({ ...order })),
    post: vi.fn(async (path) => {
      calls.push(path);
      return { ...order, payment_status: 'refunded', refunded_at: '2026-10-21T09:00:00Z' };
    }),
  },
}));

const { default: OrderDrawer } = await import('../components/OrderDrawer');
const { ToastProvider } = await import('../components/toast');

test('a cancelled paid order shows the refund to send, and Mark refunded asks first', async () => {
  const user = userEvent.setup();
  const onChanged = vi.fn();
  render(<ToastProvider><OrderDrawer orderId={6} onClose={() => {}} onChanged={onChanged} /></ToastProvider>);

  const info = await screen.findByTestId('drawer-cancel-info');
  expect(info).toHaveTextContent('Cancelled by the customer · Changed my mind');
  expect(info).toHaveTextContent('send $60.00 back to the customer');

  await user.click(screen.getByTestId('drawer-refund'));
  const dialog = screen.getByRole('alertdialog');
  expect(dialog).toHaveTextContent('Only after you have sent $60.00 back to Demo Customer');
  await user.click(within(dialog).getByText('Mark refunded'));
  await waitFor(() => expect(calls).toEqual(['/admin/orders/6/refund']));
  expect(await screen.findByText(/Refunded \$60\.00/)).toBeInTheDocument();
  expect(screen.queryByTestId('drawer-refund')).toBeNull();
  expect(onChanged).toHaveBeenCalled();
});
