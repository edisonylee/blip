/**
 * Per-hour grid layout per CLAUDE.md core mechanic:
 *   1   -> 1×1 (full canvas)
 *   2   -> 1×2 (stacked vertically — single column, two rows on a 9:16 canvas)
 *   3-4 -> 2×2
 *   5-6 -> 3×2
 *   7-9 -> 3×3
 *   10+ -> 4×3 (caps at 12 since blip.size is bounded 2–12)
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
  if (count <= 1) { cols = 1; rows = 1; }
  else if (count === 2) { cols = 1; rows = 2; }
  else if (count <= 4) { cols = 2; rows = 2; }
  else if (count <= 6) { cols = 3; rows = 2; }
  else if (count <= 9) { cols = 3; rows = 3; }
  else { cols = 4; rows = 3; }

  const cellWidth = Math.floor(CANVAS_WIDTH / cols);
  const cellHeight = Math.floor(CANVAS_HEIGHT / rows);

  const positions: string[] = [];
  for (let i = 0; i < count; i++) {
    const r = Math.floor(i / cols);
    const c = i % cols;
    positions.push(`${c * cellWidth}_${r * cellHeight}`);
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
