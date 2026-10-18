import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Button, Card, Chip, ConfirmDialog, Drawer, Empty, ErrorBox, Field, Icon, PageTitle, Toggle } from '../components/ui';
import { money, parseTime } from '../lib/format';

const BLANK = { code: '', description: '', discount_type: 'percent', value: '', min_subtotal: '', max_discount: '', expires_at: '', is_active: true };

const offText = (c) => (c.discount_type === 'percent' ? `${c.value}% off${c.max_discount ? ` (up to ${money(c.max_discount)})` : ''}` : `${money(c.value)} off`);

/** Promo codes customers type in the cart. */
export default function Coupons() {
  const toast = useToast();
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(BLANK);
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(null);

  const load = useCallback(async () => {
    try {
      setItems(await api.get('/admin/coupons'));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const open = (c) => {
    setEditing(c);
    setErrors({});
    setForm(c.id ? {
      code: c.code, description: c.description, discount_type: c.discount_type, value: String(c.value),
      min_subtotal: c.min_subtotal ? String(c.min_subtotal) : '', max_discount: c.max_discount ? String(c.max_discount) : '',
      expires_at: c.expires_at ? c.expires_at.slice(0, 10) : '', is_active: c.is_active,
    } : BLANK);
  };

  const save = async () => {
    setSaving(true);
    try {
      const body = { ...form, min_subtotal: form.min_subtotal || 0, max_discount: form.max_discount || null, expires_at: form.expires_at || null };
      if (editing.id) await api.put(`/admin/coupons/${editing.id}`, body);
      else await api.post('/admin/coupons', body);
      toast(editing.id ? 'Coupon saved' : `${form.code.toUpperCase()} added`, { icon: 'sell' });
      setEditing(null);
      load();
    } catch (e) {
      setErrors(e.errors || { code: e.message });
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (c, on) => {
    try {
      await api.put(`/admin/coupons/${c.id}`, { is_active: on });
      toast(on ? `${c.code} is on` : `${c.code} is off`, { icon: 'sell' });
      load();
    } catch (e) {
      toast(e.message, { error: true });
    }
  };

  const remove = async () => {
    try {
      await api.del(`/admin/coupons/${deleting.id}`);
      toast(`${deleting.code} deleted`);
      load();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setDeleting(null);
    }
  };

  const num = (name) => ({ value: form[name], inputMode: 'decimal', maxLength: 10, error: errors[name], onChange: (e) => setForm({ ...form, [name]: e.target.value.replace(/[^0-9.]/g, '') }) });
  const now = Date.now();
  return (
    <>
      <PageTitle title="Coupons" sub="Promo codes customers can use in the cart.">
        <Button icon="add" onClick={() => open({})} data-testid="coupon-new">New coupon</Button>
      </PageTitle>
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {items === null ? <div className="p-10 text-center text-muted">Loading…</div> : items.length === 0 ? <Empty icon="sell" text="No promo codes yet." /> : (
          <table className="data">
            <thead><tr><th>Code</th><th>Discount</th><th>Minimum spend</th><th>Expires</th><th>Used</th><th>On</th><th /></tr></thead>
            <tbody>
              {items.map((c) => {
                const expired = c.expires_at && parseTime(c.expires_at).getTime() < now;
                return (
                  <tr key={c.id} className={c.is_active ? '' : 'opacity-60'} data-testid={`coupon-${c.id}`}>
                    <td><div className="font-mono text-[14px] font-bold text-brand">{c.code}</div><div className="text-[12px] text-muted">{c.description}</div></td>
                    <td className="font-semibold">{offText(c)}</td>
                    <td className="text-muted">{c.min_subtotal ? money(c.min_subtotal) : 'None'}</td>
                    <td>{c.expires_at ? <span className={expired ? 'font-semibold text-red-600' : 'text-muted'}>{c.expires_at.slice(0, 10)}{expired ? ' (expired)' : ''}</span> : <span className="text-muted">Never</span>}</td>
                    <td>{c.used}</td>
                    <td><Toggle checked={c.is_active} label={`${c.code} on`} onChange={(v) => toggle(c, v)} /></td>
                    <td className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button small variant="outline" icon="edit" onClick={() => open(c)}>Edit</Button>
                        <Button small variant="dangerOutline" icon="delete" onClick={() => setDeleting(c)}>Delete</Button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>
      <Drawer
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing?.id ? `Edit ${editing.code}` : 'New coupon'}
        footer={<Button className="w-full" icon="check" loading={saving} onClick={save} data-testid="coupon-save">Save</Button>}
      >
        <div className="flex flex-col gap-4">
          <Field label="Code" maxLength={30} value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase().replace(/[^A-Z0-9-]/g, '') })} error={errors.code} data-testid="coupon-code" />
          <Field label="Description" maxLength={150} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} error={errors.description} placeholder="e.g. 10% off your first order" />
          <div>
            <span className="mb-1 block text-[12.5px] font-semibold text-muted">Discount</span>
            <div className="flex gap-2">
              {[['percent', 'Percent', 'percent'], ['fixed', 'Fixed amount', 'payments']].map(([v, label, icon]) => (
                <button key={v} type="button" onClick={() => setForm({ ...form, discount_type: v })}
                  className={`flex flex-1 items-center justify-center gap-1.5 rounded-[14px] border py-2.5 text-[13.5px] font-semibold ${form.discount_type === v ? 'border-brand bg-brand-tint text-brand' : 'border-line'}`}>
                  <Icon name={icon} size={18} />{label}
                </button>
              ))}
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Field label={form.discount_type === 'percent' ? 'Percent off' : 'Dollars off'} {...num('value')} data-testid="coupon-value" />
            <Field label="Minimum spend ($)" placeholder="None" {...num('min_subtotal')} />
          </div>
          {form.discount_type === 'percent' && <Field label="Maximum discount ($)" placeholder="No limit" {...num('max_discount')} />}
          <Field label="Expires (optional)" type="date" value={form.expires_at} onChange={(e) => setForm({ ...form, expires_at: e.target.value })} error={errors.expires_at} />
          <div className="flex items-center justify-between"><span className="font-semibold">Customers can use it</span><Toggle checked={form.is_active} label="Active" onChange={(v) => setForm({ ...form, is_active: v })} /></div>
        </div>
      </Drawer>
      <ConfirmDialog open={!!deleting} title={`Delete ${deleting?.code}?`} message="Customers can no longer use it. Past orders keep their discount." confirmLabel="Delete" onCancel={() => setDeleting(null)} onConfirm={remove} />
    </>
  );
}
