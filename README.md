# HUMAStarPathfinder

A* Pathfinding implementation for iOS (and presumably Mac OS X...I don't have a Mac dev account) games.

HUMAStarPathfinder is tested on iOS 6 and iOS 7 and requires ARC. Tested with Cocos2d and SpriteKit, but will work with any game whose coordinate system has the origin set bottom-left.

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
```

See the [header](HUMAStarPathfinder/HUMAStarPathfinder.h) for full documentation.

## Installation
Just add the four files in `HUMAStarPathfinder` to your project.

## License
Released under the [MIT license](LICENSE)
