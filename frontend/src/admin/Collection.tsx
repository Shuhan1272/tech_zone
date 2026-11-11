import { useEffect, useState } from 'react';
import { api, label, type Section, type List } from './api';
import { downloadRecords } from './export';
import { ErrorBox, Grid, Icon } from './ui';

const descriptions: Record<string, string> = {
  orders:
    'Follow every order from confirmation to delivery, with payment and shipping details in one place.',
  payments:
    'Review transactions, verify payment status, and resolve payments that need your attention.',
  refunds:
    'Manage refund requests, approvals, and gateway reconciliation with a clear review process.',
  products: 'Keep your catalog organized, accurate, and ready for customers.',
  variants: 'Manage prices, availability, and stock across every product variation.',
  categories: 'Build a clear catalog structure and manage category visibility.',
  brands: 'Manage the brands customers discover in your store.',
  images: 'Curate product photography, primary images, and display order.',
  colors: 'Maintain consistent color names and swatches across your catalog.',
  discounts: 'Create promotions, set eligibility, and control usage and campaign dates.',
  notices: 'Publish store announcements and schedule the messages customers see.',
  reviews: 'Review customer feedback and choose what appears on your storefront.',
  questions: 'Answer product questions and manage their visibility.',
  customers: 'Find customer accounts and manage their account access.',
  addresses: 'View the delivery details saved by your customers.',
  carts: 'Inspect active shopping carts and the items customers are considering.',
  wishlists: 'View customer wishlists and their sharing status.',
  mappings: 'Connect catalog categories to the right PC builder components.',
  builds: 'Explore saved configurations and their component selections.',
  team: 'Manage your team, assign roles, and keep account access up to date.',
  roles: 'Create reusable permission sets so every team member has the access their work needs.',
  activity: 'A permanent history of changes made through your operations console.',
};

type Props = {
  section: Section;
  open: (id: string) => void;
  revision: number;
  initialFilters?: Record<string, string>;
};

export function Collection({ section, open, revision, initialFilters = {} }: Props) {
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [filters, setFilters] = useState<Record<string, string>>(initialFilters);
  const [ordering, setOrdering] = useState('');
  const [data, setData] = useState<List | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let live = true;
    setLoading(true);
    setError('');
    const timer = setTimeout(() => {
      const params = new URLSearchParams({
        ...filters,
        q: query,
        page: String(page),
        ordering,
      });
      api<List>(`resources/${section.key}/?${params}`)
        .then((result) => {
          if (live) setData(result);
        })
        .catch((cause: Error) => {
          if (live) setError(cause.message);
        })
        .finally(() => {
          if (live) setLoading(false);
        });
    }, 200);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [section.key, query, page, filters, ordering, revision]);

  const filtered = Boolean(query || Object.values(filters).some(Boolean));
  const summary = data?.summary;
  const columns =
    section.key === 'roles' ? ['name', 'permission_count', 'member_count'] : data?.columns || [];
  const createLabel =
    section.key === 'team'
      ? 'Add staff member'
      : section.key === 'roles'
        ? 'Create role'
        : 'Add record';

  function resetFilters() {
    setQuery('');
    setFilters({});
    setPage(1);
  }

  return (
    <>
      <header className="headline">
        <div>
          <small className="kicker">{section.group} / Workspace</small>
          <h1>{section.title}</h1>
          <p className="page-description">
            {descriptions[section.key] ||
              `Manage your ${section.title.toLowerCase()} in one place.`}
          </p>
        </div>
        <div className="section-actions">
          <button
            disabled={!data?.rows.length || loading || Boolean(error)}
            onClick={() => data && downloadRecords(data.rows, columns, section.key)}
          >
            <Icon name="download" /> Export page
          </button>
          {data?.create && (
            <button className="primary" onClick={() => open('new')}>
              + {createLabel}
            </button>
          )}
        </div>
      </header>

      {section.key === 'team' && summary && (
        <div className="stat-grid" aria-label="Staff account summary">
          {[
            ['Total staff', summary.total ?? summary.total_staff ?? data?.count ?? 0, 'team'],
            ['Active accounts', summary.active ?? summary.active_staff ?? 0, 'shield'],
            ['Suspended accounts', summary.inactive ?? summary.inactive_staff ?? 0, 'clock'],
          ].map(([name, value, icon]) => (
            <div className="status-tile" key={name}>
              <span className="iconbox">
                <Icon name={String(icon)} />
              </span>
              <div>
                <small>{name}</small>
                <strong>{value}</strong>
              </div>
            </div>
          ))}
        </div>
      )}

      {['team', 'roles'].includes(section.key) && (
        <div className="access-notice">
          <span className="iconbox">
            <Icon name="shield" />
          </span>
          <div>
            <strong>
              {section.key === 'team'
                ? 'The right access for every person'
                : 'Define once. Assign across your team.'}
            </strong>
            <p>
              {section.key === 'team'
                ? 'Use roles for shared responsibilities and additional permissions for exceptions. Suspending an account immediately blocks access.'
                : 'Combine view, add, change, and delete permissions by responsibility. Changes to a role apply to all staff assigned to it.'}
            </p>
          </div>
        </div>
      )}

      <section className="card records" aria-busy={loading}>
        <div className="cardhead collection-heading">
          <div>
            <h2>
              {section.key === 'team'
                ? 'Team directory'
                : section.key === 'roles'
                  ? 'Your roles'
                  : `All ${section.title.toLowerCase()}`}
            </h2>
            <p className="caption">
              {data
                ? `${data.count.toLocaleString()} ${filtered ? 'matching ' : ''}record${data.count === 1 ? '' : 's'}`
                : 'Your workspace records'}
            </p>
          </div>
          <span className="table-hint">Select a record to view details</span>
        </div>
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" />
            <input
              type="search"
              aria-label={`Search ${section.title}`}
              placeholder={`Search ${section.title.toLowerCase()}…`}
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setPage(1);
              }}
            />
          </label>
          {Object.entries(data?.filters || {}).map(([key, options]) => (
            <select
              key={key}
              aria-label={label(key)}
              value={filters[key] || ''}
              onChange={(event) => {
                setFilters((current) => ({
                  ...current,
                  [key]: event.target.value,
                }));
                setPage(1);
              }}
            >
              <option value="">{label(key)}: All</option>
              {options.map(([value, text]) => (
                <option key={value} value={value}>
                  {text}
                </option>
              ))}
            </select>
          ))}
          <select
            aria-label="Sort records"
            value={ordering}
            onChange={(event) => {
              setOrdering(event.target.value);
              setPage(1);
            }}
          >
            <option value="">Newest first</option>
            <option value="id">Oldest first</option>
            {(data?.sortable || data?.columns || [])
              .filter((field) => !['groups', 'permissions', 'id'].includes(field))
              .map((field) => (
                <option value={field} key={field}>
                  {label(field)}: ascending
                </option>
              ))}
          </select>
          {filtered && (
            <button className="link" onClick={resetFilters}>
              Clear filters
            </button>
          )}
        </div>
        <ErrorBox message={error} />
        {loading ? (
          <div className="empty loading-records" role="status">
            <span className="loading-dot" /> Loading records…
          </div>
        ) : (
          data &&
          !error && (
            <>
              {data.rows.length ? (
                <Grid rows={data.rows} columns={columns} open={(id) => open(String(id))} />
              ) : (
                <div className="empty collection-empty">
                  <span className="iconbox">
                    <Icon name={section.key} />
                  </span>
                  <h3>{filtered ? 'No matching records' : 'A fresh start'}</h3>
                  <p>
                    {filtered
                      ? 'Try another search or clear your filters to see more records.'
                      : `Your ${section.title.toLowerCase()} will appear here.`}
                  </p>
                  {filtered ? (
                    <button onClick={resetFilters}>Clear filters</button>
                  ) : (
                    data.create && (
                      <button className="primary" onClick={() => open('new')}>
                        {createLabel}
                      </button>
                    )
                  )}
                </div>
              )}
              <footer>
                <span>
                  {data.count
                    ? `${(data.page - 1) * 20 + 1}–${Math.min(data.page * 20, data.count)} of ${data.count.toLocaleString()}`
                    : '0 records'}{' '}
                  <span className="export-hint">· Export includes this page</span>
                </span>
                <div>
                  <button
                    disabled={data.page <= 1}
                    onClick={() => setPage(data.page - 1)}
                    aria-label="Previous page"
                  >
                    ← Previous
                  </button>
                  <span>
                    Page {data.page} of {data.pages}
                  </span>
                  <button
                    disabled={data.page >= data.pages}
                    onClick={() => setPage(data.page + 1)}
                    aria-label="Next page"
                  >
                    Next →
                  </button>
                </div>
              </footer>
            </>
          )
        )}
      </section>
    </>
  );
}
