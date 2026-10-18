import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { vi } from 'vitest';

// A fake shop behind the API
const state = {};
function reset() {
  Object.assign(state, {
    stats: { revenue: 1053, week_revenue: 277, orders_to_handle: 4, low_stock: 5, open_messages: 2,
      week: ['20', '21', '22', '23', '24', '25', '26'].map((d, i) => ({ date: `2026-10-${d}`, revenue: [20, 40, 0, 60, 30, 40, 87][i] })) },
    orders: [
      { id: 12, order_number: 'AWS-20261016-00012', status: 'pending', payment_method: 'cod', payment_status: 'unpaid', total: 87, next_statuses: ['confirmed', 'cancelled'], customer: { full_name: 'Demo Customer' }, image_url: null },
      { id: 11, order_number: 'AWS-20261016-00011', status: 'confirmed', payment_method: 'khqr', payment_status: 'paid', total: 13, next_statuses: ['shipped', 'cancelled'], customer: { full_name: 'Sok Dara' }, image_url: null },
      { id: 9, order_number: 'AWS-20261014-00009', status: 'delivered', payment_method: 'cod', payment_status: 'paid', total: 139, next_statuses: [], customer: { full_name: 'Vuthy Rith' }, image_url: null },
    ],
    events: [
      { id: 'message-1', kind: 'message', title: 'New message', message: '"When will my Luffy arrive?"', at: '2026-10-16T08:00:00Z', action: 'reply', message_id: 1 },
      { id: 'stock-7', kind: 'sold_out', title: 'Sold out', message: 'Makima has 0 left', at: '2026-10-16T07:00:00Z', action: 'restock', product_id: 7 },
    ],
    low: [{ id: 7, name: 'F:NEX Makima 1/7', stock: 0, image_url: null }, { id: 8, name: 'Satoru Gojo 1/7', stock: 2, image_url: null }],
    calls: [],
  });
}

vi.mock('../api', () => ({
  api: {
    get: vi.fn(async (path) => {
      if (path === '/admin/stats') return state.stats;
      if (path === '/admin/orders') return { items: state.orders };
      if (path === '/admin/activity') return state.events;
      if (path === '/admin/products') return { items: state.low };
      if (path === '/admin/contact-messages') return { items: [{ id: 1, topic: 'order', message: 'When will my Luffy arrive?', status: 'open', customer: { full_name: 'Demo Customer' } }] };
      if (path.startsWith('/admin/products/')) return state.low.find((p) => `/admin/products/${p.id}` === path);
      throw new Error(`unexpected GET ${path}`);
    }),
    put: vi.fn(async (path, body) => {
      state.calls.push(['PUT', path, body]);
      if (path.endsWith('/status')) {
        const o = state.orders.find((x) => path === `/admin/orders/${x.id}/status`);
        o.status = body.status;
        o.next_statuses = body.status === 'confirmed' ? ['shipped', 'cancelled'] : [];
        return o;
      }
      const p = state.low.find((x) => path === `/admin/products/${x.id}`);
      p.stock = body.stock;
      return p;
    }),
    post: vi.fn(async (path, body) => {
      state.calls.push(['POST', path, body]);
      return {};
    }),
    del: vi.fn(),
  },
  ApiError: class extends Error {},
  setSignedOutHandler: vi.fn(),
  tokenStore: { get: () => 't', set: vi.fn() },
}));

vi.mock('../auth', () => ({ useAuth: () => ({ user: { full_name: 'Admin', email: 'admin@shop.com', role: 'admin' }, logout: vi.fn() }) }));

const { default: Dashboard } = await import('../pages/Dashboard');
const { default: Layout } = await import('../components/Layout');
const { StatsProvider } = await import('../stats');
const { ToastProvider } = await import('../components/toast');

function renderDashboard() {
  return render(
    <MemoryRouter>
      <ToastProvider>
        <StatsProvider>
          <Layout />
          <Dashboard />
        </StatsProvider>
      </ToastProvider>
    </MemoryRouter>,
  );
}

beforeEach(reset);

test('shows the numbers, badges, orders to handle, activity and low stock', async () => {
  renderDashboard();
  expect(await screen.findByTestId('kpi-revenue')).toHaveTextContent('$1,053');
  expect(screen.getByTestId('kpi-orders')).toHaveTextContent('4');
  expect(await screen.findByTestId('badge-Orders')).toHaveTextContent('4');
  expect(screen.getByTestId('badge-Messages')).toHaveTextContent('2');
  expect(await screen.findByTestId('order-row-12')).toBeInTheDocument();
  expect(screen.queryByTestId('order-row-9')).toBeNull(); // delivered: nothing to do
  expect(screen.getByTestId('event-action-message-1')).toHaveTextContent('Reply');
  expect(screen.getByTestId('low-7')).toHaveTextContent('Sold out');
});

test('Confirm moves the order on and says the customer was told', async () => {
  const user = userEvent.setup();
  renderDashboard();
  await user.click(await screen.findByTestId('order-step-12'));
  await waitFor(() => expect(state.calls).toContainEqual(['PUT', '/admin/orders/12/status', { status: 'confirmed' }]));
  expect(await screen.findByText(/confirmed · the customer was told/)).toBeInTheDocument();
});

test('+5 restocks a sold-out product', async () => {
  const user = userEvent.setup();
  renderDashboard();
  await user.click(await screen.findByTestId('restock-7'));
  await waitFor(() => expect(state.calls).toContainEqual(['PUT', '/admin/products/7', { stock: 5 }]));
  expect(await screen.findByText(/restocked · 5 in stock/)).toBeInTheDocument();
});

test('Reply opens the reply panel and sends the answer', async () => {
  const user = userEvent.setup();
  renderDashboard();
  await user.click(await screen.findByTestId('event-action-message-1'));
  const box = await screen.findByTestId('reply-text');
  await user.type(box, 'Tomorrow!');
  await user.click(screen.getByTestId('reply-send'));
  await waitFor(() => expect(state.calls).toContainEqual(['POST', '/admin/contact-messages/1/reply', { reply: 'Tomorrow!' }]));
  expect(await screen.findByText('Reply sent to Demo Customer')).toBeInTheDocument();
  expect(within(document.body).queryByTestId('reply-text')).toBeNull();
});
