export class HttpError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: unknown;

  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
    if (details !== undefined) {
      this.details = details;
    }
  }

  body(): { error: { code: string; message: string; details?: unknown } } {
    const error: { code: string; message: string; details?: unknown } = {
      code: this.code,
      message: this.message,
    };
    if (this.details !== undefined) {
      error.details = this.details;
    }
    return { error };
  }
}
