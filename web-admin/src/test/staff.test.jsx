import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { vi } from 'vitest';

const state = {};
const auth = { user: null, isAdmin: true };
function reset() {
  Object.assign(state, {
    staff: [
      { id: 1, full_name: 'Admin', email: 'admin@shop.com', phone: null, role: 'admin', is_active: true, last_login_at: null },
      { id: 2, full_name: 'Shop Staff', email: 'staff@shop.com', phone: '012345678', role: 'staff', is_active: true, last_login_at: null },
    ],
    calls: [],
  });
  Object.assign(auth, { user: { id: 1, full_name: 'Admin', email: 'admin@shop.com', role: 'admin' }, isAdmin: true });
}

vi.mock('../api', () => ({
  api: {
    get: vi.fn(async (path) => {
      if (path === '/admin/staff') return state.staff.map((s) => ({ ...s }));
      if (path === '/admin/stats') return { orders_to_handle: 0, open_messages: 0 };
      throw new Error(`unexpected GET ${path}`);
    }),
    post: vi.fn(async (path, body) => {
      state.calls.push(['POST', path, body]);
      const s = { id: 3, ...body, is_active: true, last_login_at: null };
      state.staff.push(s);
      return s;
    }),
    put: vi.fn(async (path, body) => {
      state.calls.push(['PUT', path, body]);
      const s = state.staff.find((x) => path === `/admin/staff/${x.id}`);
      Object.assign(s, body);
      return { ...s };
    }),
  },
  ApiError: class extends Error {},
}));

vi.mock('../auth', () => ({ useAuth: () => ({ ...auth, logout: vi.fn() }) }));

const { default: Staff } = await import('../pages/Staff');
const { default: Layout } = await import('../components/Layout');
const { StatsProvider } = await import('../stats');
const { ToastProvider } = await import('../components/toast');

const renderWith = (ui) => render(<MemoryRouter><ToastProvider><StatsProvider>{ui}</StatsProvider></ToastProvider></MemoryRouter>);

beforeEach(reset);

test('the owner adds a staff member', async () => {
  const user = userEvent.setup();
  renderWith(<Staff />);
  expect(await screen.findByTestId('staff-2')).toHaveTextContent('Shop Staff');
  expect(screen.getByTestId('staff-1')).toHaveTextContent('(you)');

  await user.click(screen.getByTestId('staff-new'));
  await user.type(screen.getByTestId('staff-name'), 'Sokha Chan');
  await user.type(screen.getByTestId('staff-email'), 'sokha@shop.com');
  await user.type(screen.getByTestId('staff-password'), 'welcome123');
  await user.click(screen.getByTestId('staff-save'));
  await waitFor(() => expect(state.calls).toContainEqual(['POST', '/admin/staff',
    { full_name: 'Sokha Chan', email: 'sokha@shop.com', phone: null, role: 'staff', password: 'welcome123' }]));
  expect(await screen.findByTestId('staff-3')).toHaveTextContent('Sokha Chan');
});

test('promote, reset password and disable from the drawer; not for yourself', async () => {
  const user = userEvent.setup();
  renderWith(<Staff />);
  await user.click(await screen.findByTestId('staff-2'));
  await user.click(screen.getByTestId('staff-role-admin'));
  await user.click(screen.getByTestId('staff-reset'));
  await user.type(screen.getByTestId('staff-password'), 'newpass123');
  await user.click(screen.getByTestId('staff-save'));
  await waitFor(() => expect(state.calls).toContainEqual(['PUT', '/admin/staff/2',
    { full_name: 'Shop Staff', phone: '012345678', role: 'admin', password: 'newpass123' }]));

  await user.click(await screen.findByTestId('staff-2'));
  await user.click(screen.getByTestId('staff-disable'));
  await user.click(within(screen.getByRole('alertdialog')).getByText('Disable'));
  await waitFor(() => expect(state.calls).toContainEqual(['PUT', '/admin/staff/2', { is_active: false }]));
  expect(await screen.findByTestId('staff-enable')).toBeInTheDocument();

  await user.click(screen.getByLabelText('Close'));
  await user.click(screen.getByTestId('staff-1'));
  expect(screen.queryByTestId('staff-disable')).toBeNull();
  expect(screen.getByTestId('staff-role-staff')).toBeDisabled();
});

test('a staff account does not see Coupons or Staff in the menu', async () => {
  auth.user = { id: 2, full_name: 'Shop Staff', email: 'staff@shop.com', role: 'staff' };
  auth.isAdmin = false;
  renderWith(<Layout />);
  expect(screen.getByText('Orders')).toBeInTheDocument();
  expect(screen.queryByText('Coupons')).toBeNull();
  expect(screen.queryByText('Staff')).toBeNull();
  expect(screen.getByText('Staff · staff@shop.com')).toBeInTheDocument();
});
