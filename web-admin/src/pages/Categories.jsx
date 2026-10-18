import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Button, Card, ConfirmDialog, Drawer, Empty, ErrorBox, Field, Icon, PageTitle } from '../components/ui';

export default function Categories() {
  const toast = useToast();
  const [items, setItems] = useState(null);
  const [error, setError] = useState(null);
  const [editing, setEditing] = useState(null); // {} for new, or a category
  const [form, setForm] = useState({ name: '', description: '' });
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(null);

  const load = useCallback(async () => {
    try {
      setItems(await api.get('/admin/categories'));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const open = (c) => {
    setEditing(c);
    setForm({ name: c.name || '', description: c.description || '' });
    setErrors({});
  };

  const save = async () => {
    setSaving(true);
    try {
      const body = { name: form.name, description: form.description.trim() || null };
      if (editing.id) await api.put(`/admin/categories/${editing.id}`, body);
      else await api.post('/admin/categories', body);
      toast(editing.id ? 'Category saved' : 'Category added');
      setEditing(null);
      load();
    } catch (e) {
      setErrors(e.errors || { name: e.message });
    } finally {
      setSaving(false);
    }
  };

  const remove = async () => {
    try {
      await api.del(`/admin/categories/${deleting.id}`);
      toast(`${deleting.name} deleted`);
      load();
    } catch (e) {
      toast(e.message, { error: true });
    } finally {
      setDeleting(null);
    }
  };

  return (
    <>
      <PageTitle title="Categories" sub="A category can be deleted once it has no products.">
        <Button icon="add" onClick={() => open({})} data-testid="category-new">New category</Button>
      </PageTitle>
      {error && <ErrorBox message={error} onRetry={load} />}
      <Card className="px-2 py-2">
        {items === null ? <div className="p-10 text-center text-muted">Loading…</div> : items.length === 0 ? <Empty icon="category" text="No categories yet." /> : (
          <table className="data">
            <thead><tr><th>Category</th><th>Description</th><th>Products</th><th /></tr></thead>
            <tbody>
              {items.map((c) => (
                <tr key={c.id} data-testid={`category-${c.id}`}>
                  <td>
                    <div className="flex items-center gap-3">
                      <div className="grid h-10 w-10 place-items-center rounded-xl bg-violet-100 text-violet-700"><Icon name="category" /></div>
                      <span className="font-semibold">{c.name}</span>
                    </div>
                  </td>
                  <td className="max-w-[360px] truncate text-muted">{c.description || '—'}</td>
                  <td>{c.product_count === 0 ? <span className="text-muted">Empty</span> : c.product_count}</td>
                  <td className="text-right">
                    <div className="flex justify-end gap-2">
                      <Button small variant="outline" icon="edit" onClick={() => open(c)}>Edit</Button>
                      <Button
                        small
                        variant="dangerOutline"
                        icon="delete"
                        disabled={c.product_count > 0}
                        title={c.product_count > 0 ? 'Move or hide its products first' : 'Delete'}
                        onClick={() => setDeleting(c)}
                        data-testid={`category-delete-${c.id}`}
                      >
                        Delete
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <Drawer
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing?.id ? 'Edit category' : 'New category'}
        footer={<Button className="w-full" icon="check" loading={saving} onClick={save} data-testid="category-save">Save</Button>}
      >
        <div className="flex flex-col gap-4">
          <Field label="Name" autoFocus maxLength={100} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} error={errors.name} data-testid="category-name" />
          <Field label="Description (optional)" textarea maxLength={1000} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} error={errors.description} />
        </div>
      </Drawer>
      <ConfirmDialog open={!!deleting} title={`Delete ${deleting?.name}?`} message="It has no products, so nothing else changes." confirmLabel="Delete" onCancel={() => setDeleting(null)} onConfirm={remove} />
    </>
  );
}
