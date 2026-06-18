import { strict as assert } from "node:assert";
import test from "node:test";

import {
  dateKeyFor,
  isActiveHour,
  orderedHours,
  scheduleFrom,
} from "./blipSchedule";

test("active windows support daytime, overnight, and 24-hour schedules", () => {
  assert.equal(isActiveHour(8, 8, 22), true);
  assert.equal(isActiveHour(22, 8, 22), false);
  assert.equal(isActiveHour(23, 18, 2), true);
  assert.equal(isActiveHour(1, 18, 2), true);
  assert.equal(isActiveHour(2, 18, 2), false);
  assert.equal(isActiveHour(15, 4, 4), true);
});

test("orderedHours follows the group start and treats the end as exclusive", () => {
  assert.deepEqual(orderedHours(8, 12), [8, 9, 10, 11]);
  assert.deepEqual(orderedHours(22, 2), [22, 23, 0, 1]);
  assert.equal(orderedHours(4, 4).length, 24);
  assert.deepEqual(orderedHours(4, 4).slice(0, 3), [4, 5, 6]);
});

test("date keys use group-local time and the configured start hour", () => {
  assert.equal(dateKeyFor(new Date("2026-06-19T02:00:00Z"), "UTC", 4), "2026-06-18");
  assert.equal(dateKeyFor(new Date("2026-06-19T05:00:00Z"), "UTC", 4), "2026-06-19");
  assert.equal(
    dateKeyFor(new Date("2026-06-19T02:00:00Z"), "Asia/Kolkata", 4),
    "2026-06-19",
  );
});

test("date keys remain calendar-correct across a daylight-saving transition", () => {
  assert.equal(
    dateKeyFor(new Date("2026-03-08T07:30:00Z"), "America/New_York", 4),
    "2026-03-07",
  );
});

test("old blips default to the former 4 AM full-day schedule", () => {
  assert.deepEqual(scheduleFrom({ timezoneIdentifier: "UTC" }), {
    timezoneIdentifier: "UTC",
    activeStartHour: 4,
    activeEndHour: 4,
  });
});
