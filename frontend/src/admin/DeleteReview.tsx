import type { DeletionSummary } from './api';

type Props = {
  summary: DeletionSummary;
  busy: boolean;
  onConfirm: () => void;
  onBack: () => void;
};

export function DeleteReview({ summary, busy, onConfirm, onBack }: Props) {
  const blocked = summary.blockers.length > 0;

  return (
    <section className="confirm" aria-label="Review deletion">
      <h3>{blocked ? 'Deletion blocked' : 'Confirm permanent deletion'}</h3>
      <p>
        {blocked
          ? 'Resolve these dependencies before deleting this record.'
          : 'Django will apply the following changes.'}
      </p>
      <ul>
        {(blocked ? summary.blockers : summary.changes).map((message) => (
          <li key={message}>{message}</li>
        ))}
      </ul>
      <div className="buttons">
        {!blocked && (
          <button className="danger" disabled={busy} onClick={onConfirm}>
            {busy ? 'Deleting…' : 'Confirm deletion'}
          </button>
        )}
        <button disabled={busy} onClick={onBack}>
          Back
        </button>
      </div>
    </section>
  );
}
