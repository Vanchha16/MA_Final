import { useEffect } from 'react';
import { STATUS } from '../lib/format';

/** Material Symbols icon (no emoji anywhere). */
export const Icon = ({ name, className = '', size = 20, title }) => (
  <span className={`material-symbols-rounded select-none ${className}`} style={{ fontSize: size }} aria-hidden={!title} title={title}>
    {name}
  </span>
);

export const Card = ({ className = '', children, ...rest }) => (
  <div className={`bg-white rounded-card shadow-card ${className}`} {...rest}>{children}</div>
);

export const Chip = ({ className = 'bg-brand-tint text-brand', children }) => (
  <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11.5px] font-bold whitespace-nowrap ${className}`}>{children}</span>
);

export const StatusChip = ({ status }) => {
  const s = STATUS[status] || STATUS.pending;
  return <Chip className={s.cls}>{s.label}</Chip>;
};

export const Spinner = ({ className = '' }) => (
  <Icon name="progress_activity" size={18} className={`animate-spin ${className}`} />
);

const VARIANTS = {
  primary: 'bg-brand text-white hover:bg-brand-dark',
  ghost: 'bg-brand-tint text-brand hover:bg-sky-200',
  danger: 'bg-red-600 text-white hover:bg-red-700',
  outline: 'border border-line text-ink bg-white hover:bg-slate-50',
  dangerOutline: 'border border-red-300 text-red-600 bg-white hover:bg-red-50',
  success: 'bg-green-600 text-white hover:bg-green-700',
};

/** Solid pill button (never a gradient). */
export function Button({ variant = 'primary', icon, loading = false, small = false, className = '', children, disabled, ...rest }) {
  return (
    <button
      type="button"
      disabled={disabled || loading}
      className={`inline-flex items-center justify-center gap-1.5 rounded-full font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed
        ${small ? 'px-3 py-1.5 text-[12.5px]' : 'px-4 py-2.5 text-[13.5px]'} ${VARIANTS[variant]} ${className}`}
      {...rest}
    >
      {loading ? <Spinner /> : icon ? <Icon name={icon} size={small ? 16 : 18} /> : null}
      {children}
    </button>
  );
}

export const Kpi = ({ icon, tint, value, label, sub, testid }) => (
  <Card className="flex flex-1 items-center gap-3.5 p-[18px]">
    <div className={`grid h-[46px] w-[46px] shrink-0 place-items-center rounded-[14px] ${tint}`}><Icon name={icon} /></div>
    <div className="min-w-0">
      <div className="text-[26px] font-extrabold leading-tight" data-testid={testid}>{value}</div>
      <div className="text-[12.5px] text-muted">{label}</div>
      {sub && <div className="mt-0.5 text-[11.5px] font-bold text-green-600">{sub}</div>}
    </div>
  </Card>
);

export const Photo = ({ src, size = 40, className = '' }) =>
  src ? (
    <img src={src} alt="" className={`shrink-0 rounded-[10px] bg-brand-tint object-cover ${className}`} style={{ width: size, height: size }} />
  ) : (
    <div className={`grid shrink-0 place-items-center rounded-[10px] bg-brand-tint text-brand ${className}`} style={{ width: size, height: size }}>
      <Icon name="toys" size={size * 0.5} />
    </div>
  );

export const Empty = ({ icon = 'inbox', text, action }) => (
  <div className="flex flex-col items-center gap-2 px-6 py-12 text-center text-muted">
    <Icon name={icon} size={44} />
    <div className="text-[13.5px]">{text}</div>
    {action}
  </div>
);

export const PageTitle = ({ title, sub, children }) => (
  <div className="flex items-center gap-4">
    <div className="flex-1">
      <h1 className="text-2xl font-extrabold">{title}</h1>
      {sub && <div className="text-[13px] text-muted">{sub}</div>}
    </div>
    {children}
  </div>
);

export const SearchBox = ({ value, onChange, placeholder, className = 'w-[340px]' }) => (
  <label className={`flex items-center gap-2 rounded-full bg-white px-4 py-2.5 shadow-card ${className}`}>
    <Icon name="search" className="text-muted" />
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      maxLength={100}
      className="w-full bg-transparent text-[13.5px] outline-none placeholder:text-muted"
    />
  </label>
);

/** A row of filter chips with counts; [items] = [[key, label, count]]. */
export const FilterChips = ({ items, value, onChange }) => (
  <div className="flex flex-wrap gap-2">
    {items.map(([key, label, count]) => (
      <button
        key={key}
        type="button"
        onClick={() => onChange(key)}
        className={`rounded-full px-3.5 py-1.5 text-[12.5px] font-semibold transition-colors ${
          value === key ? 'bg-brand text-white' : 'border border-line bg-white text-ink hover:bg-slate-50'
        }`}
      >
        {label}{count !== undefined && count !== null ? `  ${count}` : ''}
      </button>
    ))}
  </div>
);

/** Panel that slides in from the right, over a dim backdrop. */
export function Drawer({ open, onClose, title, children, footer, width = 440 }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    if (open) window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  return (
    <div className={`fixed inset-0 z-40 ${open ? '' : 'pointer-events-none'}`} aria-hidden={!open}>
      <div className={`absolute inset-0 bg-slate-900/35 transition-opacity duration-300 ${open ? 'opacity-100' : 'opacity-0'}`} onClick={onClose} />
      <aside
        role="dialog"
        aria-label={title}
        className={`absolute right-0 top-0 flex h-full flex-col bg-white shadow-drawer transition-transform duration-300 ease-out ${open ? 'translate-x-0' : 'translate-x-full'}`}
        style={{ width }}
      >
        <div className="flex items-center gap-3 px-6 pb-3 pt-6">
          <h2 className="flex-1 text-[19px] font-bold">{title}</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink" aria-label="Close"><Icon name="close" /></button>
        </div>
        <div className="flex-1 overflow-y-auto px-6 pb-6">{open && children}</div>
        {footer && open && <div className="border-t border-line px-6 py-4">{footer}</div>}
      </aside>
    </div>
  );
}

/** "Are you sure?" pop-up. The confirm button is solid red for destructive actions. */
export function ConfirmDialog({ open, title, message, confirmLabel = 'Confirm', danger = true, busy = false, onConfirm, onCancel }) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-slate-900/40 p-4" role="alertdialog" aria-label={title}>
      <Card className="w-full max-w-[400px] p-6 text-center">
        <div className={`mx-auto mb-3 grid h-14 w-14 place-items-center rounded-full ${danger ? 'bg-red-50 text-red-600' : 'bg-brand-tint text-brand'}`}>
          <Icon name={danger ? 'warning' : 'help'} size={28} />
        </div>
        <h3 className="text-lg font-bold">{title}</h3>
        <p className="mt-1 text-[13.5px] text-muted">{message}</p>
        <div className="mt-5 flex gap-3">
          <Button variant="outline" className="flex-1" onClick={onCancel}>Keep it</Button>
          <Button variant={danger ? 'danger' : 'primary'} className="flex-1" loading={busy} onClick={onConfirm}>{confirmLabel}</Button>
        </div>
      </Card>
    </div>
  );
}

/** Labelled input with the server's error under it. */
export function Field({ label, error, textarea = false, className = '', ...rest }) {
  const Tag = textarea ? 'textarea' : 'input';
  return (
    <label className={`block ${className}`}>
      <span className="mb-1 block text-[12.5px] font-semibold text-muted">{label}</span>
      <Tag
        {...rest}
        className={`w-full rounded-[14px] border bg-white px-3.5 py-2.5 text-[14px] outline-none transition-colors focus:border-brand ${
          error ? 'border-red-400' : 'border-line'
        } ${textarea ? 'min-h-[110px] resize-y' : ''}`}
      />
      {error && <span className="mt-1 block text-[12px] font-semibold text-red-600">{error}</span>}
    </label>
  );
}

export const Toggle = ({ checked, onChange, label, disabled }) => (
  <button
    type="button"
    role="switch"
    aria-checked={checked}
    aria-label={label}
    disabled={disabled}
    onClick={() => onChange(!checked)}
    className={`relative h-7 w-12 shrink-0 rounded-full transition-colors disabled:opacity-50 ${checked ? 'bg-brand' : 'bg-slate-300'}`}
  >
    <span className={`absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all ${checked ? 'left-6' : 'left-1'}`} />
  </button>
);

export const ErrorBox = ({ message, onRetry }) => (
  <Card className="flex items-center gap-3 border border-red-200 bg-red-50 p-4 text-red-700">
    <Icon name="cloud_off" />
    <div className="flex-1 text-[13.5px] font-semibold">{message}</div>
    {onRetry && <Button small variant="dangerOutline" icon="refresh" onClick={onRetry}>Try again</Button>}
  </Card>
);
