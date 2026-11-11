import { useEffect, useMemo, useState } from 'react';
import { api } from './api';

interface Choice {
  id: string;
  label: string;
  selected: boolean;
}

interface AccessField {
  name: string;
  label: string;
  choices: Choice[];
}

interface Permission {
  id: number;
  name: string;
  action: string;
  resource: string;
}

interface PermissionGroup {
  key: string;
  title: string;
  permissions: Permission[];
}

interface PermissionCatalog {
  groups: PermissionGroup[];
}

/** Keep Django's validation and field names while making access choices usable. */
function parseAccessFields(html: string) {
  const document = new DOMParser().parseFromString(html, 'text/html');
  const fields: AccessField[] = [];

  for (const name of ['groups', 'user_permissions', 'permissions']) {
    const select = document.querySelector<HTMLSelectElement>(`select[name="${name}"]`);
    if (!select) continue;

    const fieldLabel = document.querySelector(`label[for="${select.id}"]`);
    fields.push({
      name,
      label: fieldLabel?.textContent?.replace(/:\s*$/, '') || name,
      choices: Array.from(select.options).map((option) => ({
        id: option.value,
        label: option.text,
        selected: option.hasAttribute('selected'),
      })),
    });
    (select.closest('div') || select).remove();
  }

  return { html: document.body.innerHTML, fields };
}

function PermissionChooser({
  field,
  groups,
  onChange,
}: {
  field: AccessField;
  groups: PermissionGroup[];
  onChange: () => void;
}) {
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState(
    () => new Set(field.choices.filter((choice) => choice.selected).map((choice) => choice.id)),
  );
  const allowed = useMemo(
    () => new Map(field.choices.map((choice) => [choice.id, choice])),
    [field],
  );
  const grouped = useMemo(() => {
    const included = new Set<string>();
    const result = groups
      .map((group) => ({
        ...group,
        choices: group.permissions.flatMap((permission) => {
          const choice = allowed.get(String(permission.id));
          if (!choice) return [];
          included.add(choice.id);
          return [{ ...choice, label: permission.name }];
        }),
      }))
      .filter((group) => group.choices.length);
    const remaining = field.choices.filter((choice) => !included.has(choice.id));
    if (remaining.length)
      result.push({
        key: 'other',
        title: result.length ? 'Other permissions' : 'Available permissions',
        permissions: [],
        choices: remaining,
      });
    return result;
  }, [allowed, field, groups]);
  const term = query.trim().toLowerCase();
  const visibleCount = grouped.reduce(
    (count, group) =>
      count +
      group.choices.filter((choice) =>
        `${group.title} ${choice.label}`.toLowerCase().includes(term),
      ).length,
    0,
  );

  function update(ids: string[], enabled: boolean) {
    setSelected((previous) => {
      const next = new Set(previous);
      ids.forEach((id) => (enabled ? next.add(id) : next.delete(id)));
      return next;
    });
    onChange();
  }

  return (
    <fieldset className="access-section">
      <legend>
        {field.name === 'permissions' ? 'Role permissions' : 'Additional permissions'}
      </legend>
      <div className="access-heading">
        <p className="caption">
          {field.name === 'permissions'
            ? 'Choose what members of this role can view and manage.'
            : 'Grant individual access in addition to the permissions inherited from roles.'}
        </p>
        <span className="access-count">{selected.size} selected</span>
      </div>
      <input
        className="access-search"
        type="search"
        aria-label="Search permissions"
        placeholder="Search permissions or resources…"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <div className="permission-groups">
        {grouped.map((group) => {
          const visible = group.choices.filter((choice) =>
            `${group.title} ${choice.label}`.toLowerCase().includes(term),
          );
          const allSelected =
            visible.length > 0 && visible.every((choice) => selected.has(choice.id));
          return (
            <section className="permission-group" key={group.key} hidden={!visible.length}>
              <div className="permission-group-head">
                <h4>{group.title}</h4>
                <button
                  type="button"
                  className="link"
                  onClick={() =>
                    update(
                      visible.map((choice) => choice.id),
                      !allSelected,
                    )
                  }
                  aria-label={`${allSelected ? 'Clear' : 'Select'} matching permissions for ${group.title}`}
                >
                  {allSelected ? 'Clear' : 'Select all'}
                </button>
              </div>
              <div className="permission-options">
                {group.choices.map((choice) => (
                  <label
                    className="permission-option"
                    key={choice.id}
                    hidden={!`${group.title} ${choice.label}`.toLowerCase().includes(term)}
                  >
                    <input
                      type="checkbox"
                      name={field.name}
                      value={choice.id}
                      checked={selected.has(choice.id)}
                      onChange={(event) => update([choice.id], event.target.checked)}
                    />
                    <span>{choice.label}</span>
                  </label>
                ))}
              </div>
            </section>
          );
        })}
      </div>
      {!visibleCount && <p className="empty">No permissions match your search.</p>}
      {!field.choices.length && <p className="caption">No permissions are available.</p>}
    </fieldset>
  );
}

export function AccessFields({ html, onChange }: { html: string; onChange: () => void }) {
  const parsed = useMemo(() => parseAccessFields(html), [html]);
  const [catalog, setCatalog] = useState<PermissionGroup[]>([]);

  useEffect(() => {
    let live = true;
    if (parsed.fields.some((field) => field.name !== 'groups')) {
      api<PermissionCatalog>('permissions/')
        .then((data) => {
          if (live) setCatalog(data.groups);
        })
        .catch(() => {
          // Native form options remain available if the catalog cannot be loaded.
        });
    }
    return () => {
      live = false;
    };
  }, [parsed]);

  return (
    <div className="access-fields">
      <div className="fields" dangerouslySetInnerHTML={{ __html: parsed.html }} />
      {parsed.fields.map((field) =>
        field.name === 'groups' ? (
          <fieldset className="access-section" key={field.name}>
            <legend>Assigned roles</legend>
            <p className="caption">Staff inherit the permissions of every selected role.</p>
            <div className="access-role-list">
              {field.choices.map((choice) => (
                <label className="access-role-option" key={choice.id}>
                  <input
                    type="checkbox"
                    name="groups"
                    value={choice.id}
                    defaultChecked={choice.selected}
                  />
                  <span>{choice.label}</span>
                </label>
              ))}
            </div>
            {!field.choices.length && (
              <p className="caption">
                Create a role in Roles & permissions to assign shared access.
              </p>
            )}
          </fieldset>
        ) : (
          <PermissionChooser field={field} groups={catalog} onChange={onChange} key={field.name} />
        ),
      )}
    </div>
  );
}
