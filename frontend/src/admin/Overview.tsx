import { useEffect, useState } from 'react';
import { api, money, title, type Stats } from './api';
import { Icon, ErrorBox, Grid } from './ui';

type Alert = { key: string; title: string; count: number; filter?: string };
type WorkspaceHealth = {
  alerts?: Alert[];
  summary?: Record<string, number>;
};

type Props = { open: (id: number) => void; go: () => void };

export function Overview({ open, go }: Props) {
  const [days, setDays] = useState('30');
  const [stats, setStats] = useState<Stats | null>(null);
  const [health, setHealth] = useState<WorkspaceHealth>({});
  const [error, setError] = useState('');
  const [refresh, setRefresh] = useState(0);

  useEffect(() => {
    let live = true;
    setStats(null);
    setError('');
    api<Stats>(`overview/?days=${days}`)
      .then((result) => {
        if (live) setStats(result);
      })
      .catch((cause: Error) => {
        if (live) setError(cause.message);
      });
    return () => {
      live = false;
    };
  }, [days, refresh]);

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
            Store overview<span className="heading-dot">.</span>
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
            value={days}
            onChange={(event) => setDays(event.target.value)}
          >
            {[7, 30, 90].map((period) => (
              <option value={period} key={period}>
                Last {period} days
              </option>
            ))}
          </select>
        </div>
      </header>
      <ErrorBox message={error} />
      {stats ? (
        <>
          <div className="kpis">
            {[
              ['Paid revenue', money(stats.revenue), 'wallet', 'Paid, non-cancelled orders'],
              [
                'Total orders',
                stats.orders.toLocaleString(),
                'orders',
                'All orders in this period',
              ],
              ['Average order value', money(stats.average), 'chart', 'Average across paid orders'],
              [
                'Awaiting confirmation',
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
                  <h2>Revenue overview</h2>
                </div>
                <span className="legend">
                  <i /> Paid revenue · BDT
                </span>
              </div>
              <div className="revenue-total">
                {money(stats.revenue)} <span>in the last {days} days</span>
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
                  aria-label={`Daily paid revenue for the last ${days} days. Total ${money(stats.revenue)}.`}
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
                  <h2>Order status</h2>
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
                  <h2>Recent orders</h2>
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
                  <h2>Needs attention</h2>
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
                    <strong>You're all caught up</strong>
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
                <h2>Best-selling products</h2>
              </div>
              <span className="caption">Ranked by paid units · Last {days} days</span>
            </div>
            {stats.sellers.length ? (
              <div className="tablewrap">
                <table>
                  <thead>
                    <tr>
                      <th>Rank</th>
                      <th>Product</th>
                      <th>Units sold</th>
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
              <Icon name="shield" /> Permission-aware workspace
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
