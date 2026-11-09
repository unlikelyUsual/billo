import { draftSchema, looksLikePan, type Draft } from './domain';

export const SAMPLE_MARKER = 'BILLO-SAMPLE-STATEMENT-V1';

export const VERIFIED_SAMPLE_LINES = [
  SAMPLE_MARKER,
  'issuer=ttb',
  'last4=7781',
  'network=visa',
  'periodStart=2026-10-01',
  'periodEnd=2026-10-31',
  'statementDate=2026-10-31',
  'dueDate=2026-11-21',
  'fullDueSatang=1500000',
  'minDueSatang=75000',
] as const;

export const UNSUPPORTED_LETTER_LINES = [
  'Billo demo letter',
  'This document is not a credit card statement.',
] as const;

export type PdfExtractResult =
  | { status: 'extracted'; draft: Draft }
  | { status: 'unavailable'; reason: string; message: string };

function unavailable(reason: string, message: string): PdfExtractResult {
  return { status: 'unavailable', reason, message };
}

/**
 * Reads one uncompressed sample layout. Anything else is unavailable.
 * Amounts are never guessed from a partial or unknown document.
 */
export function extractStatementPdf(bytes: Buffer): PdfExtractResult {
  const text = bytes.toString('latin1');
  if (!text.startsWith('%PDF-')) {
    return unavailable('not_a_pdf', 'The upload is not a PDF. No amounts were read.');
  }
  if (text.includes('/Encrypt')) {
    return unavailable('encrypted_pdf', 'Encrypted PDFs are not read. No amounts were guessed.');
  }
  if (text.includes('/Filter') || text.includes('/ObjStm')) {
    return unavailable(
      'compressed_pdf',
      'This PDF is compressed or packaged. Automatic extraction is unavailable, and no amounts were guessed.',
    );
  }
  const literals = extractLiteralStrings(text);
  for (const line of literals) {
    if (looksLikePan(line) || /^(pan|cvv|cvc)\b/i.test(line)) {
      return unavailable(
        'secret_field_rejected',
        'The PDF appears to contain a full card number or a secret. It was not imported.',
      );
    }
    const separator = line.indexOf('=');
    if (separator > 0 && looksLikePan(line.slice(separator + 1))) {
      return unavailable(
        'secret_field_rejected',
        'The PDF appears to contain a full card number or a secret. It was not imported.',
      );
    }
  }
  if (literals.length === 0) {
    return unavailable('no_text_layer', 'No readable text layer was found. Automatic extraction is unavailable.');
  }
  if (!literals.some((line) => line.includes(SAMPLE_MARKER))) {
    return unavailable(
      'layout_not_verified',
      'This PDF has no verified Billo sample layout. Automatic extraction is unavailable, and amounts were not guessed.',
    );
  }
  const record: Record<string, string> = {};
  for (const line of literals) {
    const separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    record[line.slice(0, separator)] = line.slice(separator + 1);
  }
  const fullRaw = record.fullDueSatang ?? '';
  const minRaw = record.minDueSatang ?? '';
  const parsed = draftSchema.safeParse({
    issuer: record.issuer,
    last4: record.last4,
    network: record.network,
    periodStart: record.periodStart,
    periodEnd: record.periodEnd,
    statementDate: record.statementDate,
    dueDate: record.dueDate,
    fullDueSatang: Number(fullRaw),
    minDueSatang: Number(minRaw),
  });
  if (!parsed.success || !/^\d+$/.test(fullRaw) || !/^\d+$/.test(minRaw)) {
    return unavailable(
      'sample_fields_invalid',
      'The sample marker was present but the fields were incomplete or invalid. No statement was created.',
    );
  }
  return { status: 'extracted', draft: parsed.data };
}

export function buildTextPdf(lines: readonly string[]): Buffer {
  const commands = lines.map((line, index) => {
    if (!/^[\x20-\x7E]*$/.test(line)) {
      throw new Error('PDF fixture lines must be ASCII');
    }
    const y = 740 - index * 22;
    return `BT /F1 11 Tf 64 ${y} Td (${escapePdf(line)}) Tj ET`;
  });
  return assemblePdf(commands.join('\n'));
}

function escapePdf(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
}

function assemblePdf(content: string): Buffer {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Count 1 /Kids [3 0 R] >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${Buffer.byteLength(content, 'latin1')} >>\nstream\n${content}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets: number[] = [0];
  for (let index = 0; index < objects.length; index += 1) {
    offsets.push(Buffer.byteLength(pdf, 'latin1'));
    const body = objects[index];
    if (body === undefined) {
      throw new Error('Missing PDF object');
    }
    pdf += `${index + 1} 0 obj\n${body}\nendobj\n`;
  }
  const xref = Buffer.byteLength(pdf, 'latin1');
  let body = `${pdf}xref\n0 ${objects.length + 1}\n`;
  body += '0000000000 65535 f \n';
  for (let index = 1; index < offsets.length; index += 1) {
    const offset = offsets[index];
    if (offset === undefined) {
      throw new Error('Missing xref offset');
    }
    body += `${String(offset).padStart(10, '0')} 00000 n \n`;
  }
  body += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(body, 'latin1');
}

function extractLiteralStrings(pdf: string): string[] {
  const out: string[] = [];
  for (let index = 0; index < pdf.length; index += 1) {
    if (pdf[index] !== '(' || isEscaped(pdf, index)) {
      continue;
    }
    let cursor = index + 1;
    let value = '';
    while (cursor < pdf.length) {
      const char = pdf[cursor] ?? '';
      if (char === '\\') {
        const next = pdf[cursor + 1] ?? '';
        if (next === 'n') value += '\n';
        else if (next === 'r') value += '\r';
        else if (next === 't') value += '\t';
        else value += next;
        cursor += 2;
        continue;
      }
      if (char === ')') {
        break;
      }
      value += char;
      cursor += 1;
    }
    const after = pdf.slice(cursor + 1, cursor + 16);
    if (/^\s*Tj/.test(after)) {
      out.push(value);
    }
    index = cursor;
  }
  return out;
}

function isEscaped(pdf: string, index: number): boolean {
  let slashes = 0;
  for (let cursor = index - 1; cursor >= 0 && pdf[cursor] === '\\'; cursor -= 1) {
    slashes += 1;
  }
  return slashes % 2 === 1;
}
