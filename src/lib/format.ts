/**
 * Money and date formatting for PharmaCare.
 *
 * Money is stored as integer millimes (1 TND = 1000 millimes) so arithmetic
 * stays exact. Never use floating-point multiplication to parse user input.
 */

export const MILLIMES_PER_DINAR = 1000;

const TIME_ZONE = "Africa/Tunis";
const CURRENCY_LOCALE = "fr-TN";
const DATE_LOCALE = "fr-FR";
const EMPTY_VALUE = "—";

const currencyFormatter = new Intl.NumberFormat(CURRENCY_LOCALE, {
  style: "currency",
  currency: "TND",
  minimumFractionDigits: 3,
  maximumFractionDigits: 3,
});

const dateFormatter = new Intl.DateTimeFormat(DATE_LOCALE, {
  timeZone: TIME_ZONE,
  day: "2-digit",
  month: "long",
  year: "numeric",
});

const dateTimeFormatter = new Intl.DateTimeFormat(DATE_LOCALE, {
  timeZone: TIME_ZONE,
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

const timeFormatter = new Intl.DateTimeFormat(DATE_LOCALE, {
  timeZone: TIME_ZONE,
  hour: "2-digit",
  minute: "2-digit",
});

export type DateInput = Date | string | number;

function toDate(value: DateInput): Date | null {
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

/** Format an integer amount in millimes as Tunisian dinars (3 decimals). */
export function formatTND(millimes: number): string {
  if (!Number.isFinite(millimes)) {
    return EMPTY_VALUE;
  }
  return currencyFormatter.format(millimes / MILLIMES_PER_DINAR);
}

/**
 * Parse a user-entered TND amount into integer millimes.
 *
 * Strict: accepts digits with an optional single `.` or `,` followed by
 * 1–3 decimals, optional thousands spaces and an optional `DT`/`TND` suffix.
 * Returns `null` for empty, negative or malformed input.
 */
export function parseTNDInput(value: string): number | null {
  const withoutCurrency = value
    .trim()
    .replace(/[\s\u00a0\u202f]*(?:TND|DT)$/i, "");
  const normalized = withoutCurrency.replace(/[\s\u00a0\u202f]/g, "");

  const match = /^(\d+)(?:[.,](\d{1,3}))?$/.exec(normalized);
  if (!match) {
    return null;
  }

  const dinars = Number.parseInt(match[1], 10);
  const fraction = (match[2] ?? "").padEnd(3, "0");
  const millimes = fraction.length === 0 ? 0 : Number.parseInt(fraction, 10);
  const total = dinars * MILLIMES_PER_DINAR + millimes;

  return Number.isSafeInteger(total) ? total : null;
}

/** Long French date in the Africa/Tunis time zone, e.g. `07 novembre 2026`. */
export function formatDate(value: DateInput): string {
  const date = toDate(value);
  return date ? dateFormatter.format(date) : EMPTY_VALUE;
}

/** Short French date and time in the Africa/Tunis time zone. */
export function formatDateTime(value: DateInput): string {
  const date = toDate(value);
  return date ? dateTimeFormatter.format(date) : EMPTY_VALUE;
}

/** French time (24 h) in the Africa/Tunis time zone, e.g. `13:05`. */
export function formatTime(value: DateInput): string {
  const date = toDate(value);
  return date ? timeFormatter.format(date) : EMPTY_VALUE;
}
