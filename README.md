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

## Properties

The HUMAStarPathfinder has the following properties:

      @property (nonatomic, weak) id<HUMAStarPathfinderDelegate> delegate;

An object that conforms to the `HUMAStarPathfinderDelegate` protocol. Queried to find information about specific nodes. If nil, all nodes are considered walkable and will use a base movement cost of 10. The default is nil.

      @property (nonatomic, assign) CGSize tileMapSize;

The size of the tile map in tiles. For example, a CGSize of 15, 10 denotes a map that is 15 tiles wide by 10 tiles high.

      @property (nonatomic, assign) CGSize tileSize;

The size of each tile on the tile map in points.

      @property (nonatomic, assign) HUMAStarDistanceType distanceType;

The distance formula used to calculate a node's heuristic (cost to move from one node to the target). The default is `HUMAStarDistanceTypeManhattan`.

      @property (nonatomic, assign) HUMCoodinateSystemOrigin coordinateSystemOrigin;

The origin point for the coordinate system being used. This is used to determine the CGPoint values for the returned path. The start, target, and path points will all be relative to this origin. For example, UIKit has it's origin (0, 0) at the top-left, whereas SpriteKit and Cocos2d have their origin at the bottom-left. The default value is `HUMCoodinateSystemOriginBottomLeft`.

      @property (nonatomic, assign) BOOL pathDiagonally;

If YES, the calculated path can include diagonal paths. If NO, the path will only include horizontal and vertical paths. The default value is YES.

      @property (nonatomic, assign) BOOL ignoreDiagonalBarriers;  

If YES and `pathDiagonally` is YES, diagonal tiles will be allowed provided it is a valid tile. (eg. NE is valid if the tile is valid, ignoring whether either N or E are valid). The default value is NO.

      @property (nonatomic, assign) BOOL pathCanCrossBorders;

If YES, the calculate path is able to cross any obstacle borders provided there is a valid tile in one of the cardinal directions (eg. NE is valid if either N or E is valid). If NO, the calculated path will move around obstacle borders provided there is a valid tile in both cardinal directions. (eg. NE is valid if both N and E are valid). Ignored if `ignoreDiagonalBarriers` is YES. The default value is YES.

## Methods

The HUMAStarPathfinder has the following methods:

      - (NSArray *)findPathFromStart:(CGPoint)start toTarget:(CGPoint)target;

Finds the shortest path from the start point to the target point, avoiding any non-walkable nodes. The returned CGPoints are relative to the specified coordinateSystemOrigin value. If `HUMCoodinateSystemOriginTopLeft`, the position is relative to the top-left of the screen. If `HUMCoodinateSystemOriginBottomLeft`, the position is relative to the bottom-left of the screen.

      - (CGPoint)positionForTileLocation:(CGPoint)tileLocation;

Converts a tile location to the position on screen. The returned CGPoint is relative to the specified coordinateSystemOrigin value. If `HUMCoodinateSystemOriginTopLeft`, the position is relative to the top-left of the screen. If `HUMCoodinateSystemOriginBottomLeft`, the position is relative to the bottom-left of the screen.

      - (CGPoint)tileLocationForPosition:(CGPoint)position;

Converts a position on the screen to the position of the tile. The returned CGPoint is relative to the specified coordinateSystemOrigin value. If `HUMCoodinateSystemOriginTopLeft`, the position is relative to the top-left of the screen. If `HUMCoodinateSystemOriginBottomLeft`, the position is relative to the bottom-left of the screen.

## Delegate

The HUMAStarPathfinder provides one delegate protocol. The HUMAStarPathfinderDelegate has the following required methods:

      - (BOOL)pathfinder:(HUMAStarPathfinder*)pathFinder canWalkToNodeAtTileLocation:(CGPoint)tileLocation;

Determines if a particular node is walkable. Walkability is dictated by the app/game. For example, a mountain may be unwalkable whereas a swamp may be. Returns YES if the node is walkable, NO otherwise.

## Installation
Just add the four files in `HUMAStarPathfinder` to your project

- HUMAStarPathfinder.h and .m
- HUMAStarPathfinderNode.h and .m

or add `HUMAStarPathfinder` to your Podfile if you're using CocoaPods.

## License
Released under the [MIT license](LICENSE).