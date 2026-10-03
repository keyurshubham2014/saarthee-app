# Saarthee brand assets

Name: **Saarthee · સારથી**. Rules come from `docs/v2/design-system.md` §1–§4.

## The mark (variant E, "road turn")

`mark.svg` is the master. It is a 100 × 100 unit rounded square (radius 28, `primary` #14674A).
A white road (stroke 12, round caps and joins) rises from the bottom-left, turns right on a
generous 18-unit corner, and runs on towards a `sunrise` #C24A1F dot (r 10.5), which is the
destination. A 6-unit gap separates the road end from the dot, so the mark also works in one colour
without masks.

```
square  rect 0 0 100 100 rx 28        #14674A
route   M24 73 L24 51 Q24 33 42 33 L50 33   stroke 12, white
dot     circle 72.5 33 r 10.5          #C24A1F
glyph bbox 18–83 × 22.5–79 (optically centred)
```

### Why E

Seven candidates are compared in `explorations.html`
(`screens/explorations.png` and the close-up `screens/mark-closeup.png`).

- **D (previous pick) was rejected.** A zig-zag rising to the upper right is the stock Material
  `trending_up` / `show_chart` icon, which reads as finance or analytics, not civic help.
- **F (chevron)** reads as the head of the `north_east` / `call_made` arrow, or as the digit "7".
- **G (winding lane)** is pleasant at 256 px, but at 16 px it collapses into a diagonal stroke,
  which again looks like `north_east`.
- **E** reads as a navigation turn ("turn here, you are nearly there") and does not borrow any chart
  or arrow semantics. Its two strokes (vertical and horizontal) and the dot snap cleanly to the
  pixel grid, so it is the most legible at 16 px and as a 24 dp status-bar silhouette. It keeps the
  DS §1 story, "the way forward", with the route going up and then right to the destination.

What is not used: seals, circle emblems, architecture, wheels or chakras, and AMC colours.

## Files

| File | Use |
| --- | --- |
| `mark.svg` | master full-colour mark |
| `explorations.html` | variant comparison (A–G), light and dark |
| `screens/` | rendered PNG proofs |

The scripts live in `apps/mobile/tool/brand/`. They need `@resvg/resvg-js` and `playwright`
installed in a scratch directory outside the repo; they are not app dependencies.
