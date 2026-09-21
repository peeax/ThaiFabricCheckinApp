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

export function parseEnglishDateRangeFromText(
  value: string,
  fallbackYear?: number,
): DateRange | null {
  const normalized = value.replace(/[–—]/g, "-").replace(/\s+/g, " ").trim();
  const acrossYears = normalized.match(
    /(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\s+(?:to|-)\s+(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})/i,
  );
  if (acrossYears) {
    const [, startDay, startMonth, startYear, endDay, endMonth, endYear] =
      acrossYears;
    return buildRangeWithYears(
      startDay,
      startMonth,
      startYear,
      endDay,
      endMonth,
      endYear,
    );
  }

  const acrossMonths = normalized.match(
    /(\d{1,2})\s+([A-Za-z]+)\s+(?:to|-)\s+(\d{1,2})\s+([A-Za-z]+)(?:\s+(\d{4}))?/i,
  );
  if (acrossMonths) {
    const [, startDay, startMonth, endDay, endMonth, yearText] = acrossMonths;
    const year = yearText ?? fallbackYear?.toString();
    return buildRange(startDay, startMonth, endDay, endMonth, year);
  }

  const sameMonth = normalized.match(
    /(\d{1,2})\s*-\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})/i,
  );
  if (sameMonth) {
    const [, startDay, endDay, month, year] = sameMonth;
    return buildRange(startDay, month, endDay, month, year);
  }

  const singleDay = normalized.match(/(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})/i);
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

function buildRangeWithYears(
  startDay: string | undefined,
  startMonth: string | undefined,
  startYear: string | undefined,
  endDay: string | undefined,
  endMonth: string | undefined,
  endYear: string | undefined,
): DateRange | null {
  const startMonthIndex = months.get(startMonth?.toLowerCase() ?? "");
  const endMonthIndex = months.get(endMonth?.toLowerCase() ?? "");
  if (
    startMonthIndex === undefined ||
    endMonthIndex === undefined ||
    !startYear ||
    !endYear
  ) {
    return null;
  }
  return {
    startDate: calendarDate(Number(startYear), startMonthIndex, Number(startDay)),
    endDate: calendarDate(Number(endYear), endMonthIndex, Number(endDay)),
  };
}

function calendarDate(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month, day));
}
