import { useEffect, useState } from 'react';
import { api } from '../api';
import { timeAgo } from '../lib/format';
import { useToast } from './toast';
import { Button, Chip, Drawer } from './ui';

const TOPIC = { order: 'Order', payment: 'Payment', product: 'Product', other: 'Something else' };

/** Answer a Contact message; the customer gets it in their Notifications. */
export default function ReplyDrawer({ message, onClose, onSent }) {
  const toast = useToast();
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setText('');
    setError(null);
  }, [message?.id]);

  const send = async () => {
    setBusy(true);
    setError(null);
    try {
      await api.post(`/admin/contact-messages/${message.id}/reply`, { reply: text.trim() });
      toast(`Reply sent to ${message.customer?.full_name || 'the customer'}`, { icon: 'send' });
      onSent?.();
      onClose();
    } catch (e) {
      setError(e.errors?.reply || e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Drawer
      open={!!message}
      onClose={onClose}
      title={`Reply to ${message?.customer?.full_name || 'customer'}`}
      footer={<Button className="w-full" icon="send" loading={busy} disabled={!text.trim()} onClick={send} data-testid="reply-send">Send reply</Button>}
    >
      {message && (
        <div className="flex flex-col gap-4">
          <div className="flex gap-2">
            <Chip className="bg-cyan-100 text-cyan-700">{TOPIC[message.topic] || 'Message'}</Chip>
            {message.order && <Chip>{message.order.number}</Chip>}
          </div>
          <div className="rounded-2xl bg-slate-100 p-3.5 text-[14px] leading-relaxed">
            {message.message}
            <div className="mt-1.5 text-[11.5px] text-muted">{timeAgo(message.created_at)} ago</div>
          </div>
          <textarea
            autoFocus
            value={text}
            maxLength={2000}
            onChange={(e) => setText(e.target.value)}
            placeholder="Your answer goes to their Notifications"
            data-testid="reply-text"
            className="min-h-[150px] w-full rounded-2xl border border-line p-3.5 text-[14px] outline-none focus:border-brand"
          />
          {error && <div className="text-[12.5px] font-semibold text-red-600">{error}</div>}
        </div>
      )}
    </Drawer>
  );
}
