import { money, nextStep, parseTime, paymentText, timeAgo } from '../lib/format';

test('money has two decimals and thousands', () => {
  expect(money(1053)).toBe('$1,053.00');
  expect(money('87.5')).toBe('$87.50');
});

test('times without a zone are read as UTC', () => {
  expect(parseTime('2026-10-16T08:00:00').toISOString()).toBe('2026-10-16T08:00:00.000Z');
  const now = Date.parse('2026-10-16T09:00:00Z');
  expect(timeAgo('2026-10-16T08:59:30', now)).toBe('just now');
  expect(timeAgo('2026-10-16T08:51:00', now)).toBe('9 min');
  expect(timeAgo('2026-10-16T06:00:00Z', now)).toBe('3 h');
});

test('the next step skips Cancel, and payment text', () => {
  expect(nextStep({ next_statuses: ['confirmed', 'cancelled'] })).toBe('confirmed');
  expect(nextStep({ next_statuses: ['cancelled'] })).toBeNull();
  expect(paymentText({ payment_method: 'khqr', payment_status: 'paid' })).toBe('KHQR paid');
  expect(paymentText({ payment_method: 'cod', payment_status: 'unpaid' })).toBe('Cash');
});
