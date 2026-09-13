const months = new Map<string, number>([
  ["january", 0],
  ["february", 1],
  ["march", 2],
  ["april", 3],
  ["may", 4],
  ["june", 5],
  ["july", 6],
  ["august", 7],
  ["september", 8],
  ["october", 9],
  ["november", 10],
  ["december", 11],
]);

export type DateRange = { startDate: Date; endDate: Date };

export function parseEnglishDateRange(value: string): DateRange | null {
  const dateText = value
    .split("|")[0]
    ?.replace(/[–—]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
  if (!dateText) return null;

  const acrossMonths = dateText.match(
    /^(\d{1,2})\s+([A-Za-z]+)\s*-\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/,
  );
  if (acrossMonths) {
    const [, startDay, startMonth, endDay, endMonth, year] = acrossMonths;
    return buildRange(startDay, startMonth, endDay, endMonth, year);
  }

  const sameMonth = dateText.match(
    /^(\d{1,2})\s*-\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/,
  );
  if (sameMonth) {
    const [, startDay, endDay, month, year] = sameMonth;
    return buildRange(startDay, month, endDay, month, year);
  }

  const singleDay = dateText.match(/^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/);
  if (singleDay) {
    const [, day, month, year] = singleDay;
    return buildRange(day, month, day, month, year);
  }

  return null;
}

function buildRange(
  startDay: string | undefined,
  startMonth: string | undefined,
  endDay: string | undefined,
  endMonth: string | undefined,
  year: string | undefined,
): DateRange | null {
  const startMonthIndex = months.get(startMonth?.toLowerCase() ?? "");
  const endMonthIndex = months.get(endMonth?.toLowerCase() ?? "");
  if (startMonthIndex === undefined || endMonthIndex === undefined || !year) {
    return null;
  }

  const startDate = calendarDate(Number(year), startMonthIndex, Number(startDay));
  const endDate = calendarDate(Number(year), endMonthIndex, Number(endDay));
  if (Number.isNaN(startDate.valueOf()) || Number.isNaN(endDate.valueOf())) {
    return null;
  }
  return { startDate, endDate };
}

function calendarDate(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month, day));
}
