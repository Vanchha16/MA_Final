import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import ReplyDrawer from '../components/ReplyDrawer';
import { Button, Card, Chip, Empty, ErrorBox, FilterChips, Icon, PageTitle } from '../components/ui';
import { timeAgo } from '../lib/format';
import { useStats } from '../stats';

const TOPIC = { order: 'Order', payment: 'Payment', product: 'Product', other: 'Something else' };

export default function Messages() {
  const { refresh, tick } = useStats();
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('open');
  const [replyTo, setReplyTo] = useState(null);

  const load = useCallback(async () => {
    try {
      setItems((await api.get('/admin/contact-messages', { per_page: 100 })).items);
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load, tick]);

  const shown = (items || []).filter((m) => m.status === filter);
  return (
    <>
      <PageTitle title="Messages" sub="Questions from the app's Contact screen. Your reply arrives in the customer's Notifications." />
      <FilterChips
        items={[['open', 'Open', items?.filter((m) => m.status === 'open').length], ['answered', 'Answered', items?.filter((m) => m.status === 'answered').length]]}
        value={filter}
        onChange={setFilter}
      />
      {error && <ErrorBox message={error} onRetry={load} />}
      {items === null ? <Card className="p-10 text-center text-muted">Loading…</Card> : shown.length === 0 ? (
        <Card><Empty icon="forum" text={filter === 'open' ? 'No questions waiting. Nice!' : 'No answered messages yet.'} /></Card>
      ) : (
        <div className="grid grid-cols-2 gap-4">
          {shown.map((m) => (
            <Card key={m.id} className="flex flex-col gap-3 p-5" data-testid={`message-${m.id}`}>
              <div className="flex items-center gap-3">
                <div className="grid h-9 w-9 place-items-center rounded-full bg-brand-tint font-bold text-brand">{m.customer.full_name[0]}</div>
                <div className="flex-1 font-bold">{m.customer.full_name}</div>
                <span className="text-[12px] text-muted">{timeAgo(m.created_at)}</span>
              </div>
              <div className="flex gap-2">
                <Chip className="bg-cyan-100 text-cyan-700">{TOPIC[m.topic] || 'Message'}</Chip>
                {m.order && <Chip>{m.order.number}</Chip>}
              </div>
              <p className="text-[14px] leading-relaxed">{m.message}</p>
              {m.status === 'open' ? (
                <Button icon="reply" className="self-start" onClick={() => setReplyTo(m)} data-testid={`message-reply-${m.id}`}>Reply</Button>
              ) : (
                <div className="flex gap-2 rounded-2xl bg-green-50 p-3 text-[13px] font-semibold text-green-700">
                  <Icon name="reply" size={18} />{m.reply}
                </div>
              )}
            </Card>
          ))}
        </div>
      )}
      <ReplyDrawer message={replyTo} onClose={() => setReplyTo(null)} onSent={() => { load(); refresh(); }} />
    </>
  );
}
