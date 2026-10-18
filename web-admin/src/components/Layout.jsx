import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth';
import { useStats } from '../stats';
import { Icon } from './ui';

const LOGO = '/static/admin/logo.png';

/** Sidebar layout (picked from the web admin previews, A). */
export default function Layout() {
  const { user, logout } = useAuth();
  const { stats } = useStats();
  const nav = [
    ['/', 'space_dashboard', 'Dashboard'],
    ['/orders', 'receipt_long', 'Orders', stats?.orders_to_handle],
    ['/products', 'inventory_2', 'Products'],
    ['/categories', 'category', 'Categories'],
    ['/customers', 'group', 'Customers'],
    ['/messages', 'forum', 'Messages', stats?.open_messages],
    ['/reviews', 'star', 'Reviews'],
    ['/coupons', 'sell', 'Coupons'],
  ];
  return (
    <div className="flex min-h-screen">
      <aside className="fixed inset-y-0 left-0 flex w-[240px] flex-col bg-white px-4 py-[22px] shadow-[2px_0_14px_rgba(15,23,42,.04)]">
        <div className="mx-1.5 mb-6 flex items-center gap-2.5">
          <img src={LOGO} alt="" className="h-[38px] w-[38px]" />
          <div>
            <div className="text-[15px] font-bold">Anime World</div>
            <div className="text-[11.5px] text-muted">Shop admin</div>
          </div>
        </div>
        <nav className="flex flex-col gap-1">
          {nav.map(([to, icon, label, badge]) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-xl px-3.5 py-[11px] text-[14px] transition-colors ${
                  isActive ? 'bg-brand-tint font-bold text-brand' : 'font-medium text-slate-700 hover:bg-slate-50'
                }`
              }
            >
              <Icon name={icon} />
              <span className="flex-1">{label}</span>
              {badge > 0 && <span className="rounded-full bg-coral px-2 py-0.5 text-[11.5px] font-bold text-white" data-testid={`badge-${label}`}>{badge}</span>}
            </NavLink>
          ))}
        </nav>
        <div className="mt-auto flex items-center gap-2.5 rounded-card bg-white p-3.5 shadow-card">
          <div className="grid h-9 w-9 place-items-center rounded-full bg-brand-tint font-extrabold text-brand">{user?.full_name?.[0] || 'A'}</div>
          <div className="min-w-0 flex-1">
            <div className="truncate text-[13px] font-bold">{user?.full_name}</div>
            <div className="truncate text-[11.5px] text-muted">{user?.email}</div>
          </div>
          <button type="button" onClick={() => logout()} title="Log out" className="text-red-600 hover:text-red-700" aria-label="Log out">
            <Icon name="logout" />
          </button>
        </div>
      </aside>
      <main className="ml-[240px] flex min-w-0 flex-1 flex-col gap-[18px] px-7 py-6">
        <Outlet />
      </main>
    </div>
  );
}
