import { useEffect, useRef, useState, type FormEvent } from 'react';
import { api, label, type Section, type Detail } from './api';
import { ErrorBox, display, Grid } from './ui';
import { AccessFields } from './AccessFields';
import { DeleteReview } from './DeleteReview';

const actionDescriptions: Record<string, string> = {
  deactivate_staff:
    'This staff member will lose access to the admin console immediately. Their account and activity history will be preserved.',
  activate_staff:
    'This staff member will be able to sign in with their existing credentials and assigned permissions.',
  cancelled: 'Cancel this order. Review the order and payment details before continuing.',
  collect_cod: 'Confirm that payment has been received for this delivered cash-on-delivery order.',
  approve_refund:
    'Approve this refund request for processing. Submit the refund to the payment provider in the next step.',
  request_refund: 'Submit a refund request for this payment. Include a reason for the review.',
  reject_refund: 'Reject this refund request and record the reason in the activity history.',
};

export function Editor({
  section,
  id,
  close,
  saved,
}: {
  section: Section;
  id: string;
  close: () => void;
  saved: (message: string) => void;
}) {
  const [data, setData] = useState<Detail | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(id === 'new');
  const [action, setAction] = useState('');
  const [note, setNote] = useState('');
  const [dirty, setDirty] = useState(false);
  const [discard, setDiscard] = useState<'close' | 'edit' | null>(null);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const base = `resources/${section.key}/${id}/`;
  const isAccessRecord = ['team', 'roles'].includes(section.key);
  const creationLabels: Record<string, { heading: string; button: string }> = {
    team: { heading: 'Add staff member', button: 'Create staff account' },
    roles: { heading: 'Create role', button: 'Create role' },
  };
  const newHeading = creationLabels[section.key]?.heading || 'New record';
  const createLabel = creationLabels[section.key]?.button || 'Create record';
  const heading =
    id === 'new' ? newHeading : String(data?.data.email || data?.data.name || `Record #${id}`);

  useEffect(() => {
    const dialog = dialogRef.current;
    dialog?.showModal();
    let live = true;
    api<Detail>(base)
      .then((result) => {
        if (live) setData(result);
      })
      .catch((reason) => {
        if (live) setError(reason.message);
      });
    return () => {
      live = false;
      dialog?.close();
    };
  }, [base]);

  function leave(destination: 'close' | 'edit') {
    if (busy) return;
    if (dirty) {
      setDiscard(destination);
      return;
    }
    if (destination === 'close') close();
    else setEditing(false);
  }

  function markDirty(event: FormEvent<HTMLFormElement>) {
    const target = event.target;
    if (
      (target instanceof HTMLInputElement ||
        target instanceof HTMLSelectElement ||
        target instanceof HTMLTextAreaElement) &&
      target.name
    ) {
      setDirty(true);
    }
  }

  async function send(method: string, body?: FormData | string, operation = false) {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      await api(base + (operation ? 'action/' : ''), {
        method,
        body,
        headers: {
          'X-Record-Version': data?.version || '',
          ...(method === 'DELETE' && {
            'X-Deletion-Token': data?.deletion?.token || '',
          }),
        },
      });
      saved(
        method === 'DELETE'
          ? 'Record deleted.'
          : operation
            ? `${label(action)} completed.`
            : 'Changes saved.',
      );
    } catch (reason) {
      setError((reason as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <dialog
      className="drawer"
      ref={dialogRef}
      aria-labelledby="record-heading"
      aria-busy={busy}
      onCancel={(event) => {
        event.preventDefault();
        leave('close');
      }}
    >
      <div className="cardhead editor-heading">
        <div>
          <small className="kicker">
            {section.title}
            {id !== 'new' ? ` / #${id}` : ''}
          </small>
          <h2 id="record-heading">{heading}</h2>
        </div>
        <button
          disabled={busy}
          className="square"
          onClick={() => leave('close')}
          aria-label="Close record"
        >
          ×
        </button>
      </div>
      <ErrorBox message={error} />
      {discard ? (
        <section className="confirm unsaved-confirm" aria-label="Unsaved changes">
          <h3>Discard unsaved changes?</h3>
          <p>Your changes have not been saved.</p>
          <div className="buttons">
            <button
              className="danger"
              onClick={() => {
                setDirty(false);
                setDiscard(null);
                if (discard === 'close') close();
                else setEditing(false);
              }}
            >
              Discard changes
            </button>
            <button onClick={() => setDiscard(null)}>Keep editing</button>
          </div>
        </section>
      ) : null}
      {!data ? (
        !error && (
          <p className="editor-loading" role="status">
            Loading record…
          </p>
        )
      ) : editing ? (
        <form
          hidden={discard !== null}
          onInput={markDirty}
          onChange={markDirty}
          onSubmit={(event) => {
            event.preventDefault();
            void send('POST', new FormData(event.currentTarget));
          }}
        >
          <fieldset disabled={busy} className="editor-form-fields">
            {isAccessRecord ? (
              <AccessFields html={data.form} onChange={() => setDirty(true)} />
            ) : (
              <div className="fields" dangerouslySetInnerHTML={{ __html: data.form }} />
            )}
          </fieldset>
          <div className="buttons editor-footer">
            <button className="primary" disabled={busy}>
              {busy ? 'Saving…' : id === 'new' ? createLabel : 'Save changes'}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => leave(id === 'new' ? 'close' : 'edit')}
            >
              Cancel
            </button>
          </div>
        </form>
      ) : (
        <>
          {section.key === 'team' && (
            <p className="staff-status-note">
              {data.data.is_active
                ? 'Active staff member. Access is determined by their assigned roles and individual permissions.'
                : 'This account is suspended. The staff member cannot access the admin console.'}
            </p>
          )}
          <dl>
            {Object.entries(data.data)
              .filter(([key]) => key !== 'id')
              .map(([key, value]) => (
                <div key={key}>
                  <dt>{label(key)}</dt>
                  <dd>{display(key, value)}</dd>
                </div>
              ))}
          </dl>
          {data.access && (
            <section className="access-summary">
              <h3>Access summary</h3>
              <div className="access-chips">
                {data.access.groups.length ? (
                  data.access.groups.map((group) => (
                    <span className="access-chip" key={group.id}>
                      {group.name}
                    </span>
                  ))
                ) : (
                  <span className="caption">No roles assigned</span>
                )}
              </div>
              <div className="access-summary-grid">
                <div>
                  <strong>{data.access.effective_permissions.length}</strong>
                  <span>Effective permissions</span>
                </div>
                <div>
                  <strong>{data.access.direct_permissions.length}</strong>
                  <span>Individual permissions</span>
                </div>
              </div>
              <p className="caption">
                Suspending a staff member preserves their account and activity history.
              </p>
            </section>
          )}
          {data.members && (
            <section className="access-summary">
              <h3>Assigned accounts · {data.members.length}</h3>
              {data.members.length ? (
                <ul className="role-members">
                  {data.members.map((member) => (
                    <li key={member.id}>
                      <span>{member.email}</span>
                      {display('is_active', member.is_active)}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="caption">No accounts are assigned to this role yet.</p>
              )}
            </section>
          )}
          {['orders', 'carts', 'wishlists', 'builds'].includes(section.key) && (
            <>
              <h3>Items</h3>
              {data.items.length ? (
                <Grid
                  rows={data.items}
                  columns={Object.keys(data.items[0]).filter((key) => key !== 'id')}
                />
              ) : (
                <p className="caption">No items.</p>
              )}
            </>
          )}
          {action === 'delete' && data.deletion ? (
            <DeleteReview
              summary={data.deletion}
              busy={busy}
              onConfirm={() => void send('DELETE')}
              onBack={() => setAction('')}
            />
          ) : action ? (
            <form
              className="confirm"
              onSubmit={(event) => {
                event.preventDefault();
                void send('POST', JSON.stringify({ action, note }), true);
              }}
            >
              <h3>{label(action)}?</h3>
              {actionDescriptions[action] && <p>{actionDescriptions[action]}</p>}
              {['approve_refund', 'request_refund', 'reject_refund'].includes(action) && (
                <label>
                  Reason or note
                  <textarea
                    required={action !== 'approve_refund'}
                    value={note}
                    maxLength={255}
                    onChange={(event) => setNote(event.target.value)}
                  />
                </label>
              )}
              <div className="buttons">
                <button
                  disabled={busy}
                  className={
                    action === 'deactivate_staff' || action === 'cancelled' ? 'danger' : 'primary'
                  }
                >
                  {busy ? 'Working…' : 'Confirm'}
                </button>
                <button type="button" disabled={busy} onClick={() => setAction('')}>
                  Back
                </button>
              </div>
            </form>
          ) : (
            <div className="buttons editor-footer">
              {data.form && (
                <button className="primary" onClick={() => setEditing(true)}>
                  {isAccessRecord ? 'Edit details & access' : 'Edit record'}
                </button>
              )}
              {data.actions.map((item) => (
                <button key={item} onClick={() => setAction(item)}>
                  {label(item)}
                </button>
              ))}
              {data.delete && (
                <button className="delete-link" onClick={() => setAction('delete')}>
                  Delete
                </button>
              )}
            </div>
          )}
        </>
      )}
    </dialog>
  );
}
