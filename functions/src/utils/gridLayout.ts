/**
 * Per-hour grid layout. Up to 5 members the grid stays single-column so each
 * landscape clip gets a full-width row (looks much better than cramming
 * landscape footage into square cells). Past 5 it splits into two columns.
 *
 *   1    -> 1×1 (full canvas)
 *   2    -> 1×2
 *   3    -> 1×3
 *   4    -> 1×4
 *   5    -> 1×5
 *   6    -> 2×3
 *   7-8  -> 2×4
 *   9-10 -> 2×5  (hard cap at 10 members per blip)
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
  if (count <= 1)      { cols = 1; rows = 1; }
  else if (count <= 5) { cols = 1; rows = count; }
  else if (count === 6) { cols = 2; rows = 3; }
  else if (count <= 8) { cols = 2; rows = 4; }
  else                 { cols = 2; rows = 5; }

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
