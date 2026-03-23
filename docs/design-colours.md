# Kiwifruit Design Colour Palette

A reference for all colours used across the app so far. Use these values when building new views to stay consistent.

---

## Brand Colours

| Name | Hex | Usage |
|------|-----|-------|
| Kiwi | `#A3C985` | Primary accent — buttons, highlights, JOIN NOW |
| Kiwi Light | `#E6F0DC` | Subtle backgrounds — streak badge, LOAD MORE button |
| Tan | `#D1BFAe` | Start Session button (Focus), Discover More cards |
| Tan Light | `#F5E6D3` | Soft warm backgrounds |

---

## UI Colours

| Name | Hex | Usage |
|------|-----|-------|
| Text / Border | `#2D3748` | All text, all hand-drawn borders |
| UI Border (subtle) | `#E2E8F0` | Light dividers, subtle borders |
| UI Background | `#FAFAFA` | Page background (Focus) |
| Teal | `#88C0D0` | Launch speed reading button (Focus) |

---

## Card Backgrounds

| Name | Hex | Notes |
|------|-----|-------|
| Teal Card | `#CFE6EC` | Your Challenges cards, Recent Updates (Profile) — preblended `#88C0D0` at 40% on white |
| Tan Card | `#D1BFAe` | Discover More cards — same as Tan brand colour |

---

## Notes

- **Hand-drawn border** is always `#2D3748` at `lineWidth: 2` or `3`
- **Sketch shadow** uses `.sketchShadow()` / `.sketchShadowCircle()` from `SketchStyle.swift`
- Avoid using `opacity()` on card backgrounds — use the preblended hex value instead to ensure consistent rendering across light/dark contexts
