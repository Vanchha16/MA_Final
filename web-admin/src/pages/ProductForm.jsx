import { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api';
import { useToast } from '../components/toast';
import { Button, Card, ConfirmDialog, ErrorBox, Field, Icon, PageTitle, Spinner, Toggle } from '../components/ui';
import { useStats } from '../stats';

const EMPTY = { name: '', category_id: '', series_id: '', brand: '', price: '', discount_price: '', stock: '1', description: '', is_featured: false, is_active: true };

/** Add or edit a product. New photos wait until the product is saved, then upload one by one. */
export default function ProductForm() {
  const { id } = useParams();
  const editing = Boolean(id);
  const navigate = useNavigate();
  const toast = useToast();
  const { refresh } = useStats();
  const fileInput = useRef(null);
  const [form, setForm] = useState(EMPTY);
  const [photos, setPhotos] = useState([]); // saved: {id, url, is_primary}
  const [queued, setQueued] = useState([]); // new: {file, preview}
  const [categories, setCategories] = useState([]);
  const [series, setSeries] = useState([]);
  const [errors, setErrors] = useState({});
  const [loadError, setLoadError] = useState(null);
  const [loading, setLoading] = useState(editing);
  const [saving, setSaving] = useState(false);
  const [askHide, setAskHide] = useState(false);

  useEffect(() => {
    Promise.all([api.get('/admin/categories'), api.get('/series')])
      .then(([c, s]) => {
        setCategories(c);
        setSeries(s);
        if (!editing && c.length) setForm((f) => ({ ...f, category_id: f.category_id || String(c[0].id) }));
      })
      .catch((e) => setLoadError(e.message));
    if (!editing) return;
    api.get(`/admin/products/${id}`)
      .then((p) => {
        setForm({
          name: p.name, category_id: String(p.category.id), series_id: p.series ? String(p.series.id) : '', brand: p.brand || '',
          price: String(p.price), discount_price: p.discount_price != null ? String(p.discount_price) : '', stock: String(p.stock),
          description: p.description || '', is_featured: p.is_featured, is_active: p.is_active,
        });
        setPhotos(p.photos);
      })
      .catch((e) => setLoadError(e.message))
      .finally(() => setLoading(false));
  }, [id, editing]);

  useEffect(() => () => queued.forEach((q) => URL.revokeObjectURL(q.preview)), [queued]);

  const field = (name) => ({ value: form[name], onChange: (e) => setForm({ ...form, [name]: e.target.value }), error: errors[name] });

  const save = async () => {
    setSaving(true);
    setErrors({});
    const body = {
      ...form,
      category_id: form.category_id ? Number(form.category_id) : null,
      series_id: form.series_id ? Number(form.series_id) : null,
      price: form.price.trim(),
      discount_price: form.discount_price.trim() || null,
      stock: form.stock.trim(),
    };
    try {
      const saved = editing ? await api.put(`/admin/products/${id}`, body) : await api.post('/admin/products', body);
      let failed = 0;
      for (const q of queued) {
        try { await api.upload(`/admin/products/${saved.id}/images`, q.file); } catch { failed += 1; }
      }
      setQueued([]);
      toast(editing ? 'Product saved' : `${saved.name} added`);
      if (failed) toast(`${failed} photo(s) could not be uploaded`, { error: true });
      refresh();
      navigate('/products');
    } catch (e) {
      setErrors(e.errors || {});
      toast(e.errors ? 'Please check the highlighted fields' : e.message, { error: true });
    } finally {
      setSaving(false);
    }
  };

  const removePhoto = async (photo) => {
    try {
      const p = await api.del(`/admin/products/${id}/images/${photo.id}`);
      setPhotos(p.photos);
    } catch (e) {
      toast(e.message, { error: true });
    }
  };

  const hide = async () => {
    try {
      await api.del(`/admin/products/${id}`);
      toast('Product hidden from the shop');
      refresh();
      navigate('/products');
    } catch (e) {
      toast(e.message, { error: true });
    }
  };

  if (loading) return <div className="grid place-items-center py-24 text-brand"><Spinner /></div>;
  return (
    <>
      <PageTitle title={editing ? 'Edit product' : 'Add product'} sub={editing ? form.name : 'It appears in the shop as soon as it is saved.'}>
        <Button variant="outline" icon="arrow_back" onClick={() => navigate('/products')}>Back</Button>
        {editing && form.is_active && <Button variant="dangerOutline" icon="visibility_off" onClick={() => setAskHide(true)}>Hide</Button>}
        <Button icon="check" loading={saving} onClick={save} data-testid="product-save">{editing ? 'Save product' : 'Add product'}</Button>
      </PageTitle>
      {loadError && <ErrorBox message={loadError} />}

      <div className="flex gap-4">
        <Card className="flex flex-[1.6] flex-col gap-4 p-6">
          <Field label="Name" maxLength={150} {...field('name')} data-testid="product-name" />
          <div className="grid grid-cols-2 gap-4">
            <label className="block">
              <span className="mb-1 block text-[12.5px] font-semibold text-muted">Category</span>
              <select className="w-full rounded-[14px] border border-line bg-card px-3.5 py-2.5 text-[14px]" {...field('category_id')} error={undefined}>
                {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
              {errors.category_id && <span className="mt-1 block text-[12px] font-semibold text-red-600">{errors.category_id}</span>}
            </label>
            <label className="block">
              <span className="mb-1 block text-[12.5px] font-semibold text-muted">Series</span>
              <select className="w-full rounded-[14px] border border-line bg-card px-3.5 py-2.5 text-[14px]" value={form.series_id} onChange={(e) => setForm({ ...form, series_id: e.target.value })}>
                <option value="">None</option>
                {series.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </label>
          </div>
          <Field label="Brand" maxLength={100} {...field('brand')} />
          <div className="grid grid-cols-3 gap-4">
            <Field label="Price ($)" inputMode="decimal" maxLength={10} {...field('price')} onChange={(e) => setForm({ ...form, price: e.target.value.replace(/[^0-9.]/g, '') })} data-testid="product-price" />
            <Field label="Sale price ($)" inputMode="decimal" maxLength={10} placeholder="None" {...field('discount_price')} onChange={(e) => setForm({ ...form, discount_price: e.target.value.replace(/[^0-9.]/g, '') })} />
            <Field label="Stock" inputMode="numeric" maxLength={6} {...field('stock')} onChange={(e) => setForm({ ...form, stock: e.target.value.replace(/\D/g, '') })} />
          </div>
          <Field label="Description" textarea maxLength={5000} {...field('description')} />
        </Card>

        <div className="flex flex-1 flex-col gap-4">
          <Card className="p-6">
            <div className="mb-3 text-base font-bold">Photos</div>
            <div className="grid grid-cols-3 gap-3">
              {photos.map((ph) => (
                <div key={ph.id} className="group relative">
                  <img src={ph.url} alt="" className="aspect-square w-full rounded-2xl object-cover" />
                  {ph.is_primary && <span className="absolute left-1.5 top-1.5 rounded-full bg-card px-2 py-0.5 text-[11px] font-bold">Main</span>}
                  <button type="button" onClick={() => removePhoto(ph)} aria-label="Remove photo" className="absolute right-1.5 top-1.5 grid h-7 w-7 place-items-center rounded-full bg-card text-red-600 shadow opacity-0 transition-opacity group-hover:opacity-100">
                    <Icon name="delete" size={16} />
                  </button>
                </div>
              ))}
              {queued.map((q, i) => (
                <div key={q.preview} className="relative">
                  <img src={q.preview} alt="" className="aspect-square w-full rounded-2xl object-cover opacity-80" />
                  <span className="absolute left-1.5 top-1.5 rounded-full bg-brand px-2 py-0.5 text-[11px] font-bold text-brand-on">New</span>
                  <button type="button" onClick={() => setQueued(queued.filter((_, n) => n !== i))} aria-label="Remove new photo" className="absolute right-1.5 top-1.5 grid h-7 w-7 place-items-center rounded-full bg-card text-red-600 shadow">
                    <Icon name="close" size={16} />
                  </button>
                </div>
              ))}
              <button type="button" onClick={() => fileInput.current?.click()} className="grid aspect-square place-items-center rounded-2xl border-2 border-dashed border-brand bg-brand-tint/50 text-brand">
                <span className="flex flex-col items-center gap-1 text-[12px] font-bold"><Icon name="add_a_photo" size={26} />Add photo</span>
              </button>
            </div>
            <input
              ref={fileInput}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              multiple
              hidden
              onChange={(e) => {
                const files = [...e.target.files].filter((f) => f.size <= 5 * 1024 * 1024);
                if (files.length < e.target.files.length) toast('Photos must be 5 MB or smaller', { error: true });
                setQueued([...queued, ...files.map((file) => ({ file, preview: URL.createObjectURL(file) }))]);
                e.target.value = '';
              }}
            />
            <p className="mt-3 text-[12px] text-muted">JPG, PNG or WebP up to 5 MB. The first photo is the main one. Photos are made square.</p>
          </Card>
          <Card className="flex flex-col gap-4 p-6">
            <div className="flex items-center justify-between"><span className="font-semibold">Featured on Home</span><Toggle checked={form.is_featured} label="Featured" onChange={(v) => setForm({ ...form, is_featured: v })} /></div>
            <div className="flex items-center justify-between"><span className="font-semibold">In the shop</span><Toggle checked={form.is_active} label="In the shop" onChange={(v) => setForm({ ...form, is_active: v })} /></div>
          </Card>
        </div>
      </div>
      <ConfirmDialog open={askHide} title="Hide this product?" message="Customers stop seeing it. Past orders keep it, and you can show it again any time." confirmLabel="Hide" onCancel={() => setAskHide(false)} onConfirm={hide} />
    </>
  );
}
