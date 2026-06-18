/**
 * Per-hour portrait grid layout, based on actual group membership.
 *
 *   1    -> 1×1 (full canvas)
 *   2    -> 1×2
 *   3    -> 2×2 (last seat centered)
 *   4    -> 2×2
 *   5    -> 2×3 (last seat centered)
 *   6    -> 2×3
 *   7-8  -> 2×4 (last seat centered for 7)
 *   9-10 -> 2×5 (last seat centered for 9)
 *   11-12 -> 2×6 (last seat centered for 11)
 *
 * Inputs are pre-scaled to cellWidth × cellHeight before xstack, so positions
 * are literal pixel offsets (no `w0/h0` variables needed).
 */
export interface GridSpec {
  cols: number;
  rows: number;
  cellWidth: number;
  cellHeight: number;
  /** Literal pixel positions, "x_y|x_y|...", one entry per cell. */
  xstackLayout: string;
}

const CANVAS_WIDTH = 1080;
const CANVAS_HEIGHT = 1920;

export function gridFor(count: number): GridSpec {
  let cols: number;
  let rows: number;
  if (!Number.isInteger(count) || count < 1 || count > 12) {
    throw new Error(`grid count must be between 1 and 12, got ${count}`);
  }
  if (count <= 2) {
    cols = 1;
    rows = count;
  } else {
    cols = 2;
    rows = Math.ceil(count / 2);
  }

  const cellWidth = Math.floor(CANVAS_WIDTH / cols);
  const cellHeight = Math.floor(CANVAS_HEIGHT / rows);

  const positions: string[] = [];
  for (let i = 0; i < count; i++) {
    const r = Math.floor(i / cols);
    const c = i % cols;
    const isCenteredFinalSeat = cols === 2 && count % 2 === 1 && i === count - 1;
    const x = isCenteredFinalSeat ? Math.floor((CANVAS_WIDTH - cellWidth) / 2) : c * cellWidth;
    positions.push(`${x}_${r * cellHeight}`);
  }
  return {
    cols,
    rows,
    cellWidth,
    cellHeight,
    xstackLayout: positions.join("|"),
  };
}

export const CANVAS = { width: CANVAS_WIDTH, height: CANVAS_HEIGHT };
