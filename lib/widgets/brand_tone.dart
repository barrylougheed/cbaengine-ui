/// Which colour of the brand logos to draw. The artwork is a single colour, so
/// it comes in versions for the background it sits on:
///
/// * [green], the brand green (#2C3F33), for white;
/// * [cream] (#F6F3E9), for the deep olive of the hero and the footer.
///
/// The name is the end of the asset's file name (`sloth_icon_green.png`).
enum BrandTone {
  green('green'),
  cream('cream');

  const BrandTone(this.fileSuffix);

  final String fileSuffix;
}
