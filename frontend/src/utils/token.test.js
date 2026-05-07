import { describe, expect, test } from 'vitest';
import { decodeToken } from './token';

describe('decodeToken', () => {
  test('returns null for malformed token', () => {
    expect(decodeToken('not-a-jwt')).toBeNull();
  });

  test('returns payload for valid JWT-shaped token', () => {
    const payload = { sub: '123', username: 'alice' };
    const encoded = btoa(JSON.stringify(payload)).replace(/=+$/, '');
    const token = `x.${encoded}.y`;

    expect(decodeToken(token)).toEqual(payload);
  });
});

