// Généré par tools/sync_eliminated_house.py ; sources PNG conservées intactes.
class HouseSpriteGeometry {
  const HouseSpriteGeometry(
    this.width,
    this.height,
    this.left,
    this.top,
    this.visibleWidth,
    this.visibleHeight,
  );
  final double width, height, left, top, visibleWidth, visibleHeight;
}

const houseSpriteGeometry = <String, HouseSpriteGeometry>{
  'day': HouseSpriteGeometry(1024, 1024, 145, 139, 738, 732),
  'night': HouseSpriteGeometry(418, 414, 0, 0, 418, 414),
  'eliminated': HouseSpriteGeometry(1024, 1024, 143, 137, 740, 734),
};
