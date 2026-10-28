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

// Visible bounds at alpha > 8: ignore nearly transparent export padding.
const intenseHouseSpriteGeometry = <String, HouseSpriteGeometry>{
  'day': HouseSpriteGeometry(1254, 1254, 59, 41, 1168, 1189),
  'night': HouseSpriteGeometry(1254, 1254, 84, 10, 1115, 1222),
  'eliminated': HouseSpriteGeometry(1254, 1254, 54, 39, 1178, 1189),
};
const horrorHouseSpriteGeometry = <String, HouseSpriteGeometry>{
  'day': HouseSpriteGeometry(1254, 1254, 66, 56, 1143, 1145),
  'night': HouseSpriteGeometry(1254, 1254, 52, 11, 1154, 1219),
  'eliminated': HouseSpriteGeometry(1254, 1254, 96, 15, 1115, 1207),
};
