# HUMAStarPathfinder

A* Pathfinding implementation for iOS (and presumably Mac OS X...I don't have a Mac dev account) games.

HUMAStarPathfinder is tested on iOS 6 and iOS 7 and requires ARC. 

The pathfinding algorithm is generic to work with any game engines (I've tested it with Cocos2d and SpriteKit), but will return a path assuming the game engine's coordinate system has its origin at the bottom-left of the screen.

## Example
Check out the included Xcode project for an example Cocos2d game. Tap anywhere to move the icon, which will avoid any tiles marked in red.

## Usage
```objc
// initialize a pathfinder. Store as an instance variable so you can reference it on touches later. Optionally set a delegate. The tileMap object can be any tile map implementation. In the example, it is a CCTMXTiledMap, but can be anything. The mapSize is the size of the map in tiles. The tileSize is the size of each tile.
self.pathfinder = [HUMAStarPathfinder pathfinderWithTileMapSize:tileMap.mapSize
													                             tileSize:tileMap.tileSize
													                             delegate:self];

// find a path from the start point to the target point. The target could be where a tap occured or some other point determined programmatically. Returned is an array of NSValue-wrapped CGPoints that describe the path. From here you can create a CGPath or UIBezier path for a sprite to follow, move a sprite from point to point, etc.
NSArray *path = [self.pathfinder findPathFromStart:startPoint
										                      toTarget:targetPoint];

...

// elsewhere, you must implement the delegate method to determine if a node is walkable. For example, a mountain may not be walkable but grass is
- (BOOL)pathfinder:(HUMAStarPathfinder *)pathFinder canWalkToNodeAtTileLocation:(CGPoint)tileLocation {
  CCTMXLayer *meta = [self.tileMap layerNamed:@"Meta"];
  uint8_t gid = [meta tileGIDAt:tileLocation];

  BOOL walkable = YES;
  
  if (gid) {
    NSDictionary *properties = [self.tileMap propertiesForGID:gid];
    walkable = [properties[@"walkable"] boolValue];
  }
  
  return walkable;
}
```

See the [header](HUMAStarPathfinder/HUMAStarPathfinder.h) for full documentation.

## Installation
Just add the four files in `HUMAStarPathfinder` to your project

- HUMAStarPathfinder.h and .m
- HUMAStarPathfinderNode.h and .m

or add `HUMAStarPathfinder` to your Podfile if you're using CocoaPods.

## License
Released under the [MIT license](LICENSE)
