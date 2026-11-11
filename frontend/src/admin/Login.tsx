import { useState, type FormEvent } from 'react';
import { api, sessionKey } from './api';
import { Icon, Brand, ErrorBox } from './ui';

export function Login({ done, expired }: { done: () => void; expired: boolean }) {
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [visible, setVisible] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');

    try {
      const data = Object.fromEntries(new FormData(event.currentTarget));
      const response = await api<{ token: string }>('login/', {
        method: 'POST',
        body: JSON.stringify(data),
      });
      sessionStorage.setItem(sessionKey, response.token);
      done();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="login">
      <section className="login-story" aria-label="TechZone operations">
        <Brand />
        <div className="login-story-copy">
          <span className="login-eyebrow">
            <span /> YOUR STORE. CONNECTED.
          </span>
          <h1>
            Great operations.
            <br />
            <em>Better business.</em>
          </h1>
          <p>A focused workspace for the people, products, and decisions behind your store.</p>
          <div className="login-capabilities">
            <div>
              <Icon name="team" />
              <span>
                <b>People & access</b>
                <small>Staff status, roles, and permissions</small>
              </span>
              <Icon name="check" />
            </div>
            <div>
              <Icon name="orders" />
              <span>
                <b>Everyday operations</b>
                <small>Orders, inventory, and customers</small>
              </span>
              <Icon name="check" />
            </div>
            <div>
              <Icon name="activity" />
              <span>
                <b>A clear view of your store</b>
                <small>Performance, activity, and insights</small>
              </span>
              <Icon name="check" />
            </div>
          </div>
        </div>
        <p className="login-story-footer">
          TECHZONE <span>OPERATIONS WORKSPACE</span>
        </p>
      </section>
      <section className="login-form-side">
        <div className="signin">
          <div className="login-mobile-brand">
            <Brand />
          </div>
          <span className="signin-icon">
            <Icon name="lock" />
          </span>
          <small className="kicker">ADMIN ACCESS</small>
          <h2>Welcome back.</h2>
          <p>Sign in to manage your TechZone store.</p>
          {expired && (
            <div className="session-notice" role="status">
              Your session has expired. Sign in to continue.
            </div>
          )}
          <form onSubmit={submit}>
            <label htmlFor="admin-email">Email address</label>
            <input
              id="admin-email"
              autoComplete="username"
              name="email"
              required
              type="email"
              placeholder="you@techzone.com"
              autoFocus
              disabled={busy}
            />
            <label htmlFor="admin-password">Password</label>
            <div className="password-field">
              <input
                id="admin-password"
                name="password"
                type={visible ? 'text' : 'password'}
                required
                autoComplete="current-password"
                placeholder="Enter your password"
                disabled={busy}
              />
              <button
                type="button"
                className="password-toggle"
                aria-label={visible ? 'Hide password' : 'Show password'}
                aria-pressed={visible}
                onClick={() => setVisible(!visible)}
              >
                <Icon name={visible ? 'eyeoff' : 'eye'} />
              </button>
            </div>
            <ErrorBox message={error} />
            <button className="primary" disabled={busy} type="submit">
              {busy ? 'Signing in…' : 'Sign in to workspace'}
              <Icon name="arrow" />
            </button>
          </form>
          <div className="signin-help">
            <Icon name="shield" />
            <span>For authorized staff only. Contact your workspace owner if you need access.</span>
          </div>
        </div>
        <p className="login-copyright">
          © {new Date().getFullYear()} TechZone. All rights reserved.
        </p>
      </section>
    </main>
  );
}
