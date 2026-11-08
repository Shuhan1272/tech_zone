import { useEffect, useState, type FormEvent } from 'react';

import { useAuth, useToast } from '../contexts/Store';
import { api } from '../lib/api';
import { useData } from '../lib/data';
import { Link } from '../lib/router';
import type { Address, Page, User } from '../lib/types';
import { asList, errorMessage } from '../lib/utils';

import {
  Breadcrumbs,
  Button,
  Icon,
  Notice,
  PageHeading,
  Spinner,
} from '../components/UI';

// =========================================================
// ACCOUNT PAGE
// =========================================================

export function Account() {
  const auth = useAuth();
  const toast = useToast();

  const [first, setFirst] = useState('');
  const [last, setLast] = useState('');
  const [phone, setPhone] = useState('');

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (auth.user) {
      setFirst(auth.user.first_name);
      setLast(auth.user.last_name);
      setPhone(auth.user.phone || '');
    }
  }, [auth.user]);

  // =======================================================
  // UPDATE PROFILE
  // =======================================================

  const save = async (e: FormEvent) => {
    e.preventDefault();

    setBusy(true);
    setError('');

    try {
      await api<User>('/api/v1/accounts/me/', {
        method: 'PATCH',
        body: {
          first_name: first.trim(),
          last_name: last.trim(),
          phone: phone.trim(),
        },
      });

      await auth.reload();

      toast('Profile updated', 'success');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[{ label: 'My account' }]}
      />

      <PageHeading
        eyebrow="YOUR ACCOUNT"
        title="Account settings"
        description="Manage your personal information and preferences."
      />

      <div className="account-layout">
        {/* ACCOUNT SIDEBAR */}

        <aside className="account-side">
          <div className="account-user-avatar">
            {(
              auth.user?.first_name ||
              auth.user?.email ||
              'T'
            )
              .charAt(0)
              .toUpperCase()}
          </div>

          <h3>
            {auth.user?.first_name || 'TechZone customer'}
          </h3>

          <p>{auth.user?.email}</p>

          <Link to="/orders">
            <Icon name="receipt" size={18} />
            My orders
          </Link>

          <Link to="/wishlist">
            <Icon name="heart" size={18} />
            Wishlist
          </Link>

          <Link to="/account/password">
            <Icon name="lock" size={18} />
            Change password
          </Link>
        </aside>

        {/* PERSONAL INFORMATION */}

        <div className="form-card">
          <h2>Personal information</h2>

          <p>Keep your account details up to date.</p>

          {error && <Notice message={error} />}

          <form
            className="form-grid"
            onSubmit={save}
          >
            <label className="form-field">
              <span>First name</span>

              <input
                required
                value={first}
                onChange={(e) => setFirst(e.target.value)}
              />
            </label>

            <label className="form-field">
              <span>Last name</span>

              <input
                required
                value={last}
                onChange={(e) => setLast(e.target.value)}
              />
            </label>

            <label className="form-field full">
              <span>Email address</span>

              <input
                value={auth.user?.email || ''}
                disabled
              />

              <small>
                Your email address cannot be changed here.
              </small>
            </label>

            <label className="form-field full">
              <span>Phone number</span>

              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
            </label>

            <Button loading={busy}>
              Save changes
              <Icon name="check" size={17} />
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
}

// =========================================================
// DEFAULT ADDRESS
// =========================================================

const blank: Address = {
  first_name: '',
  last_name: '',
  company: '',
  address1: '',
  address2: '',
  city: '',
  postal_code: '',
  country: 'Bangladesh',
  region: '',
};

// =========================================================
// ADDRESS PAGE
// =========================================================

export function AddressPage() {
  const toast = useToast();

  const data = useData(
    'account-address',
    async () =>
      asList<Address>(
        await api<Address[] | Page<Address>>(
          '/api/v1/accounts/address/'
        )
      ),
    [] as Address[]
  );

  const existing = data.data[0];

  const [fields, setFields] = useState<Address>(blank);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (existing) {
      setFields(existing);
    }
  }, [existing?.id]);

  // =======================================================
  // SAVE ADDRESS
  // =======================================================

  const save = async (e: FormEvent) => {
    e.preventDefault();

    setBusy(true);
    setError('');

    try {
      await api(
        `/api/v1/accounts/address/${existing?.id ?? ''}${existing ? '/' : ''}`,
        {
          method: existing ? 'PATCH' : 'POST',
          body: fields,
        }
      );

      data.refresh();

      toast('Address saved', 'success');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  // =======================================================
  // UPDATE ADDRESS FIELD
  // =======================================================

  const change = (key: keyof Address, value: string) => {
    setFields((previous) => ({
      ...previous,
      [key]: value,
    }));
  };

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[
          {
            label: 'My account',
            to: '/account',
          },
          {
            label: 'Address',
          },
        ]}
      />

      <PageHeading
        eyebrow="ADDRESS DETAILS"
        title="Address"
        description="Please provide your address where you live. Note : You can use different addresses for shipping during checkout."
      />

      {data.loading ? (
        <Spinner label="Loading address..." />
      ) : (
        <div className="form-card account-form-wide">
          {error && <Notice message={error} />}

          <form
            className="form-grid"
            onSubmit={save}
          >
            {(
              [
                ['first_name', 'First name'],
                ['last_name', 'Last name'],
                ['company', 'Company (optional)'],
                ['address1', 'Address line 1'],
                ['address2', 'Address line 2 (optional)'],
                ['city', 'City'],
                ['region', 'Division / region'],
                ['postal_code', 'Postal code'],
                ['country', 'Country'],
              ] as [keyof Address, string][]
            ).map(([key, label]) => (
              <label
                key={key}
                className={`form-field ${
                  key === 'address1' || key === 'address2'
                    ? 'full'
                    : ''
                }`}
              >
                <span>{label}</span>

                <input
                  required={
                    !['company', 'address2'].includes(key)
                  }
                  value={String(fields[key] ?? '')}
                  onChange={(e) =>
                    change(key, e.target.value)
                  }
                />
              </label>
            ))}

            <div className="full">
              <Button loading={busy}>
                Save address
                <Icon name="check" size={17} />
              </Button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}

// =========================================================
// CHANGE PASSWORD PAGE
// =========================================================

export function ChangePassword() {
  const toast = useToast();

  const [old, setOld] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  // =======================================================
  // UPDATE PASSWORD
  // =======================================================

  const submit = async (e: FormEvent) => {
    e.preventDefault();

    if (next !== confirm) {
      setError('New passwords do not match.');
      return;
    }

    setBusy(true);
    setError('');

    try {
      await api('/api/v1/accounts/change-password/', {
        method: 'POST',
        body: {
          current_password: old,
          new_password: next,
          new_password2: confirm,
        },
      });

      setOld('');
      setNext('');
      setConfirm('');

      toast('Password updated successfully', 'success');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[
          {
            label: 'My account',
            to: '/account',
          },
          {
            label: 'Change password',
          },
        ]}
      />

      <PageHeading
        eyebrow="ACCOUNT SECURITY"
        title="Change password"
        description="Keep your account secure with a strong password."
      />

      <div className="form-card account-form-wide">
        {error && <Notice message={error} />}

        <form
          className="auth-form"
          onSubmit={submit}
        >
          <label className="form-field">
            <span>Current password</span>

            <input
              type="password"
              required
              autoComplete="current-password"
              value={old}
              onChange={(e) => setOld(e.target.value)}
            />
          </label>

          <label className="form-field">
            <span>New password</span>

            <input
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={next}
              onChange={(e) => setNext(e.target.value)}
            />
          </label>

          <label className="form-field">
            <span>Confirm new password</span>

            <input
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
            />
          </label>

          <Button loading={busy}>
            Update password
          </Button>
        </form>
      </div>
    </div>
  );
}