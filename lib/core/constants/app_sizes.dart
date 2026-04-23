/// Spacing, radius, and dimension tokens used across the ATELIER app.
///
/// These centralise the magic numbers that appear in padding, margins,
/// border radii, and fixed dimensions so every screen stays consistent.
class AppSizes {
  // ── Spacing ──────────────────────────────────────────────
  static const double spacingXxs = 4;
  static const double spacingXs = 6;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 20;
  static const double spacingXxl = 24;
  static const double spacing3xl = 32;
  static const double spacing4xl = 40;
  static const double spacing5xl = 48;

  // ── Border Radii ─────────────────────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 18;
  static const double radiusXl = 22;
  static const double radiusXxl = 24;
  static const double radiusCard = 22;
  static const double radiusPill = 999;

  // ── Component Heights ────────────────────────────────────
  static const double buttonHeight = 56;
  static const double inputHeight = 56;
  static const double bottomNavHeight = 76;
  static const double avatarSm = 42;
  static const double avatarMd = 56;
  static const double avatarLg = 64;
  static const double avatarXl = 72;

  // ── Image Thumbnails ─────────────────────────────────────
  static const double thumbnailSm = 84;
  static const double thumbnailMd = 92;
  static const double thumbnailLg = 108;

  // ── Product Grid ─────────────────────────────────────────
  static const double productGridMaxCrossAxis = 240;
  static const double productGridMainAxisExtent = 290;
  static const double productGridSpacing = 16;
  static const double productGridRunSpacing = 18;

  // ── Image Carousel ───────────────────────────────────────
  static const double imageCarouselHeight = 320;

  // ── Page Padding ─────────────────────────────────────────
  static const double pagePaddingH = 16;
  static const double formPaddingH = 24;
}
