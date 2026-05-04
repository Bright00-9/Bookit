import React, { useState, useEffect, useCallback } from 'react';
import {
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts';
import {
  Users, Briefcase, TrendingUp, Wifi, LogOut, Menu, X,
  ChevronRight, Search, Filter, Trash2, Ban, CheckCircle,
  Eye, AlertTriangle, Star, MapPin, Clock, RefreshCw, CreditCard,
} from 'lucide-react';
import * as api from './services/api';

// ─── THEME ───────────────────────────────────────────────────────────────────
const C = {
  bg: '#0A0A0F',
  surface: '#13131A',
  border: '#1E1E2E',
  accent: '#FF6B00',
  accentDim: 'rgba(255,107,0,0.12)',
  green: '#22C55E',
  red: '#EF4444',
  blue: '#3B82F6',
  yellow: '#F59E0B',
  text: '#F1F1F5',
  muted: '#6B7280',
  subtle: '#374151',
};

const SKILLS_COLORS = ['#FF6B00','#3B82F6','#22C55E','#F59E0B','#8B5CF6','#EC4899','#14B8A6','#F97316'];

// ─── HELPERS ─────────────────────────────────────────────────────────────────
const fmt = (n) => (n ?? 0).toLocaleString();
const timeAgo = (ts) => {
  if (!ts) return '';
  const diff = Date.now() - new Date(ts);
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  if (m < 1440) return `${Math.floor(m / 60)}h ago`;
  return `${Math.floor(m / 1440)}d ago`;
};

const Badge = ({ color, children }) => (
  <span style={{
    background: `${color}20`, color, border: `1px solid ${color}40`,
    padding: '2px 8px', borderRadius: 6, fontSize: 11, fontWeight: 700,
    letterSpacing: '0.04em', textTransform: 'uppercase',
  }}>{children}</span>
);

const statusColor = (s) => ({ open: C.green, accepted: C.yellow, completed: C.blue }[s] ?? C.muted);
const urgencyColor = (u) => ({ normal: C.green, urgent: C.yellow, emergency: C.red }[u] ?? C.muted);

// ─── STAT CARD ────────────────────────────────────────────────────────────────
const StatCard = ({ icon: Icon, label, value, color, sub }) => (
  <div style={{
    background: C.surface, border: `1px solid ${C.border}`,
    borderRadius: 16, padding: '20px 24px',
    display: 'flex', alignItems: 'center', gap: 16,
  }}>
    <div style={{
      width: 48, height: 48, borderRadius: 12,
      background: `${color}15`, display: 'flex',
      alignItems: 'center', justifyContent: 'center', flexShrink: 0,
    }}>
      <Icon size={22} color={color} />
    </div>
    <div>
      <div style={{ fontSize: 26, fontWeight: 800, color: C.text, lineHeight: 1 }}>{fmt(value)}</div>
      <div style={{ fontSize: 13, color: C.muted, marginTop: 4 }}>{label}</div>
      {sub && <div style={{ fontSize: 11, color, marginTop: 2 }}>{sub}</div>}
    </div>
  </div>
);

// ─── TABLE ────────────────────────────────────────────────────────────────────
const Table = ({ cols, rows, onRow }) => (
  <div style={{ overflowX: 'auto' }}>
    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
      <thead>
        <tr style={{ borderBottom: `1px solid ${C.border}` }}>
          {cols.map((c) => (
            <th key={c.key} style={{
              padding: '10px 16px', textAlign: 'left',
              color: C.muted, fontWeight: 600, fontSize: 11,
              textTransform: 'uppercase', letterSpacing: '0.05em', whiteSpace: 'nowrap',
            }}>{c.label}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, i) => (
          <tr key={i}
            onClick={() => onRow?.(row)}
            style={{
              borderBottom: `1px solid ${C.border}`,
              cursor: onRow ? 'pointer' : 'default',
              transition: 'background 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = C.border}
            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
          >
            {cols.map((c) => (
              <td key={c.key} style={{ padding: '12px 16px', color: C.text, whiteSpace: 'nowrap' }}>
                {c.render ? c.render(row[c.key], row) : (row[c.key] ?? '—')}
              </td>
            ))}
          </tr>
        ))}
        {rows.length === 0 && (
          <tr><td colSpan={cols.length} style={{ padding: 40, textAlign: 'center', color: C.muted }}>
            No data found
          </td></tr>
        )}
      </tbody>
    </table>
  </div>
);

// ─── LOGIN PAGE ───────────────────────────────────────────────────────────────
const LoginPage = ({ onLogin }) => {
  const [email, setEmail] = useState('admin@moka.com');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      const res = await api.login(email, password);
      localStorage.setItem('moka_admin_token', res.data.access_token);
      onLogin(res.data.admin);
    } catch {
      setError('Invalid email or password');
    } finally {
      setLoading(false);
    }
  };

  const inputStyle = {
    width: '100%', padding: '12px 16px', background: C.surface,
    border: `1px solid ${C.border}`, borderRadius: 10, color: C.text,
    fontSize: 14, outline: 'none', boxSizing: 'border-box',
  };

  return (
    <div style={{
      minHeight: '100vh', background: C.bg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: "'DM Sans', sans-serif",
    }}>
      <div style={{
        background: C.surface, border: `1px solid ${C.border}`,
        borderRadius: 20, padding: 40, width: 380,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 32 }}>
          <div style={{
            width: 44, height: 44, background: C.accent,
            borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Briefcase size={22} color="#fff" />
          </div>
          <div>
            <div style={{ color: C.text, fontWeight: 800, fontSize: 18 }}>Moka Admin</div>
            <div style={{ color: C.muted, fontSize: 12 }}>Dashboard</div>
          </div>
        </div>

        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: 16 }}>
            <label style={{ color: C.muted, fontSize: 12, fontWeight: 600, display: 'block', marginBottom: 6 }}>EMAIL</label>
            <input style={inputStyle} type="email" value={email}
              onChange={e => setEmail(e.target.value)} required />
          </div>
          <div style={{ marginBottom: 24 }}>
            <label style={{ color: C.muted, fontSize: 12, fontWeight: 600, display: 'block', marginBottom: 6 }}>PASSWORD</label>
            <input style={inputStyle} type="password" value={password} placeholder="••••••••"
              onChange={e => setPassword(e.target.value)} required />
          </div>
          {error && <div style={{ color: C.red, fontSize: 13, marginBottom: 16, textAlign: 'center' }}>{error}</div>}
          <button type="submit" disabled={loading} style={{
            width: '100%', padding: '13px', background: C.accent,
            border: 'none', borderRadius: 10, color: '#fff',
            fontWeight: 700, fontSize: 15, cursor: loading ? 'not-allowed' : 'pointer',
            opacity: loading ? 0.7 : 1,
          }}>{loading ? 'Signing in...' : 'Sign In'}</button>
        </form>
      </div>
    </div>
  );
};

// ─── ANALYTICS PAGE ───────────────────────────────────────────────────────────
const AnalyticsPage = () => {
  const [overview, setOverview] = useState(null);
  const [jobsBySkill, setJobsBySkill] = useState([]);
  const [jobsOverTime, setJobsOverTime] = useState([]);
  const [usersOverTime, setUsersOverTime] = useState([]);
  const [topWorkers, setTopWorkers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const [ov, jbs, jot, uot, tw] = await Promise.all([
          api.getOverview(), api.getJobsBySkill(),
          api.getJobsOverTime(30), api.getUsersOverTime(30),
          api.getTopWorkers(),
        ]);
        setOverview(ov.data);
        setJobsBySkill(jbs.data);
        setJobsOverTime(jot.data);
        setUsersOverTime(uot.data);
        setTopWorkers(tw.data);
      } catch {}
      setLoading(false);
    };
    load();
  }, []);

  if (loading) return <Loader />;

  return (
    <div>
      <SectionHeader title="Analytics" subtitle="Platform overview & insights" />

      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, marginBottom: 28 }}>
        <StatCard icon={Users} label="Total Users" value={overview?.totalUsers} color={C.accent} />
        <StatCard icon={Users} label="Workers" value={overview?.totalWorkers} color={C.blue} sub={`${overview?.onlineWorkers} online now`} />
        <StatCard icon={Users} label="Customers" value={overview?.totalCustomers} color={C.green} />
        <StatCard icon={Briefcase} label="Total Jobs" value={overview?.totalJobs} color={C.yellow} />
        <StatCard icon={Briefcase} label="Open Jobs" value={overview?.openJobs} color={C.accent} />
        <StatCard icon={CheckCircle} label="Completed" value={overview?.completedJobs} color={C.green} />
        <StatCard icon={Star} label="Total Reviews" value={overview?.totalRatings} color={C.yellow} />
        <StatCard icon={TrendingUp} label="Revenue (GHS)" value={overview?.totalRevenue} color={C.green} />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, marginBottom: 20 }}>
        {/* Jobs over time */}
        <ChartCard title="Jobs Over Time (30 days)">
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={jobsOverTime}>
              <CartesianGrid strokeDasharray="3 3" stroke={C.border} />
              <XAxis dataKey="date" tick={{ fill: C.muted, fontSize: 10 }} tickFormatter={d => d.slice(5)} />
              <YAxis tick={{ fill: C.muted, fontSize: 10 }} />
              <Tooltip contentStyle={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 8 }} />
              <Legend />
              <Line type="monotone" dataKey="total" stroke={C.accent} strokeWidth={2} dot={false} name="Total" />
              <Line type="monotone" dataKey="completed" stroke={C.green} strokeWidth={2} dot={false} name="Completed" />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Users over time */}
        <ChartCard title="New Users (30 days)">
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={usersOverTime}>
              <CartesianGrid strokeDasharray="3 3" stroke={C.border} />
              <XAxis dataKey="date" tick={{ fill: C.muted, fontSize: 10 }} tickFormatter={d => d.slice(5)} />
              <YAxis tick={{ fill: C.muted, fontSize: 10 }} />
              <Tooltip contentStyle={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 8 }} />
              <Legend />
              <Bar dataKey="customers" fill={C.green} name="Customers" radius={[3,3,0,0]} />
              <Bar dataKey="workers" fill={C.blue} name="Workers" radius={[3,3,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        {/* Jobs by skill pie */}
        <ChartCard title="Jobs by Skill">
          <ResponsiveContainer width="100%" height={220}>
            <PieChart>
              <Pie data={jobsBySkill} dataKey="count" nameKey="skill" cx="50%" cy="50%" outerRadius={80} label={({ skill, percent }) => `${skill} ${(percent * 100).toFixed(0)}%`} labelLine={false}>
                {jobsBySkill.map((_, i) => <Cell key={i} fill={SKILLS_COLORS[i % SKILLS_COLORS.length]} />)}
              </Pie>
              <Tooltip contentStyle={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 8 }} />
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Top workers */}
        <ChartCard title="Top Rated Workers">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, maxHeight: 220, overflowY: 'auto' }}>
            {topWorkers.map((w, i) => (
              <div key={w.id} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 24, height: 24, borderRadius: '50%', background: C.accentDim, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 700, color: C.accent, flexShrink: 0 }}>
                  {i + 1}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ color: C.text, fontSize: 13, fontWeight: 600 }}>{w.name}</div>
                  <div style={{ color: C.muted, fontSize: 11 }}>{w.skill}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                  <Star size={12} color={C.yellow} fill={C.yellow} />
                  <span style={{ color: C.text, fontSize: 13, fontWeight: 600 }}>{(w.rating || 0).toFixed(1)}</span>
                </div>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: w.is_online ? C.green : C.subtle }} />
              </div>
            ))}
          </div>
        </ChartCard>
      </div>
    </div>
  );
};

// ─── USERS PAGE ───────────────────────────────────────────────────────────────
const UsersPage = () => {
  const [users, setUsers] = useState([]);
  const [total, setTotal] = useState(0);
  const [role, setRole] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.getUsers({ role: role || undefined, page, limit: 20 });
      setUsers(res.data.data);
      setTotal(res.data.total);
    } catch {}
    setLoading(false);
  }, [role, page]);

  useEffect(() => { load(); }, [load]);

  const handleSuspend = async (id, suspended) => {
    if (!window.confirm(suspended ? 'Unsuspend this user?' : 'Suspend this user?')) return;
    try {
      suspended ? await api.unsuspendUser(id) : await api.suspendUser(id);
      load();
    } catch {}
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Permanently delete this user? This cannot be undone.')) return;
    try { await api.deleteUser(id); load(); } catch {}
  };

  const filtered = users.filter(u =>
    !search || u.name?.toLowerCase().includes(search.toLowerCase()) ||
    u.phone?.includes(search)
  );

  const cols = [
    { key: 'name', label: 'Name', render: (v, r) => (
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 32, height: 32, borderRadius: '50%', background: C.accentDim, display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.accent, fontWeight: 700, fontSize: 13 }}>
          {(v || '?')[0].toUpperCase()}
        </div>
        <div>
          <div style={{ fontWeight: 600, color: C.text }}>{v || '—'}</div>
          <div style={{ fontSize: 11, color: C.muted }}>{r.phone}</div>
        </div>
      </div>
    )},
    { key: 'role', label: 'Role', render: v => <Badge color={v === 'worker' ? C.blue : C.green}>{v}</Badge> },
    { key: 'skill', label: 'Skill', render: v => v ? <Badge color={C.accent}>{v}</Badge> : '—' },
    { key: 'is_suspended', label: 'Status', render: v => v
      ? <Badge color={C.red}>Suspended</Badge>
      : <Badge color={C.green}>Active</Badge>
    },
    { key: 'is_online', label: 'Online', render: v => (
      <div style={{ width: 8, height: 8, borderRadius: '50%', background: v ? C.green : C.subtle, margin: '0 auto' }} />
    )},
    { key: 'created_at', label: 'Joined', render: v => timeAgo(v) },
    { key: 'id', label: 'Actions', render: (id, row) => (
      <div style={{ display: 'flex', gap: 6 }}>
        <ActionBtn icon={row.is_suspended ? CheckCircle : Ban}
          color={row.is_suspended ? C.green : C.yellow}
          onClick={() => handleSuspend(id, row.is_suspended)}
          title={row.is_suspended ? 'Unsuspend' : 'Suspend'} />
        <ActionBtn icon={Trash2} color={C.red} onClick={() => handleDelete(id)} title="Delete" />
      </div>
    )},
  ];

  return (
    <div>
      <SectionHeader title="Users" subtitle={`${fmt(total)} total users`} />
      <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
        <SearchBar value={search} onChange={setSearch} placeholder="Search by name or phone..." />
        <Select value={role} onChange={setRole} options={[{ value: '', label: 'All Roles' }, { value: 'customer', label: 'Customers' }, { value: 'worker', label: 'Workers' }]} />
        <RefreshBtn onClick={load} />
      </div>
      <Card>
        {loading ? <Loader /> : <Table cols={cols} rows={filtered} />}
      </Card>
      <Pagination page={page} total={total} limit={20} onChange={setPage} />
    </div>
  );
};

// ─── JOBS PAGE ────────────────────────────────────────────────────────────────
const JobsPage = () => {
  const [jobs, setJobs] = useState([]);
  const [total, setTotal] = useState(0);
  const [status, setStatus] = useState('');
  const [skill, setSkill] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.getJobs({ status: status || undefined, skill: skill || undefined, page, limit: 20 });
      setJobs(res.data.data);
      setTotal(res.data.total);
    } catch {}
    setLoading(false);
  }, [status, skill, page]);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this job?')) return;
    try { await api.deleteJob(id); load(); } catch {}
  };

  const handleStatusChange = async (id, newStatus) => {
    try { await api.updateJobStatus(id, newStatus); load(); } catch {}
  };

  const cols = [
    { key: 'title', label: 'Job Title', render: (v, r) => (
      <div>
        <div style={{ fontWeight: 600, color: C.text }}>{v}</div>
        <div style={{ fontSize: 11, color: C.muted }}>{r.profiles?.name}</div>
      </div>
    )},
    { key: 'skill_needed', label: 'Skill', render: v => v ? <Badge color={C.blue}>{v}</Badge> : '—' },
    { key: 'urgency', label: 'Urgency', render: v => <Badge color={urgencyColor(v)}>{v}</Badge> },
    { key: 'status', label: 'Status', render: v => <Badge color={statusColor(v)}>{v}</Badge> },
    { key: 'budget', label: 'Budget', render: v => v ? `GHS ${Number(v).toFixed(2)}` : '—' },
    { key: 'payments', label: 'Payment', render: v => {
      const p = Array.isArray(v) ? v[0] : null;
      if (!p) return <Badge color={C.muted}>Unpaid</Badge>;
      return <Badge color={p.status === 'success' ? C.green : C.yellow}>{p.status}</Badge>;
    }},
    { key: 'created_at', label: 'Posted', render: v => timeAgo(v) },
    { key: 'id', label: 'Actions', render: (id, row) => (
      <div style={{ display: 'flex', gap: 6 }}>
        <ActionBtn icon={Eye} color={C.blue} onClick={() => setSelected(row)} title="View" />
        <ActionBtn icon={Trash2} color={C.red} onClick={() => handleDelete(id)} title="Delete" />
      </div>
    )},
  ];

  return (
    <div>
      <SectionHeader title="Jobs" subtitle={`${fmt(total)} total jobs`} />
      <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
        <Select value={status} onChange={setStatus} options={[
          { value: '', label: 'All Statuses' },
          { value: 'open', label: 'Open' },
          { value: 'accepted', label: 'Accepted' },
          { value: 'completed', label: 'Completed' },
        ]} />
        <Select value={skill} onChange={setSkill} options={[
          { value: '', label: 'All Skills' },
          ...['Plumber','Electrician','Cleaner','Carpenter','Painter','Mason','Welder','Driver','Security'].map(s => ({ value: s, label: s }))
        ]} />
        <RefreshBtn onClick={load} />
      </div>
      <Card>
        {loading ? <Loader /> : <Table cols={cols} rows={jobs} onRow={setSelected} />}
      </Card>
      <Pagination page={page} total={total} limit={20} onChange={setPage} />

      {selected && (
        <Modal title="Job Details" onClose={() => setSelected(null)}>
          <DetailRow label="Title" value={selected.title} />
          <DetailRow label="Description" value={selected.description} />
          <DetailRow label="Skill" value={selected.skill_needed} />
          <DetailRow label="Urgency" value={<Badge color={urgencyColor(selected.urgency)}>{selected.urgency}</Badge>} />
          <DetailRow label="Status" value={<Badge color={statusColor(selected.status)}>{selected.status}</Badge>} />
          <DetailRow label="Customer" value={selected.profiles?.name} />
          <DetailRow label="Location" value={selected.lat ? `${selected.lat?.toFixed(4)}, ${selected.lng?.toFixed(4)}` : '—'} />
          <DetailRow label="Posted" value={new Date(selected.created_at).toLocaleString()} />
          <div style={{ marginTop: 20, display: 'flex', gap: 10 }}>
            {['open','accepted','completed'].map(s => (
              <button key={s} onClick={() => { handleStatusChange(selected.id, s); setSelected(null); }} style={{
                padding: '8px 16px', background: `${statusColor(s)}20`, color: statusColor(s),
                border: `1px solid ${statusColor(s)}40`, borderRadius: 8, cursor: 'pointer',
                fontWeight: 600, fontSize: 12, textTransform: 'uppercase',
              }}>Set {s}</button>
            ))}
          </div>
        </Modal>
      )}
    </div>
  );
};

// ─── SHARED COMPONENTS ────────────────────────────────────────────────────────
const Loader = () => (
  <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}>
    <div style={{ width: 32, height: 32, border: `3px solid ${C.border}`, borderTopColor: C.accent, borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
  </div>
);

const Card = ({ children }) => (
  <div style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 16, overflow: 'hidden' }}>
    {children}
  </div>
);

const ChartCard = ({ title, children }) => (
  <div style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 16, padding: 20 }}>
    <div style={{ color: C.text, fontWeight: 700, fontSize: 14, marginBottom: 16 }}>{title}</div>
    {children}
  </div>
);

const SectionHeader = ({ title, subtitle }) => (
  <div style={{ marginBottom: 24 }}>
    <h2 style={{ color: C.text, fontSize: 22, fontWeight: 800, margin: 0 }}>{title}</h2>
    <p style={{ color: C.muted, fontSize: 13, margin: '4px 0 0' }}>{subtitle}</p>
  </div>
);

const SearchBar = ({ value, onChange, placeholder }) => (
  <div style={{ position: 'relative', flex: 1, minWidth: 200 }}>
    <Search size={15} color={C.muted} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)' }} />
    <input value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder}
      style={{ width: '100%', padding: '9px 12px 9px 36px', background: C.surface, border: `1px solid ${C.border}`, borderRadius: 10, color: C.text, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
  </div>
);

const Select = ({ value, onChange, options }) => (
  <select value={value} onChange={e => onChange(e.target.value)} style={{
    padding: '9px 12px', background: C.surface, border: `1px solid ${C.border}`,
    borderRadius: 10, color: C.text, fontSize: 13, outline: 'none', cursor: 'pointer',
  }}>
    {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
  </select>
);

const RefreshBtn = ({ onClick }) => (
  <button onClick={onClick} style={{
    padding: '9px 12px', background: C.surface, border: `1px solid ${C.border}`,
    borderRadius: 10, color: C.muted, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6,
  }}>
    <RefreshCw size={14} /> Refresh
  </button>
);

const ActionBtn = ({ icon: Icon, color, onClick, title }) => (
  <button onClick={e => { e.stopPropagation(); onClick(); }} title={title} style={{
    width: 30, height: 30, background: `${color}15`, border: `1px solid ${color}30`,
    borderRadius: 7, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
  }}>
    <Icon size={14} color={color} />
  </button>
);

const Pagination = ({ page, total, limit, onChange }) => {
  const pages = Math.ceil(total / limit);
  if (pages <= 1) return null;
  return (
    <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 16 }}>
      {Array.from({ length: Math.min(pages, 7) }, (_, i) => i + 1).map(p => (
        <button key={p} onClick={() => onChange(p)} style={{
          width: 36, height: 36, borderRadius: 8, border: `1px solid ${page === p ? C.accent : C.border}`,
          background: page === p ? C.accentDim : C.surface, color: page === p ? C.accent : C.muted,
          cursor: 'pointer', fontWeight: page === p ? 700 : 400, fontSize: 13,
        }}>{p}</button>
      ))}
    </div>
  );
};

const Modal = ({ title, children, onClose }) => (
  <div onClick={onClose} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
    <div onClick={e => e.stopPropagation()} style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 16, padding: 28, width: '100%', maxWidth: 480, maxHeight: '80vh', overflowY: 'auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <div style={{ color: C.text, fontWeight: 700, fontSize: 16 }}>{title}</div>
        <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: C.muted }}><X size={20} /></button>
      </div>
      {children}
    </div>
  </div>
);

const DetailRow = ({ label, value }) => (
  <div style={{ display: 'flex', gap: 12, padding: '8px 0', borderBottom: `1px solid ${C.border}` }}>
    <div style={{ color: C.muted, fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', width: 100, flexShrink: 0, paddingTop: 2 }}>{label}</div>
    <div style={{ color: C.text, fontSize: 13 }}>{value ?? '—'}</div>
  </div>
);

// ─── PAYMENTS PAGE ────────────────────────────────────────────────────────────
const PaymentsPage = () => {
  const [payments, setPayments] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.getPayments({ page, limit: 20 });
      setPayments(res.data.data);
      setTotal(res.data.total);
    } catch {}
    setLoading(false);
  }, [page]);

  useEffect(() => { load(); }, [load]);

  const cols = [
    { key: 'jobs', label: 'Job', render: v => (
      <div>
        <div style={{ fontWeight: 600, color: C.text }}>{v?.title || '—'}</div>
        <div style={{ fontSize: 11, color: C.muted }}>{v?.skill_needed}</div>
      </div>
    )},
    { key: 'profiles', label: 'Customer', render: v => v?.name || '—' },
    { key: 'amount', label: 'Amount', render: v => (
      <span style={{ color: C.green, fontWeight: 700 }}>
        GHS {Number(v || 0).toFixed(2)}
      </span>
    )},
    { key: 'payment_method', label: 'Method', render: v => v
      ? <Badge color={C.blue}>{v}</Badge>
      : '—'
    },
    { key: 'status', label: 'Status', render: v => (
      <Badge color={v === 'success' ? C.green : v === 'failed' ? C.red : C.yellow}>
        {v}
      </Badge>
    )},
    { key: 'paid_at', label: 'Paid At', render: v => v ? timeAgo(v) : '—' },
    { key: 'paystack_reference', label: 'Reference', render: v => (
      <span style={{ color: C.muted, fontSize: 11, fontFamily: 'monospace' }}>
        {v?.substring(0, 20)}...
      </span>
    )},
  ];

  return (
    <div>
      <SectionHeader title="Payments" subtitle={`${fmt(total)} total transactions`} />
      <div style={{ display: 'flex', gap: 12, marginBottom: 20 }}>
        <RefreshBtn onClick={load} />
      </div>
      <Card>
        {loading ? <Loader /> : <Table cols={cols} rows={payments} />}
      </Card>
      <Pagination page={page} total={total} limit={20} onChange={setPage} />
    </div>
  );
};

// ─── SIDEBAR ──────────────────────────────────────────────────────────────────
const NAV = [
  { id: 'analytics', label: 'Analytics', icon: TrendingUp },
  { id: 'users', label: 'Users', icon: Users },
  { id: 'jobs', label: 'Jobs', icon: Briefcase },
  { id: 'payments', label: 'Payments', icon: CreditCard },
];

const Sidebar = ({ active, onNav, admin, onLogout, collapsed, onToggle }) => (
  <div style={{
    width: collapsed ? 64 : 220, flexShrink: 0, background: C.surface,
    borderRight: `1px solid ${C.border}`, display: 'flex', flexDirection: 'column',
    transition: 'width 0.2s', overflow: 'hidden', height: '100vh', position: 'sticky', top: 0,
  }}>
    {/* Logo */}
    <div style={{ padding: '20px 16px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: `1px solid ${C.border}` }}>
      <div style={{ width: 36, height: 36, background: C.accent, borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Briefcase size={18} color="#fff" />
      </div>
      {!collapsed && <div style={{ color: C.text, fontWeight: 800, fontSize: 16, whiteSpace: 'nowrap' }}>Moka Admin</div>}
      <button onClick={onToggle} style={{ marginLeft: 'auto', background: 'none', border: 'none', cursor: 'pointer', color: C.muted, flexShrink: 0 }}>
        {collapsed ? <Menu size={16} /> : <X size={16} />}
      </button>
    </div>

    {/* Nav */}
    <nav style={{ flex: 1, padding: '12px 8px' }}>
      {NAV.map(({ id, label, icon: Icon }) => (
        <button key={id} onClick={() => onNav(id)} style={{
          width: '100%', padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10,
          background: active === id ? C.accentDim : 'none',
          border: `1px solid ${active === id ? `${C.accent}40` : 'transparent'}`,
          borderRadius: 10, cursor: 'pointer', marginBottom: 4,
          color: active === id ? C.accent : C.muted,
        }}>
          <Icon size={18} style={{ flexShrink: 0 }} />
          {!collapsed && <span style={{ fontWeight: 600, fontSize: 13, whiteSpace: 'nowrap' }}>{label}</span>}
          {!collapsed && active === id && <ChevronRight size={14} style={{ marginLeft: 'auto' }} />}
        </button>
      ))}
    </nav>

    {/* Admin info + logout */}
    <div style={{ padding: '12px 8px', borderTop: `1px solid ${C.border}` }}>
      {!collapsed && (
        <div style={{ padding: '8px 12px', marginBottom: 8 }}>
          <div style={{ color: C.text, fontWeight: 600, fontSize: 13 }}>{admin?.name}</div>
          <div style={{ color: C.muted, fontSize: 11 }}>{admin?.email}</div>
        </div>
      )}
      <button onClick={onLogout} style={{
        width: '100%', padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10,
        background: 'none', border: 'none', borderRadius: 10, cursor: 'pointer', color: C.red,
      }}>
        <LogOut size={18} style={{ flexShrink: 0 }} />
        {!collapsed && <span style={{ fontWeight: 600, fontSize: 13 }}>Log Out</span>}
      </button>
    </div>
  </div>
);

// ─── APP ──────────────────────────────────────────────────────────────────────
export default function App() {
  const [admin, setAdmin] = useState(null);
  const [page, setPage] = useState('analytics');
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('moka_admin_token');
    if (token) {
      api.getMe().then(r => setAdmin(r.data)).catch(() => localStorage.removeItem('moka_admin_token'));
    }
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('moka_admin_token');
    setAdmin(null);
  };

  if (!admin) return <LoginPage onLogin={setAdmin} />;

  const pages = { analytics: <AnalyticsPage />, users: <UsersPage />, jobs: <JobsPage />, payments: <PaymentsPage /> };

  return (
    <div style={{ display: 'flex', background: C.bg, minHeight: '100vh', fontFamily: "'DM Sans', sans-serif", color: C.text }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { width: 6px; } ::-webkit-scrollbar-track { background: ${C.bg}; } ::-webkit-scrollbar-thumb { background: ${C.border}; border-radius: 3px; }
        @keyframes spin { to { transform: rotate(360deg); } }
        select option { background: ${C.surface}; color: ${C.text}; }
      `}</style>
      <Sidebar active={page} onNav={setPage} admin={admin} onLogout={handleLogout} collapsed={collapsed} onToggle={() => setCollapsed(c => !c)} />
      <main style={{ flex: 1, padding: 28, overflowY: 'auto', minHeight: '100vh' }}>
        {pages[page]}
      </main>
    </div>
  );
}
