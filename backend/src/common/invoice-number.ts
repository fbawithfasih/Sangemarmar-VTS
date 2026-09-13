import { EntityManager } from 'typeorm';

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

// Indian financial year label (Apr–Mar) for the current moment in IST, e.g. "25-26".
// Computed in IST so the server's timezone (UTC on Railway) doesn't shift the
// Apr 1 boundary.
export function currentFyLabel(now: Date = new Date()): string {
  const ist = new Date(now.getTime() + IST_OFFSET_MS);
  const year = ist.getUTCFullYear();
  const fyStart = ist.getUTCMonth() >= 3 ? year : year - 1;
  return `${String(fyStart).slice(2)}-${String(fyStart + 1).slice(2)}`;
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Allocates the next invoice number of the form `${prefix}/NNN/${fy}`.
//
// Must be called inside a transaction, and the order row must be inserted in
// that same transaction: the advisory lock serialises concurrent creates for
// this prefix and is released only on commit/rollback. The sequence is taken
// from the highest existing number (not a row count), so deleting an order can
// never cause a collision with a number still in use.
export async function nextInvoiceNumber(
  manager: EntityManager,
  tableName: string,
  prefix: string,
): Promise<string> {
  const fy = currentFyLabel();

  await manager.query('SELECT pg_advisory_xact_lock(hashtext($1))', [`invoice:${prefix}`]);

  const pattern = `^${escapeRegex(prefix)}/[0-9]+/${escapeRegex(fy)}$`;
  const [row] = await manager.query(
    `SELECT COALESCE(MAX(CAST(split_part("invoiceNumber", '/', 2) AS integer)), 0) AS max
       FROM "${tableName}"
      WHERE "invoiceNumber" ~ $1`,
    [pattern],
  );

  const next = Number(row?.max ?? 0) + 1;
  return `${prefix}/${String(next).padStart(3, '0')}/${fy}`;
}
