import { useEffect, useState } from 'react';
import { api, sessionKey, type Section } from './api';
import { Icon, Brand, ErrorBox } from './ui';
import { Login } from './Login';
import { Overview } from './Overview';
import { Editor } from './Editor';
import { Collection } from './Collection';

type Workspace = {
  sections: Section[];
  email: string;
  name?: string;
  role?: string;
  can_overview?: boolean;
  is_superuser?: boolean;
};

export function Console() {
  const [signed, setSigned] = useState(!!sessionStorage.getItem(sessionKey));
  const [expired, setExpired] = useState(false);
  const [workspace, setWorkspace] = useState<Workspace | null>(null);
  const [error, setError] = useState('');
  const [menu, setMenu] = useState(false);
  const [compact, setCompact] = useState(window.matchMedia('(max-width: 760px)').matches);
  const [navigationSearch, setNavigationSearch] = useState('');
  const [route, setRoute] = useState(location.hash.slice(1));
  const [revision, setRevision] = useState(0);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const expire = () => {
      setExpired(true);
      setSigned(false);
      setWorkspace(null);
    };
    const navigate = () => {
      setRoute(location.hash.slice(1));
      setMenu(false);
      setMessage('');
    };
    window.addEventListener('ops-expired', expire);
    window.addEventListener('hashchange', navigate);
    return () => {
      window.removeEventListener('ops-expired', expire);
      window.removeEventListener('hashchange', navigate);
    };
  }, []);

  useEffect(() => {
    if (!signed) return;
    let live = true;
    setError('');
    api<Workspace>('workspace/')
      .then((data) => live && setWorkspace(data))
      .catch((err) => live && setError(err.message));
    return () => {
      live = false;
    };
  }, [signed, revision]);

  useEffect(() => {
    if (!message) return;
    const timer = setTimeout(() => setMessage(''), 4000);
    return () => clearTimeout(timer);
  }, [message]);

  useEffect(() => {
    const media = window.matchMedia('(max-width: 760px)');
    const updateLayout = () => setCompact(media.matches);
    media.addEventListener('change', updateLayout);
    return () => media.removeEventListener('change', updateLayout);
  }, []);

  useEffect(() => {
    if (!menu) return;
    const closeMenu = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setMenu(false);
    };
    window.addEventListener('keydown', closeMenu);
    return () => window.removeEventListener('keydown', closeMenu);
  }, [menu]);

  if (!signed) {
    return (
      <Login
        expired={expired}
        done={() => {
          setExpired(false);
          setSigned(true);
        }}
      />
    );
  }

  const sections = workspace?.sections || [];
  const analytics = workspace?.can_overview ?? sections.some((section) => section.key === 'orders');
  const [recordRoute, queryString = ''] = route.split('?');
  const [key, id] = recordRoute.split('/');
  const section =
    sections.find((item) => item.key === key) || (!analytics ? sections[0] : undefined);
  const name = workspace?.name || workspace?.email?.split('@')[0] || 'Team member';
  const role = workspace?.role || 'Staff workspace';
  const groups = Array.from(new Set(sections.map((item) => item.group)));
  const filteredSections = sections.filter((item) =>
    `${item.title} ${item.group}`.toLowerCase().includes(navigationSearch.toLowerCase()),
  );
  const today = new Date().toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Dhaka',
  });
  const go = (value: string) => {
    location.hash = value;
  };

  function signOut() {
    sessionStorage.removeItem(sessionKey);
    setSigned(false);
    setWorkspace(null);
    setExpired(false);
    setMenu(false);
  }

  return (
    <div className="shell">
      <a
        className="skip-link"
        href="#workspace-content"
        onClick={(event) => {
          event.preventDefault();
          document.getElementById('workspace-content')?.focus();
        }}
      >
        Skip to content
      </a>
      {menu && (
        <button className="scrim" aria-label="Close navigation" onClick={() => setMenu(false)} />
      )}
      <aside className={menu ? 'shown' : ''} id="admin-navigation" aria-label="Main navigation">
        <div className="sidebar-brand">
          <Brand />
          <button
            className="mobile icon-button sidebar-close"
            aria-label="Close navigation"
            onClick={() => setMenu(false)}
          >
            <Icon name="close" />
          </button>
        </div>
        <div className="workspace-label">
          <span className="workspace-avatar">TZ</span>
          <span>
            <b>TechZone Store</b>
            <small>Operations workspace</small>
          </span>
          <Icon name="chevron" />
        </div>
        <label className="nav-search">
          <Icon name="search" />
          <span className="sr-only">Find a section</span>
          <input
            type="search"
            placeholder="Find a section…"
            value={navigationSearch}
            onChange={(event) => setNavigationSearch(event.target.value)}
          />
        </label>
        <nav aria-label="Workspace sections">
          {analytics &&
            (!navigationSearch ||
              'overview dashboard'.includes(navigationSearch.toLowerCase())) && (
              <div className="nav-group">
                <small>Workspace</small>
                <button
                  className={!section ? 'active' : ''}
                  aria-current={!section ? 'page' : undefined}
                  onClick={() => go('overview')}
                >
                  <Icon name="overview" />
                  <span>Overview</span>
                  {!section && <i />}
                </button>
              </div>
            )}
          {groups.map((group) => {
            const items = filteredSections.filter((item) => item.group === group);
            return items.length ? (
              <div className="nav-group" key={group}>
                <small>{group}</small>
                {items.map((item) => (
                  <button
                    className={section?.key === item.key ? 'active' : ''}
                    aria-current={section?.key === item.key ? 'page' : undefined}
                    key={item.key}
                    onClick={() => go(item.key)}
                  >
                    <Icon name={item.key} />
                    <span>{item.title}</span>
                    {section?.key === item.key && <i />}
                  </button>
                ))}
              </div>
            ) : null;
          })}
          {navigationSearch &&
            !filteredSections.length &&
            !'overview dashboard'.includes(navigationSearch.toLowerCase()) && (
              <p className="nav-empty">No matching sections.</p>
            )}
        </nav>
        <div className="sidebar-footer">
          <span className="account-avatar">{name.slice(0, 1).toUpperCase()}</span>
          <span className="sidebar-account">
            <b>{name}</b>
            <small>{role}</small>
          </span>
          <button
            className="logout icon-button"
            aria-label="Sign out"
            title="Sign out"
            onClick={signOut}
          >
            <Icon name="exit" />
          </button>
        </div>
      </aside>
      <main className="workspace" inert={compact && menu}>
        <header className="top">
          <div className="breadcrumbs">
            <button
              className="mobile icon-button"
              aria-label="Open navigation"
              aria-expanded={menu}
              aria-controls="admin-navigation"
              onClick={() => setMenu(true)}
            >
              <Icon name="menu" />
            </button>
            <span>Workspace</span>
            <Icon name="chevron" />
            <b>{section?.title || 'Overview'}</b>
          </div>
          <div className="top-account">
            <time className="today" dateTime={new Date().toISOString().slice(0, 10)}>
              {today}
            </time>
            <span className="top-divider" />
            <span className="identity">
              <span className="account-avatar">{name.slice(0, 1).toUpperCase()}</span>
              <span>
                <b>{name}</b>
                <small>{role}</small>
              </span>
            </span>
          </div>
        </header>
        <div className="content" id="workspace-content" tabIndex={-1}>
          <ErrorBox message={error} />
          {message && (
            <div className="toast" role="status">
              <Icon name="check" />
              {message}
            </div>
          )}
          {!workspace ? (
            !error && (
              <div className="workspace-loading">
                <span className="loading-spinner" />
                <p>Opening your workspace…</p>
              </div>
            )
          ) : section ? (
            <Collection
              key={`${section.key}?${queryString}`}
              initialFilters={Object.fromEntries(new URLSearchParams(queryString))}
              section={section}
              revision={revision}
              open={(recordId) => go(section.key + '/' + recordId)}
            />
          ) : analytics ? (
            <Overview open={(recordId) => go('orders/' + recordId)} go={() => go('orders')} />
          ) : (
            <section className="card empty-state permission-empty">
              <span className="empty-icon">
                <Icon name="shield" />
              </span>
              <h1>Your workspace is ready</h1>
              <p>
                Ask your workspace owner to assign a role or permissions so you can start managing
                your store.
              </p>
            </section>
          )}
          <footer className="workspace-footer">
            <span>© {new Date().getFullYear()} TechZone</span>
            <span>
              <Icon name="lock" /> Staff operations workspace
            </span>
          </footer>
        </div>
      </main>
      {id && section && (
        <Editor
          key={route}
          section={section}
          id={id}
          close={() => go(section.key)}
          saved={(text) => {
            go(section.key);
            setRevision((value) => value + 1);
            setTimeout(() => setMessage(text), 50);
          }}
        />
      )}
    </div>
  );
}
