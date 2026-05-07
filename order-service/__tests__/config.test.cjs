const config = require('../src/config');

describe('config', () => {
  test('has defaults', () => {
    expect(config.PORT).toBe(8003);
    expect(typeof config.DATABASE_URL).toBe('string');
    expect(config.DATABASE_URL.length).toBeGreaterThan(0);
    expect(typeof config.JWT_SECRET).toBe('string');
    expect(config.JWT_SECRET.length).toBeGreaterThan(0);
  });
});

