import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from '../api';
import { useAuth } from '../auth';
import { useToast } from '../components/toast';
import { Button, Card, Chip, ConfirmDialog, Drawer, Empty, ErrorBox, Field, FilterChips, PageTitle, SearchBox } from '../components/ui';
import { timeAgo } from '../lib/format';

const FILTERS = [
  ['all', 'All', () => true],
  ['admin', 'Admins', (s) => s.role === 'admin'],
  ['staff', 'Staff', (s) => s.role === 'staff'],
  ['disabled', 'Disabled', (s) => !s.is_active],
];
const BLANK = { full_name: '', email: '', phone: '', role: 'staff', password: '' };

const RoleChip = ({ role }) => (role === 'admin'
  ? <Chip className="bg-violet-100 text-violet-700">Admin</Chip>
  : <Chip className="bg-cyan-100 text-cyan-700">Staff</Chip>);

const Avatar = ({ person, big = false }) => (
  <div className={`grid shrink-0 place-items-center rounded-full font-bold ${big ? 'h-16 w-16 text-2xl' : 'h-9 w-9'} ${person.is_active === false ? 'bg-red-100 text-red-700' : 'bg-brand-tint text-brand'}`}>
    {(person.full_name || '?')[0]}
  </div>
);

/** Staff and admin accounts (option A: table + side drawer). Admins only. */
export default function Staff() {
  const toast = useToast();
  const { user: me } = useAuth();
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState(null); // {} = new
  const [form, setForm] = useState(BLANK);
  const [errors, setErrors] = useState({});
  const [resetting, setResetting] = useState(false);
  const [saving, setSaving] = useState(false);
  const [askDisable, setAskDisable] = useState(false);

  const load = useCallback(async () => {
    try {
      setItems(await api.get('/admin/staff'));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const shown = useMemo(() => {
    const test = FILTERS.find((f) => f[0] === filter)[2];
    const needle = q.trim().toLowerCase();
    return (items || []).filter((s) => test(s) && (!needle || `${s.full_name} ${s.email} ${s.phone || ''}`.toLowerCase().includes(needle)));
  }, [items, filter, q]);

  const open = (s) => {
    setEditing(s);
    setErrors({});
    setResetting(false);
    setForm(s.id ? { ...BLANK, full_name: s.full_name, phone: s.phone || '', role: s.role } : BLANK);
  };
  const isMe = editing?.id === me?.id;
  const set = (name) => (e) => setForm({ ...form, [name]: e.target.value });

  const save = async () => {
    setSaving(true);
    try {
      if (editing.id) {
        const body = { full_name: form.full_name, phone: form.phone || null };
        if (!isMe) body.role = form.role;
        if (resetting) body.password = form.password;
        await api.put(`/admin/staff/${editing.id}`, body);
        toast(resetting ? `Saved. Give ${form.full_name} the new password.` : `${form.full_name} saved`, { icon: 'badge' });
      } else {
        await api.post('/admin/staff', { ...form, phone: form.phone || null });
        toast(`${form.full_name} can sign in now`, { icon: 'person_add' });
      }
      setEditing(null);
      load();
    } catch (e) {
      if (e.errors) setErrors(e.errors);
      else toast(e.message, { error: true });
    } finally {
      setSaving(false);
    }
  };

  const setActive = async (active) => {
    setSaving(true);
    try {
      const s = await api.put(`/admin/staff/${editing.id}`, { is_active: active });
      setEditing(s);
      toast(active ? `${s.full_name} can sign in again` : `${s.full_name} is disabled and signed out`, { icon: active ? 'check_circle' : 'block' });
      load();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setSaving(false);
      setAskDisable(false);
    }
  };

  const RoleButton = ({ value, label }) => (
    <button
      type="button"
      disabled={isMe}
      onClick={() => setForm({ ...form, role: value })}
      data-testid={`staff-role-${value}`}
      className={`rounded-[14px] py-2.5 text-[13.5px] font-bold transition-colors disabled:cursor-not-allowed ${form.role === value ? 'bg-brand text-brand-on' : 'bg-soft text-ink/70 hover:bg-line/60'}`}
    >
      {label}
    </button>
  );

  return (
    <>
      <PageTitle title="Staff" sub="Who can sign in to the shop admin. Staff run orders and products; only admins manage staff and promo codes.">
        <Button icon="person_add" onClick={() => open({})} data-testid="staff-new">Add staff</Button>
      </PageTitle>
      <div className="flex flex-wrap items-center gap-3">
        <FilterChips items={FILTERS.map(([k, l, t]) => [k, l, items ? items.filter(t).length : null])} value={filter} onChange={setFilter} />
        <div className="flex-1" />
        <SearchBox value={q} onChange={setQ} placeholder="Name, email or phone" className="w-[280px]" />
      </div>
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {items === null ? <div className="p-10 text-center text-muted">Loading…</div> : shown.length === 0 ? <Empty icon="badge" text="Nobody here." /> : (
          <table className="data">
            <thead><tr><th>Member</th><th>Phone</th><th>Role</th><th>Last login</th><th>Status</th></tr></thead>
            <tbody>
              {shown.map((s) => (
                <tr key={s.id} className="clickable" onClick={() => open(s)} data-testid={`staff-${s.id}`}>
                  <td>
                    <div className="flex items-center gap-3">
                      <Avatar person={s} />
                      <div>
                        <div className="font-semibold">{s.full_name}{s.id === me?.id && <span className="ml-1 text-[12px] font-medium text-muted">(you)</span>}</div>
                        <div className="text-[12px] text-muted">{s.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="text-muted">{s.phone || '—'}</td>
                  <td><RoleChip role={s.role} /></td>
                  <td className="text-muted">{s.last_login_at ? timeAgo(s.last_login_at) : 'Never'}</td>
                  <td>{s.is_active ? <Chip className="bg-green-100 text-green-700">Active</Chip> : <Chip className="bg-red-100 text-red-700">Disabled</Chip>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Drawer
        open={editing !== null}
        onClose={() => setEditing(null)}
        width={420}
        title={editing?.id ? 'Staff member' : 'Add staff'}
        footer={editing && (
          <div className="flex gap-2">
            {editing.id && !isMe && (editing.is_active
              ? <Button variant="danger" className="flex-1" icon="block" onClick={() => setAskDisable(true)} data-testid="staff-disable">Disable</Button>
              : <Button variant="success" className="flex-1" icon="check_circle" loading={saving} onClick={() => setActive(true)} data-testid="staff-enable">Enable</Button>)}
            <Button className="flex-1" icon="check" loading={saving} onClick={save} data-testid="staff-save">{editing.id ? 'Save' : 'Add staff'}</Button>
          </div>
        )}
      >
        {editing && (
          <div className="flex flex-col gap-4 text-[13.5px]">
            {editing.id && (
              <div className="flex flex-col items-center text-center">
                <Avatar person={editing} big />
                <div className="mt-2 text-lg font-bold">{editing.full_name}</div>
                <div className="text-muted">{editing.email} · {editing.last_login_at ? `Last login ${timeAgo(editing.last_login_at)}` : 'Never signed in'}</div>
                {!editing.is_active && <div className="mt-2"><Chip className="bg-red-100 text-red-700">Disabled</Chip></div>}
              </div>
            )}
            <Field label="Name" maxLength={100} value={form.full_name} onChange={set('full_name')} error={errors.full_name} data-testid="staff-name" />
            {!editing.id && <Field label="Email" type="email" maxLength={150} value={form.email} onChange={set('email')} error={errors.email} data-testid="staff-email" />}
            <Field label="Phone (optional)" maxLength={30} value={form.phone} onChange={set('phone')} error={errors.phone} placeholder="012 345 678" />
            <div>
              <span className="mb-1 block text-[12.5px] font-semibold text-muted">Role</span>
              <div className="grid grid-cols-2 gap-2"><RoleButton value="staff" label="Staff" /><RoleButton value="admin" label="Admin" /></div>
              <span className={`mt-1 block text-[12px] ${errors.role ? 'font-semibold text-red-600' : 'text-muted'}`}>
                {errors.role || (isMe ? 'You can\'t change your own role.' : form.role === 'admin' ? 'Everything, including staff and promo codes.' : 'Orders, products, categories, messages and reviews. Customers view only.')}
              </span>
            </div>
            {!editing.id || resetting
              ? <Field label={editing.id ? 'New password' : 'Password'} type="text" autoComplete="off" maxLength={72} value={form.password} onChange={set('password')}
                  error={errors.password} placeholder="At least 8 characters" data-testid="staff-password" />
              : <Button variant="outline" icon="key" onClick={() => setResetting(true)} data-testid="staff-reset">Reset password</Button>}
            {(!editing.id || resetting) && <span className="-mt-2 text-[12px] text-muted">Give them this password. They can change it in Profile.</span>}
          </div>
        )}
      </Drawer>
      <ConfirmDialog
        open={askDisable}
        title={`Disable ${editing?.full_name}?`}
        message="They are signed out at once and cannot sign in until you enable them again."
        confirmLabel="Disable"
        busy={saving}
        onCancel={() => setAskDisable(false)}
        onConfirm={() => setActive(false)}
      />
    </>
  );
}
