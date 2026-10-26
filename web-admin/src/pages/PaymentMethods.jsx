import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Card, ErrorBox, Icon, PageTitle, Toggle } from '../components/ui';

/** Same logo tiles as the app's checkout. */
const LOGO = {
  khqr: <div className="grid h-11 w-11 place-items-center rounded-[13px] bg-[#E1232E]"><img src="/static/admin/pay-bakong.png" alt="Bakong KHQR" className="w-[35px]" /></div>,
  aba: <img src="/static/admin/pay-aba.png" alt="ABA Bank" className="h-11 w-11 rounded-[13px]" />,
  cod: <div className="grid h-11 w-11 place-items-center rounded-[13px] bg-[#16A34A]/[.13] text-[#16A34A]"><Icon name="payments" size={24} /></div>,
};

const status = (m) => (!m.enabled ? 'Off · hidden at checkout' : m.set_up ? 'On · customers can choose it' : 'On · the server has no bank keys for it yet');

/** Turn KHQR, ABA PayWay or cash on or off (layout A from the app). Owner only. */
export default function PaymentMethods() {
  const toast = useToast();
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(null);

  const load = useCallback(async () => {
    try {
      setItems(await api.get('/admin/payment-methods'));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const toggle = async (m, on) => {
    setSaving(m.id);
    try {
      setItems(await api.put(`/admin/payment-methods/${m.id}`, { enabled: on }));
      toast(on ? `${m.label} is back at checkout` : `${m.label} is now hidden at checkout`, { icon: 'payments' });
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setSaving(null);
    }
  };

  return (
    <>
      <PageTitle title="Payment methods" sub="Choose how customers can pay at checkout." />
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="max-w-[640px] divide-y divide-line/60">
        {items === null ? <div className="p-10 text-center text-muted">Loading…</div> : items.map((m) => (
          <div key={m.id} className="flex items-center gap-4 px-5 py-4" data-testid={`pay-${m.id}`}>
            <div className={m.enabled ? '' : 'opacity-40'}>{LOGO[m.id]}</div>
            <div className="min-w-0 flex-1">
              <div className={`text-[15px] font-semibold ${m.enabled ? '' : 'text-muted'}`}>{m.label}</div>
              <div className={`text-[13px] ${m.enabled && !m.set_up ? 'text-amber-600' : 'text-muted'}`}>{status(m)}</div>
            </div>
            <Toggle checked={m.enabled} label={`${m.label} on`} disabled={saving === m.id} onChange={(v) => toggle(m, v)} />
          </div>
        ))}
      </Card>
      <div className="flex max-w-[640px] items-start gap-2.5 rounded-[14px] bg-brand-tint px-4 py-3 text-[13px] text-muted">
        <Icon name="info" className="text-brand" />
        <span>Orders placed before a method was turned off can still be paid with it. At least one method has to stay on.</span>
      </div>
    </>
  );
}
