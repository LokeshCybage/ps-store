import { describe, expect, test } from 'vitest';
import { decodeJwtToken } from './token';

describe('decodeJwtToken', () => {
  test('returns null for malformed token', () => {
    expect(decodeJwtToken('not-a-jwt')).toBeNull();
  });

  test('returns payload for valid JWT-shaped token', () => {
    const payload = { sub: '123', username: 'alice' };
    const encoded = btoa(JSON.stringify(payload)).replace(/=+$/, '');
    const token = `x.${encoded}.y`;

    expect(decodeJwtToken(token)).toEqual(payload);
  });
});

