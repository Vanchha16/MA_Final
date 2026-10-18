import { useState } from 'react';
import { useAuth } from '../auth';
import { Button, Card, Field, Icon } from '../components/ui';

export default function Login() {
  const { login, notice } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setFieldErrors({});
    try {
      await login(email.trim(), password);
    } catch (err) {
      setError(err.message);
      setFieldErrors(err.errors || {});
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid min-h-screen place-items-center bg-page p-6">
      <Card className="w-full max-w-[400px] p-8">
        <div className="mb-6 flex flex-col items-center text-center">
          <img src="/static/admin/logo.png" alt="" className="mb-3 h-16 w-16" />
          <h1 className="text-[22px] font-extrabold">Anime World Admin</h1>
          <p className="text-[13.5px] text-muted">Sign in with a shop admin account</p>
        </div>
        {(error || notice) && (
          <div role="alert" className="mb-4 flex items-center gap-2 rounded-[14px] bg-red-50 px-3.5 py-3 text-[13px] font-semibold text-red-700">
            <Icon name="error" size={18} />{error || notice}
          </div>
        )}
        <form onSubmit={submit} className="flex flex-col gap-3.5">
          <Field label="Email" type="email" autoComplete="username" value={email} maxLength={150} onChange={(e) => setEmail(e.target.value)} error={fieldErrors.email} required />
          <Field label="Password" type="password" autoComplete="current-password" value={password} maxLength={200} onChange={(e) => setPassword(e.target.value)} error={fieldErrors.password} required />
          <Button type="submit" icon="login" loading={busy} className="mt-1 w-full">Sign in</Button>
        </form>
      </Card>
    </div>
  );
}
