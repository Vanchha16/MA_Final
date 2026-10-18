import { createContext, useCallback, useContext, useRef, useState } from 'react';
import { Icon } from './ui';

const ToastContext = createContext(() => {});

/** Dark message at the bottom of the screen, e.g. "Order confirmed · the customer was told". */
export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const seq = useRef(0);
  const show = useCallback((text, { icon = 'check_circle', error = false } = {}) => {
    const id = ++seq.current;
    setToasts((t) => [...t.slice(-2), { id, text, icon, error }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3200);
  }, []);
  return (
    <ToastContext.Provider value={show}>
      {children}
      <div className="pointer-events-none fixed bottom-6 left-1/2 z-[60] flex -translate-x-1/2 flex-col items-center gap-2" aria-live="polite">
        {toasts.map((t) => (
          <div key={t.id} role="status" className="flex animate-[toast-in_.25s_ease-out] items-center gap-2.5 rounded-[14px] bg-slate-800 px-4 py-3 text-[13.5px] font-semibold text-white shadow-xl">
            <Icon name={t.error ? 'error' : t.icon} className={t.error ? 'text-red-300' : 'text-sky-400'} />
            {t.text}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
