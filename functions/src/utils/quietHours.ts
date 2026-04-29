import type { DocumentData } from "firebase-admin/firestore";

export function currentHourIn(tz: string): number {
  try {
    const fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour: "numeric",
      hour12: false,
    });
    const h = parseInt(fmt.format(new Date()), 10);
    return Number.isFinite(h) ? h % 24 : new Date().getUTCHours();
  } catch {
    return new Date().getUTCHours();
  }
}

export function isQuietHour(hour: number, start: number, end: number): boolean {
  if (start === end) return false;
  if (start < end) return hour >= start && hour < end;
  return hour >= start || hour < end;
}

export function isQuietHourForUser(userData: DocumentData): boolean {
  const tz: string = userData.timezoneIdentifier ?? "UTC";
  const start: number = userData.quietHoursStart ?? 23;
  const end: number = userData.quietHoursEnd ?? 7;
  return isQuietHour(currentHourIn(tz), start, end);
}
