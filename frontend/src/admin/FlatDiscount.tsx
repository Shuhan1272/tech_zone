import { useEffect, useState, type FormEvent } from 'react';
import { api, money } from './api';
import { ErrorBox, Icon } from './ui';

type State = {
  percentage: string | number;
  active: boolean;
  updated_at: string | null;
  updated_by: string | null;
  variant_count: number;
  can_change: boolean;
};

const when = (value: string | null) =>
  value
    ? new Date(value).toLocaleString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        timeZone: 'Asia/Dhaka',
      })
    : '';

const percent = (value: unknown) =>
  `${Number(value).toLocaleString('en-BD', { maximumFractionDigits: 2 })}%`;

const QUICK = [10, 20, 30, 50];

export function FlatDiscount({ notify }: { notify: (text: string) => void }) {
  const [state, setState] = useState<State | null>(null);
  const [value, setValue] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let live = true;
    api<State>('flat-discount/')
      .then((result) => live && setState(result))
      .catch((cause: Error) => live && setError(cause.message));
    return () => {
      live = false;
    };
  }, []);

  const typed = Number(value);
  const typedValid = value.trim() !== '' && Number.isFinite(typed) && typed > 0;
  const tooLarge = typedValid && typed >= 100;
  const tooPrecise = typedValid && !/^\d+(\.\d{1,2})?$/.test(value.trim());
  const canApply = typedValid && !tooLarge && !tooPrecise;

  async function send(body: Record<string, unknown>, done: string) {
    setBusy(true);
    setError('');
    try {
      const result = await api<State>('flat-discount/', {
        method: 'POST',
        body: JSON.stringify(body),
      });
      setState(result);
      setValue('');
      notify(done);
    } catch (cause) {
      setError((cause as Error).message);
    } finally {
      setBusy(false);
    }
  }

  function apply(event: FormEvent) {
    event.preventDefault();
    if (!canApply || busy) return;
    void send(
      { action: 'apply', percentage: value.trim() },
      `${percent(value)} flat discount applied to all products`,
    );
  }

  function reset() {
    if (busy || !state?.active) return;
    if (
      !window.confirm(
        'Remove the flat discount from all products? Each product will go back to its own discount.',
      )
    )
      return;
    void send({ action: 'reset' }, 'Flat discount removed. Product discounts restored.');
  }

  return (
    <>
      <header className="headline">
        <div>
          <small className="kicker">STORE-WIDE PRICING</small>
          <h1>
            Flat Discount<span className="heading-dot">.</span>
          </h1>
          <p className="page-description">
            Take the same percentage off every product at once. Resetting brings back each product's
            own discount.
          </p>
        </div>
      </header>

      <ErrorBox message={error} />

      {!state ? (
        !error && (
          <div className="workspace-loading">
            <span className="loading-spinner" />
            <p>Loading flat discount…</p>
          </div>
        )
      ) : (
        <div className="flat-discount">
          <section className={`card flat-status ${state.active ? 'is-on' : ''}`}>
            <span className="iconbox">
              <Icon name="discounts" />
            </span>
            <div>
              <small>Current Status</small>
              <strong>
                {state.active
                  ? `${percent(state.percentage)} off every product`
                  : 'No Flat Discount'}
              </strong>
              <p>
                {state.active
                  ? `Running on ${state.variant_count.toLocaleString()} active product variants. Individual product discounts are paused.`
                  : 'Every product is using its own discount.'}
                {state.updated_at && (
                  <>
                    {' '}
                    Last changed {when(state.updated_at)}
                    {state.updated_by ? ` by ${state.updated_by}` : ''}.
                  </>
                )}
              </p>
            </div>
          </section>

          {state.can_change ? (
            <section className="card flat-form">
              <form onSubmit={apply}>
                <label htmlFor="flat-percentage">
                  <b>Discount Percentage</b>
                  <small>
                    Taken off the regular price of every product. Must be more than 0 and less than
                    100.
                  </small>
                </label>
                <div className="flat-quick" role="group" aria-label="Quick percentages">
                  {QUICK.map((item) => (
                    <button
                      key={item}
                      type="button"
                      className={String(item) === value.trim() ? 'active' : ''}
                      onClick={() => setValue(String(item))}
                    >
                      {item}%
                    </button>
                  ))}
                </div>
                <div className="flat-input">
                  <input
                    id="flat-percentage"
                    type="number"
                    inputMode="decimal"
                    min="0.01"
                    max="99.99"
                    step="0.01"
                    placeholder="e.g. 30"
                    value={value}
                    onChange={(event) => setValue(event.target.value)}
                    aria-invalid={tooLarge || tooPrecise || undefined}
                  />
                  <span>%</span>
                  <button className="primary" disabled={busy || !canApply}>
                    <Icon name="check" />
                    {state.active ? 'Update Flat Discount' : 'Apply Flat Discount'}
                  </button>
                </div>
                {tooLarge && (
                  <p className="flat-warning">
                    100% or more would make every product free. Use a smaller percentage.
                  </p>
                )}
                {tooPrecise && !tooLarge && (
                  <p className="flat-warning">Use at most two decimal places.</p>
                )}
                {canApply && (
                  <p className="flat-preview">
                    Example: a {money(10000)} product will sell for{' '}
                    {money(Math.round((10000 - (10000 * typed) / 100) * 100) / 100)}.
                  </p>
                )}
              </form>

              <div className="flat-reset">
                <div>
                  <b>Reset Flat Discount</b>
                  <small>
                    Removes the flat discount and restores every product's own discount.
                  </small>
                </div>
                <button
                  type="button"
                  className="danger"
                  disabled={busy || !state.active}
                  onClick={reset}
                >
                  <Icon name="refresh" />
                  Reset Flat Discount
                </button>
              </div>
            </section>
          ) : (
            <p className="page-description">
              You can view the flat discount but need the Inventory · Change permission to update
              it.
            </p>
          )}
        </div>
      )}
    </>
  );
}
