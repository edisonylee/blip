import { strict as assert } from "node:assert";
import test from "node:test";

import { CANVAS, gridFor } from "./gridLayout";

const expected: Array<[number, number, number]> = [
  [1, 1, 1],
  [2, 1, 2],
  [3, 2, 2],
  [4, 2, 2],
  [5, 2, 3],
  [6, 2, 3],
  [7, 2, 4],
  [8, 2, 4],
  [9, 2, 5],
  [10, 2, 5],
  [11, 2, 6],
  [12, 2, 6],
];

test("gridFor maps every supported member count to the portrait row spec", () => {
  for (const [count, cols, rows] of expected) {
    const grid = gridFor(count);
    assert.equal(grid.cols, cols, `cols for ${count}`);
    assert.equal(grid.rows, rows, `rows for ${count}`);
    assert.equal(grid.xstackLayout.split("|").length, count);

    for (const position of grid.xstackLayout.split("|")) {
      const [x, y] = position.split("_").map(Number);
      assert.ok(x >= 0 && x + grid.cellWidth <= CANVAS.width, `${count}: x in canvas`);
      assert.ok(y >= 0 && y + grid.cellHeight <= CANVAS.height, `${count}: y in canvas`);
    }
  }
});

test("odd two-column grids center their final member", () => {
  for (const count of [3, 5, 7, 9, 11]) {
    const grid = gridFor(count);
    const finalPosition = grid.xstackLayout.split("|").at(-1);
    const expectedX = Math.floor((CANVAS.width - grid.cellWidth) / 2);
    assert.equal(finalPosition?.split("_")[0], String(expectedX), `centered ${count}`);
  }
});

test("gridFor rejects counts outside the product limit", () => {
  assert.throws(() => gridFor(0));
  assert.throws(() => gridFor(13));
});
