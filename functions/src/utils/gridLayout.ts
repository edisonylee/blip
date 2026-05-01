/**
 * Per-hour grid layout. Mirrors `blip/Features/Shared/MemberGrid.swift` —
 * keep both in sync so the in-app preview matches the stitched export.
 *
 * Capture is landscape (CaptureSession sets videoRotationAngle = 0), so
 * landscape clips fit cleanly into the wide 1-col rows. For 6+ members we
 * split into two columns; odd member counts get a single full-width "lone"
 * row at the bottom rather than leaving a blank cell in a 2-col row.
 *
 *   1     -> 1×1 full canvas
 *   2..5  -> 1 col × N rows
 *   6     -> 2 cols × 3 rows
 *   7     -> 3 doubled rows + 1 lone full-width row
 *   8     -> 2 cols × 4 rows
 *   9     -> 4 doubled rows + 1 lone full-width row
 *  10     -> 2 cols × 5 rows
 *  11     -> 5 doubled rows + 1 lone full-width row
 *  12     -> 2 cols × 6 rows                            (12 = hard cap)
 *
 * Each input is scaled to its own cell size before xstack — see
 * `composeHour` in exportStitch.ts. Cells with a different aspect than the
 * source clip use `force_original_aspect_ratio=increase + crop` (aspect-fill).
 */
export interface GridCell {
  /** Top-left x in canvas pixel coords. */
  x: number;
  /** Top-left y in canvas pixel coords. */
  y: number;
  /** Cell width in pixels. */
  w: number;
  /** Cell height in pixels. */
  h: number;
}

export interface GridSpec {
  /** Per-seat rectangle. `cells.length === count`. */
  cells: GridCell[];
  /** Comma-free pipe-separated `x_y` positions for the ffmpeg `xstack=layout=` arg. */
  xstackLayout: string;
}

const CANVAS_WIDTH = 1080;
const CANVAS_HEIGHT = 1920;

export function gridFor(count: number): GridSpec {
  const W = CANVAS_WIDTH;
  const H = CANVAS_HEIGHT;
  const cells: GridCell[] = [];

  if (count <= 0) {
    return { cells, xstackLayout: "" };
  }

  if (count === 1) {
    cells.push({ x: 0, y: 0, w: W, h: H });
  } else if (count <= 5) {
    const cellH = Math.floor(H / count);
    for (let i = 0; i < count; i++) {
      cells.push({ x: 0, y: i * cellH, w: W, h: cellH });
    }
  } else {
    // 6+: two columns, with an optional lone full-width row at the bottom
    // when the count is odd.
    const isOdd = count % 2 !== 0;
    const fullRows = isOdd ? (count - 1) / 2 : count / 2;
    const totalRows = isOdd ? fullRows + 1 : fullRows;
    const rowH = Math.floor(H / totalRows);
    const colW = Math.floor(W / 2);

    for (let r = 0; r < fullRows; r++) {
      cells.push({ x: 0,    y: r * rowH, w: colW, h: rowH });
      cells.push({ x: colW, y: r * rowH, w: colW, h: rowH });
    }
    if (isOdd) {
      cells.push({ x: 0, y: fullRows * rowH, w: W, h: rowH });
    }
  }

  const xstackLayout = cells.map((c) => `${c.x}_${c.y}`).join("|");
  return { cells, xstackLayout };
}

export const CANVAS = { width: CANVAS_WIDTH, height: CANVAS_HEIGHT };
