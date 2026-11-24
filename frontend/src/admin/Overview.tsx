import { useEffect, useState, type FormEvent } from 'react';
import { api, money, title, type Stats } from './api';
import { Icon, ErrorBox, Grid } from './ui';

type Alert = { key: string; title: string; count: number; filter?: string };
type WorkspaceHealth = {
  alerts?: Alert[];
  summary?: Record<string, number>;
};

type Props = { open: (id: number) => void; go: () => void };

type Range = { start: string; end: string };

const PRESETS: [string, string][] = [
  ['1', 'Today'],
  ['7', 'Last 7 Days'],
  ['30', 'Last 30 Days'],
  ['90', 'Last 90 Days'],
  ['custom', 'Custom Range…'],
];

/** Today's date (YYYY-MM-DD) in the store timezone. */
const storeToday = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Dhaka' });

const shortDay = (value: string) =>
  new Date(value + 'T00:00:00').toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });

export function Overview({ open, go }: Props) {
  const [period, setPeriod] = useState('30');
  const [range, setRange] = useState<Range | null>(null);
  const [draft, setDraft] = useState<Range>({ start: '', end: '' });
  const [stats, setStats] = useState<Stats | null>(null);
  const [health, setHealth] = useState<WorkspaceHealth>({});
  const [error, setError] = useState('');
  const [refresh, setRefresh] = useState(0);

  const custom = period === 'custom';
  const query = custom ? range && `start=${range.start}&end=${range.end}` : `days=${period}`;

  useEffect(() => {
    // A custom range loads only after both dates are applied.
    if (!query) return;
    let live = true;
    setStats(null);
    setError('');
    api<Stats>(`overview/?${query}`)
      .then((result) => {
        if (live) setStats(result);
      })
      .catch((cause: Error) => {
        if (live) setError(cause.message);
      });
    return () => {
      live = false;
    };
  }, [query, refresh]);

  const today = storeToday();
  const draftError =
    draft.start && draft.end && draft.start > draft.end
      ? 'Start date must be on or before the end date.'
      : '';

  function applyRange(event: FormEvent) {
    event.preventDefault();
    if (!draft.start || !draft.end || draftError) return;
    setRange({ ...draft });
  }

  // Wording for the selected reporting window.
  const days = stats?.days ?? Number(period);
  const windowText =
    custom && stats?.start && stats?.end
      ? stats.start === stats.end
        ? `on ${shortDay(stats.start)}`
        : `from ${shortDay(stats.start)} to ${shortDay(stats.end)}`
      : period === '1'
        ? 'today'
        : `in the last ${days} days`;
  const windowLabel =
    custom && stats?.start && stats?.end
      ? stats.start === stats.end
        ? shortDay(stats.start)
        : `${shortDay(stats.start)} – ${shortDay(stats.end)}`
      : PRESETS.find(([value]) => value === period)?.[1] || `Last ${days} Days`;

  useEffect(() => {
    let live = true;
    api<WorkspaceHealth>('workspace/')
      .then((result) => {
        if (live) setHealth(result);
      })
      .catch(() => {
        /* The workspace shell presents access failures. */
      });
    return () => {
      live = false;
    };
  }, [refresh]);

  const alerts = (stats?.alerts || health.alerts || []).filter((alert) => alert.count > 0);
  const maximum = Math.max(1, ...(stats?.series.map((point) => Number(point.value)) || []));

  return (
    <>
      <header className="headline">
        <div>
          <small className="kicker">YOUR STORE, AT A GLANCE</small>
          <h1>
            Store Overview<span className="heading-dot">.</span>
          </h1>
          <p className="page-description">
            A clear view of performance, your team, and what needs attention.
          </p>
        </div>
        <div className="section-actions">
          <button
            className="square"
            aria-label="Refresh dashboard"
            onClick={() => setRefresh((value) => value + 1)}
          >
            <Icon name="refresh" />
          </button>
          <select
            aria-label="Reporting period"
            value={period}
            onChange={(event) => {
              const next = event.target.value;
              setPeriod(next);
              if (next === 'custom' && !draft.start) {
                setDraft({ start: today, end: today });
              }
            }}
          >
            {PRESETS.map(([value, text]) => (
              <option value={value} key={value}>
                {text}
              </option>
            ))}
          </select>
        </div>
      </header>
      {custom && (
        <form className="card range-picker" onSubmit={applyRange}>
          <label>
            <span>From</span>
            <input
              type="date"
              required
              max={draft.end || today}
              value={draft.start}
              onChange={(event) => setDraft((value) => ({ ...value, start: event.target.value }))}
            />
          </label>
          <label>
            <span>To</span>
            <input
              type="date"
              required
              min={draft.start || undefined}
              max={today}
              value={draft.end}
              onChange={(event) => setDraft((value) => ({ ...value, end: event.target.value }))}
            />
          </label>
          <button className="primary" disabled={!draft.start || !draft.end || !!draftError}>
            <Icon name="check" />
            Show Overview
          </button>
          {draftError ? (
            <p className="range-note error">{draftError}</p>
          ) : !range ? (
            <p className="range-note">Pick a start and end date, then select Show Overview.</p>
          ) : null}
        </form>
      )}
      <ErrorBox message={error} />
      {!query ? null : stats ? (
        <>
          <div className="kpis">
            {[
              ['Paid Revenue', money(stats.revenue), 'wallet', 'Paid, non-cancelled orders'],
              [
                'Total Orders',
                stats.orders.toLocaleString(),
                'orders',
                'All orders in this period',
              ],
              ['Average Order Value', money(stats.average), 'chart', 'Average across paid orders'],
              [
                'Awaiting Confirmation',
                stats.pending.toLocaleString(),
                'clock',
                'Pending orders in this period',
              ],
            ].map(([name, value, icon, note]) => (
              <div key={name} className="kpi">
                <span className="iconbox">
                  <Icon name={icon} />
                </span>
                <small>{name}</small>
                <strong>{value}</strong>
                <span className="metric-note">{note}</span>
              </div>
            ))}
          </div>

          <div className="analytics">
            <section className="card revenue-card">
              <div className="cardhead">
                <div>
                  <small className="kicker">PERFORMANCE</small>
                  <h2>Revenue Overview</h2>
                </div>
                <span className="legend">
                  <i /> Paid revenue · BDT
                </span>
              </div>
              <div className="revenue-total">
                {money(stats.revenue)} <span>{windowText}</span>
              </div>
              <div className="chart-area">
                <div className="chart-grid" aria-hidden="true">
                  <i />
                  <i />
                  <i />
                  <i />
                </div>
                <div
                  className="bars"
                  role="img"
                  aria-label={`Daily paid revenue ${windowText}. Total ${money(stats.revenue)}.`}
                >
                  {stats.series.map((point) => (
                    <div
                      tabIndex={0}
                      key={point.date}
                      style={{
                        height: `${Math.max(1.5, (Number(point.value) / maximum) * 100)}%`,
                      }}
                      aria-label={`${point.date}: ${money(point.value)}`}
                    >
                      <span>
                        {new Date(point.date + 'T00:00:00').toLocaleDateString('en-GB', {
                          day: 'numeric',
                          month: 'short',
                        })}
                        <br />
                        {money(point.value)}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
              <div className="axis">
                <span>{stats.series[0]?.date}</span>
                <span>{stats.series[Math.floor(stats.series.length / 2)]?.date}</span>
                <span>{stats.series.at(-1)?.date}</span>
              </div>
              <p className="caption chart-caption">
                Paid order value by the date each order was placed.
              </p>
            </section>
            <section className="card mix">
              <div className="cardhead">
                <div>
                  <small className="kicker">FULFILLMENT</small>
                  <h2>Order Status</h2>
                </div>
                <span className="count-pill">{stats.orders} total</span>
              </div>
              {['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'].map((status) => (
                <div className={`mixrow ${status}`} key={status}>
                  <div>
                    <span>
                      <i className="status-dot" />
                      {title(status)}
                    </span>
                    <b>{stats.states[status] || 0}</b>
                  </div>
                  <i>
                    <em
                      style={{
                        width: `${((stats.states[status] || 0) / Math.max(stats.orders, 1)) * 100}%`,
                      }}
                    />
                  </i>
                </div>
              ))}
              <button className="link fulfillment-link" onClick={go}>
                Manage fulfillment <span>↗</span>
              </button>
            </section>
          </div>

          <div className="analytics dashboard-secondary">
            <section className="card recents">
              <div className="cardhead">
                <div>
                  <small className="kicker">LATEST ACTIVITY</small>
                  <h2>Recent Orders</h2>
                </div>
                <button className="link" onClick={go}>
                  View all →
                </button>
              </div>
              <Grid
                rows={stats.recent}
                columns={['shipping_name', 'status', 'payment_status', 'total_amount']}
                open={open}
              />
            </section>
            <section className="card attention-card">
              <div className="cardhead">
                <div>
                  <small className="kicker">OPERATIONS</small>
                  <h2>Needs Attention</h2>
                </div>
                <span className="iconbox">
                  <Icon name="shield" />
                </span>
              </div>
              <p className="caption">Your current store-wide action queue.</p>
              <div className="attention-list">
                {alerts.length ? (
                  alerts.map((alert, index) => (
                    <button
                      className="attention-item"
                      key={`${alert.key}-${index}`}
                      onClick={() => {
                        location.hash = alert.key + (alert.filter ? '?' + alert.filter : '');
                      }}
                    >
                      <span className="attention-copy">
                        <Icon name={alert.key} />
                        <span>{alert.title}</span>
                      </span>
                      <span className="attention-count">{alert.count}</span>
                      <span aria-hidden="true">↗</span>
                    </button>
                  ))
                ) : (
                  <div className="healthy-state">
                    <span className="iconbox">
                      <Icon name="shield" />
                    </span>
                    <strong>You're All Caught Up</strong>
                    <p>No outstanding alerts in the sections you can access.</p>
                  </div>
                )}
              </div>
            </section>
          </div>

          <section className="card sellers">
            <div className="cardhead">
              <div>
                <small className="kicker">PRODUCT PERFORMANCE</small>
                <h2>Best-Selling Products</h2>
              </div>
              <span className="caption">Ranked by Paid Units · {windowLabel}</span>
            </div>
            {stats.sellers.length ? (
              <div className="tablewrap">
                <table>
                  <thead>
                    <tr>
                      <th>Rank</th>
                      <th>Product</th>
                      <th>Units Sold</th>
                      <th>Performance</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stats.sellers.map((product, index) => (
                      <tr key={product.product_name}>
                        <td>
                          <span className="rank-number">{String(index + 1).padStart(2, '0')}</span>
                        </td>
                        <td>
                          <strong>{product.product_name}</strong>
                        </td>
                        <td>{product.units.toLocaleString()}</td>
                        <td>
                          <div className="seller-bar">
                            <i
                              style={{
                                width: `${(product.units / Math.max(1, stats.sellers[0].units)) * 100}%`,
                              }}
                            />
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="empty">Your best sellers will appear when paid orders are recorded.</p>
            )}
          </section>
          <div className="dashboard-foot">
            <span>
              <Icon name="shield" /> Permission-Aware Workspace
            </span>
            <span>Reports use the store timezone · BDT</span>
          </div>
        </>
      ) : (
        !error && (
          <div className="empty" role="status">
            Preparing your store overview…
          </div>
        )
      )}
    </>
  );
}
