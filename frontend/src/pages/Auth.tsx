
import { useState, type FormEvent, type ReactNode } from 'react';
import { useAuth, useToast } from '../contexts/Store';
import { api } from '../lib/api';
import { Link, navigate, useRoute } from '../lib/router';
import { errorMessage, safeNext } from '../lib/utils';
import { Button, Icon, Notice } from '../components/UI';

// Password validation rules
function getPasswordRules(password: string) {
  const lowercase = /[a-z]/.test(password);
  const uppercase = /[A-Z]/.test(password);
  const number = /[0-9]/.test(password);
  const special = /[^A-Za-z0-9]/.test(password);

  const categoryCount = [
    lowercase,
    uppercase,
    number,
    special,
  ].filter(Boolean).length;

  return {
    length: password.length >= 8,
    lowercase,
    uppercase,
    number,
    special,
    categories: categoryCount >= 3,
    valid: password.length >= 8 && categoryCount >= 3,
  };
}

// Authentication page layout
function AuthLayout({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="auth-page">
      <div className="auth-page-visual">
        <div className="auth-visual-content">
          <span className="eyebrow">
            WELCOME TO TECHZONE
          </span>

          <h2>
            Good tech.
            <br />
            Great experiences.
          </h2>

          <p>
            Your account brings together your orders,
            saved favorites, and everything you need
            for a better shopping experience.
          </p>

          <div className="auth-visual-benefits">
            <div>
              <Icon name="shield-check" size={21} />
              Secure shopping
            </div>

            <div>
              <Icon name="truck" size={21} />
              Order tracking
            </div>

            <div>
              <Icon name="heart" size={21} />
              Saved favorites
            </div>
          </div>
        </div>

        <div className="auth-visual-orbit" />
      </div>

      <div className="auth-form-side">
        <div className="auth-card">
          <Link to="/" className="auth-back">
            <Icon name="left" size={16} />
            Back to shop
          </Link>

          <div className="auth-card-heading">
            <span className="auth-heading-icon">
              <Icon name="lock" size={23} />
            </span>

            <h1>{title}</h1>
            <p>{subtitle}</p>
          </div>

          {children}

          {footer && (
            <div className="auth-footer">
              {footer}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// Individual password checklist item
function PasswordRule({
  passed,
  children,
}: {
  passed: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={`password-rule ${passed ? 'passed' : 'pending'}`}
    >
      <span className="password-rule-icon">
        {passed ? '✓' : '•'}
      </span>

      <span>{children}</span>
    </div>
  );
}

// Live password validation checklist
function PasswordChecklist({
  password,
}: {
  password: string;
}) {
  const rules = getPasswordRules(password);

  return (
    <div className="password-checklist">
      <p className="password-checklist-title">
        Your password must contain:
      </p>

      <PasswordRule passed={rules.length}>
        At least 8 characters
      </PasswordRule>

      <PasswordRule passed={rules.categories}>
        At least 3 of the following:
      </PasswordRule>

      <div className="password-rule-subitems">
        <PasswordRule passed={rules.lowercase}>
          Lowercase letters (a-z)
        </PasswordRule>

        <PasswordRule passed={rules.uppercase}>
          Uppercase letters (A-Z)
        </PasswordRule>

        <PasswordRule passed={rules.number}>
          Numbers (0-9)
        </PasswordRule>

        <PasswordRule passed={rules.special}>
          Special characters (e.g. !@#$%^&*)
        </PasswordRule>
      </div>
    </div>
  );
}

// Reusable password input
function PasswordInput({
  value,
  onChange,
  label = 'Password',
  autoComplete = 'current-password',
  showChecklist = false,
  minLength,
}: {
  value: string;
  onChange: (v: string) => void;
  label?: string;
  autoComplete?: string;
  showChecklist?: boolean;
  minLength?: number;
}) {
  const [visible, setVisible] = useState(false);
  const [focused, setFocused] = useState(false);

  return (
    <div className="form-field">
      <label className="password-field-label">
        <span>{label}</span>

        <div className="password-wrap">
          <input
            required
            minLength={minLength}
            type={visible ? 'text' : 'password'}
            autoComplete={autoComplete}
            value={value}
            onChange={e => onChange(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            placeholder={`Enter ${label.toLowerCase()}`}
          />

          <button
            type="button"
            aria-label={
              visible ? 'Hide password' : 'Show password'
            }
            onClick={() => setVisible(v => !v)}
          >
            <Icon
              name={visible ? 'eye-off' : 'eye'}
              size={19}
            />
          </button>
        </div>
      </label>

      {showChecklist && focused && value.length > 0 && (
        <PasswordChecklist password={value} />
      )}
    </div>
  );
}

// Login page
export function Login() {
  const route = useRoute();
  const auth = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const next = safeNext(
    new URLSearchParams(route.search).get('next')
  );

  const submit = async (e: FormEvent) => {
    e.preventDefault();

    if (busy) return;

    setBusy(true);
    setError('');

    try {
      await auth.login(email, password);
      navigate(next);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthLayout
      title="Welcome back"
      subtitle="Sign in to your account and pick up right where you left off."
      footer={
        <>
          New to TechZone?{' '}
          <Link to="/register">
            Create an account
          </Link>
        </>
      }
    >
      <form onSubmit={submit} className="auth-form">
        {error && <Notice message={error} />}

        <label className="form-field">
          <span>Email address</span>

          <input
            type="email"
            required
            autoComplete="email"
            placeholder="you@example.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
          />
        </label>

        <PasswordInput
          value={password}
          onChange={setPassword}
        />

        <div className="form-link-right">
          <Link to="/forgot-password">
            Forgot password?
          </Link>
        </div>

        <Button
          loading={busy}
          className="full-width"
        >
          Sign in
          <Icon name="arrow" size={18} />
        </Button>
      </form>

      {error.toLowerCase().includes('verify') && (
        <Link
          className="auth-extra-link"
          to={`/verify-email?email=${encodeURIComponent(email)}`}
        >
          Verify your email instead
        </Link>
      )}
    </AuthLayout>
  );
}

// Registration page
export function Register() {
  const [fields, setFields] = useState({
    first_name: '',
    last_name: '',
    email: '',
    phone: '',
    password: '',
    password2: '',
  });

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const change = (
    key: keyof typeof fields,
    value: string
  ) => {
    setFields(s => ({
      ...s,
      [key]: value,
    }));
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();

    if (busy) return;

    if (!getPasswordRules(fields.password).valid) {
      setError(
        'Password must contain at least 8 characters and 3 of the 4 character types.'
      );
      return;
    }

    if (fields.password !== fields.password2) {
      setError('Passwords do not match.');
      return;
    }

    setBusy(true);
    setError('');

    try {
      await api('/api/v1/accounts/register/', {
        method: 'POST',
        auth: false,
        body: fields,
      });

      navigate(
        `/verify-email?email=${encodeURIComponent(fields.email.trim())}`
      );
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthLayout
      title="Create your account"
      subtitle="Join TechZone for a faster, easier way to shop."
      footer={
        <>
          Already have an account?{' '}
          <Link to="/login">
            Sign in
          </Link>
        </>
      }
    >
      <form
        className="auth-form"
        onSubmit={submit}
      >
        {error && <Notice message={error} />}

        <div className="form-two-col">
          <label className="form-field">
            <span>First name</span>

            <input
              required
              autoComplete="given-name"
              value={fields.first_name}
              onChange={e =>
                change('first_name', e.target.value)
              }
              placeholder="First name"
            />
          </label>

          <label className="form-field">
            <span>Last name</span>

            <input
              required
              autoComplete="family-name"
              value={fields.last_name}
              onChange={e =>
                change('last_name', e.target.value)
              }
              placeholder="Last name"
            />
          </label>
        </div>

        <label className="form-field">
          <span>Email address</span>

          <input
            required
            type="email"
            autoComplete="email"
            value={fields.email}
            onChange={e =>
              change('email', e.target.value)
            }
            placeholder="you@example.com"
          />
        </label>

        <label className="form-field">
          <span>Phone number</span>

          <input
            required
            type="tel"
            autoComplete="tel"
            value={fields.phone}
            onChange={e =>
              change('phone', e.target.value)
            }
            placeholder="01XXXXXXXXX"
          />
        </label>

        <PasswordInput
          value={fields.password}
          onChange={v => change('password', v)}
          autoComplete="new-password"
          showChecklist
          minLength={8}
        />

        <PasswordInput
          label="Confirm password"
          value={fields.password2}
          onChange={v => change('password2', v)}
          autoComplete="new-password"
          minLength={8}
        />

        <Button
          loading={busy}
          className="full-width"
        >
          Create account
          <Icon name="arrow" size={18} />
        </Button>

        <p className="form-note">
          We'll email you a 6-digit code to verify your account.
        </p>
      </form>
    </AuthLayout>
  );
}

// Email verification page
export function VerifyEmail() {
  const route = useRoute();
  const auth = useAuth();
  const toast = useToast();

  const [email, setEmail] = useState(
    new URLSearchParams(route.search).get('email') || ''
  );

  const [otp, setOtp] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e: FormEvent) => {
    e.preventDefault();

    setBusy(true);
    setError('');

    try {
      const result = await api<{
        access: string;
        refresh: string;
      }>('/api/v1/accounts/verify-email/', {
        method: 'POST',
        auth: false,
        body: {
          email: email.trim(),
          otp: otp.trim(),
        },
      });

      await auth.acceptTokens(
        result.access,
        result.refresh
      );

      toast(
        'Email verified successfully',
        'success'
      );

      navigate('/');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  const resend = async () => {
    try {
      await api('/api/v1/accounts/resend-email-otp/', {
        method: 'POST',
        auth: false,
        body: {
          email: email.trim(),
        },
      });

      toast(
        'A new verification code has been sent',
        'success'
      );
    } catch (e) {
      setError(errorMessage(e));
    }
  };

  return (
    <AuthLayout
      title="Verify your email"
      subtitle="Enter the six-digit verification code we sent to your inbox."
      footer={
        <Link to="/login">
          Back to sign in
        </Link>
      }
    >
      <form
        className="auth-form"
        onSubmit={submit}
      >
        {error && <Notice message={error} />}

        <label className="form-field">
          <span>Email address</span>

          <input
            type="email"
            required
            value={email}
            onChange={e =>
              setEmail(e.target.value)
            }
          />
        </label>

        <label className="form-field">
          <span>Verification code</span>

          <input
            required
            inputMode="numeric"
            pattern="[0-9]{6}"
            maxLength={6}
            value={otp}
            onChange={e =>
              setOtp(
                e.target.value.replace(/\D/g, '')
              )
            }
            placeholder="000000"
            className="otp-input"
          />
        </label>

        <Button
          loading={busy}
          className="full-width"
        >
          Verify email
          <Icon name="check" size={18} />
        </Button>

        <button
          type="button"
          className="text-action"
          onClick={() => void resend()}
        >
          Didn't receive a code? Resend
        </button>
      </form>
    </AuthLayout>
  );
}

// Forgot password and password reset page
export function ForgotPassword() {
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [resetToken, setResetToken] = useState('');
  const [password, setPassword] = useState('');
  const [password2, setPassword2] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

  const submit = async (e: FormEvent) => {
    e.preventDefault();

    if (busy) return;

    setBusy(true);
    setError('');
    setMessage('');

    try {
      if (step === 1) {
        const res = await api<{
          message: string;
        }>('/api/v1/accounts/forgot-password/', {
          method: 'POST',
          auth: false,
          body: {
            email: email.trim(),
          },
        });

        setMessage(res.message);
        setStep(2);
      } else if (step === 2) {
        const res = await api<{
          reset_token: string;
        }>('/api/v1/accounts/verify-password-otp/', {
          method: 'POST',
          auth: false,
          body: {
            email: email.trim(),
            otp: otp.trim(),
          },
        });

        setResetToken(res.reset_token);
        setStep(3);
      } else {
        if (!getPasswordRules(password).valid) {
          setError(
            'Password must contain at least 8 characters and 3 of the 4 character types.'
          );
          return;
        }

        if (password !== password2) {
          setError('Passwords do not match.');
          return;
        }

        await api('/api/v1/accounts/reset-password/', {
          method: 'POST',
          auth: false,
          body: {
            reset_token: resetToken,
            password,
            password2,
          },
        });

        navigate('/login');
      }
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthLayout
      title={
        step === 1
          ? 'Reset your password'
          : step === 2
            ? 'Check your inbox'
            : 'Choose a new password'
      }
      subtitle={
        step === 1
          ? 'Enter your account email and we’ll send a recovery code.'
          : step === 2
            ? 'Enter the 6-digit code sent to your email.'
            : 'Choose a strong new password to secure your account.'
      }
      footer={
        <Link to="/login">
          Back to sign in
        </Link>
      }
    >
      <form
        className="auth-form"
        onSubmit={submit}
      >
        {error && <Notice message={error} />}

        {message && (
          <Notice
            message={message}
            type="success"
          />
        )}

        {step === 1 ? (
          <label className="form-field">
            <span>Email address</span>

            <input
              type="email"
              required
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={e =>
                setEmail(e.target.value)
              }
            />
          </label>
        ) : step === 2 ? (
          <label className="form-field">
            <span>6-digit code</span>

            <input
              className="otp-input"
              required
              pattern="[0-9]{6}"
              maxLength={6}
              inputMode="numeric"
              value={otp}
              onChange={e =>
                setOtp(
                  e.target.value.replace(/\D/g, '')
                )
              }
            />
          </label>
        ) : (
          <>
            <PasswordInput
              label="New password"
              value={password}
              onChange={setPassword}
              autoComplete="new-password"
              showChecklist
              minLength={8}
            />

            <PasswordInput
              label="Confirm new password"
              value={password2}
              onChange={setPassword2}
              autoComplete="new-password"
              minLength={8}
            />
          </>
        )}

        <Button
          loading={busy}
          className="full-width"
        >
          {step === 1
            ? 'Send recovery code'
            : step === 2
              ? 'Verify code'
              : 'Reset password'}

          <Icon name="arrow" size={18} />
        </Button>

        {step === 2 && (
          <button
            type="button"
            className="text-action"
            onClick={() => setStep(1)}
          >
            Resend code
          </button>
        )}
      </form>
    </AuthLayout>
  );
}
