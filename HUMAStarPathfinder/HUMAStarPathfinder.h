//
//  HUMAStarPathfinder.h
//  HUMAStarPathfinder
//
//  Created by Colin Humber on 7/29/13.
//  Copyright (c) 2013 Colin Humber. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(u_int8_t, HUMAStarDistanceType) {
	/**
	 *	Useful when on a square grid that allows 4 directions of movement. Also known as taxicab distance.
	 *  See http://en.wikipedia.org/wiki/Taxicab_geometry for more details.
	 */
	HUMAStarDistanceTypeManhattan = 0,
	
	/**
	 *	Useful when on a square grid that allows any direction of movement.
	 *  See http://en.wikipedia.org/wiki/Euclidean_distance for more details.
	 */
	HUMAStarDistanceTypeEuclidian,
	
	/**
	 * Useful on a square grid that allows 8 directions of movement. Also known as diagonal distance.
	 * See http://en.wikipedia.org/wiki/Chebyshev_distance for more details.
	 */
	HUMAStarDistanceTypeChebyshev
};

typedef NS_ENUM(u_int8_t, HUMCoodinateSystemOrigin) {
	/**
	 *	The origin (0, 0) is at the top-left of the screen. For example, UIKit.
	 */
	HUMCoodinateSystemOriginTopLeft = 0,
	
	/**
	 *	The origin (0, 0) is at the bottom-left of the screen. For example, SpriteKit and Cocos2d.
	 */
	HUMCoodinateSystemOriginBottomLeft
};

@class HUMAStarPathfinderNode;
@protocol HUMAStarPathfinderDelegate;

/**
 *	An implementation of the A* Pathfinding algorithm for calculating a path between two points on a tile-based grid.
 */
@interface HUMAStarPathfinder : NSObject

///---------------------------
/// @name Properties
///---------------------------

/**
 *	An object that conforms to the HUMAStarPathfinderDelegate protocol. Queried to find information about specific nodes. If nil, all nodes are considered walkable and will use a base movement cost of 10.
 *
 *  The default value is nil.
 */
@property (nonatomic, weak) id<HUMAStarPathfinderDelegate> delegate;

/**
 *	The size of the tile map in tiles. For example, a CGSize of 15, 10 denotes a map that is 15 tiles wide by 10 tiles high.
 */
@property (nonatomic, assign) CGSize tileMapSize;

/**
 *	The size of each tile on the tile map in points.
 */
@property (nonatomic, assign) CGSize tileSize;

/**
 *	The distance formula used to calculate a node's heuristic (cost to move from one node to the target). 
 *
 *  The default value is HUMAStarDistanceTypeManhattan.
 */
@property (nonatomic, assign) HUMAStarDistanceType distanceType;

/**
 *	The origin point for the coordinate system being used. This is used to determine the CGPoint values for the returned path. The 
 *  start, target, and path points will all be relative to this origin.
 *  
 *  For example, UIKit has it's origin (0, 0) at the top-left, whereas SpriteKit and Cocos2d have their origin at the bottom-left.
 *  
 *  The default value is HUMCoodinateSystemOriginBottomLeft.
 */
@property (nonatomic, assign) HUMCoodinateSystemOrigin coordinateSystemOrigin;

/**
 *	If YES, the calculated path can include diagonal paths. If NO, the path will only include horizontal and vertical paths. 
 *
 *  The default value is YES.
 */
@property (nonatomic, assign) BOOL pathDiagonally;

/**
 *	If YES and pathDiagonally = YES, diagonal tiles will be allowed provided it is a valid tile. (eg. NE is valid if the tile is valid,
 *  ignoring whether either N or E are valid)
 *
 *  The default value is NO.
 */
@property (nonatomic, assign) BOOL ignoreDiagonalBarriers;				

/**
 *	If YES, the calculate path is able to cross any obstacle borders provided there is a valid tile in one of the cardinal directions 
 *  (eg. NE is valid if either N or E is valid).
 *
 *  If NO, the calculated path will move around obstacle borders provided there is a valid tile in both cardinal directions. (eg. NE is valid if both N and E are valid).
 *  
 *  Ignored if ignoreDiagonalBarriers is YES.
 *
 *  The default value is YES.
 */
@property (nonatomic, assign) BOOL pathCanCrossBorders;

///---------------------------
/// @name Initialization
///---------------------------

/**
 *	Initializes and returns an newly allocated pathfinder object with the specified tile map size, tile size, and delegate.
 *
 *	@param	mapSize		The size of the map in tiles. For example, a CGSize of 15, 10 denotes a map that is 15 tiles wide by 10 tiles high.
 *	@param	tileSize	The size of each tile on the map in points.
 *	@param	delegate	The pathfinder's delegate, or nil if it doesn't have a delegate.
 *
 *	@return	An initialized pathfinder object or nil, if the pathfinder could not be initialized.
 */
+ (instancetype)pathfinderWithTileMapSize:(CGSize)mapSize tileSize:(CGSize)tileSize delegate:(id<HUMAStarPathfinderDelegate>)delegate;

/**
 *	Initializes and returns an newly allocated pathfinder object with the specified tile map size, tile size, and delegate.
 *
 *	@param	mapSize		The size of the map in tiles. For example, a CGSize of 15, 10 denotes a map that is 15 tiles wide by 10 tiles high.
 *	@param	tileSize	The size of each tile on the map in points.
 *	@param	delegate	The pathfinder's delegate, or nil if it doesn't have a delegate.
 *
 *	@return	An initialized pathfinder object or nil, if the pathfinder could not be initialized.
 */
- (id)initWithTileMapSize:(CGSize)mapSize tileSize:(CGSize)tileSize delegate:(id<HUMAStarPathfinderDelegate>)delegate;

///---------------------------
/// @name Pathfinding
///---------------------------

/**
 *	Finds the shortest path from the start point to the target point avoiding any non-walkable nodes.
 *
 *	@param	start	A CGPoint where the path should start.
 *	@param	target	A CGPoint where the path should end.
 *
 *	@return	An NSArray of NSValue-wrapped CGPoints describing the path from start to target. If the start and target nodes are equal, the target node is not walkable, or there is no
 *			valid path, then nil.
 *  
 *  @note The returned CGPoints are relative to the specified coordinateSystemOrigin value. If HUMCoodinateSystemOriginTopLeft, the position is relative to the top-left of the screen.
 *		  If HUMCoodinateSystemOriginBottomLeft, the position is relative to the bottom-left of the screen.
 */
- (NSArray *)findPathFromStart:(CGPoint)start toTarget:(CGPoint)target;


///---------------------------
/// @name Position Helpers
///---------------------------

/**
 *	Converts a tile location to the position on screen.
 *
 *	@param	tileLocation	The location of the tile within the tile matrix (eg. 2, 0)
 *
 *	@return	The position on screen in the center of the provided tile (eg. 48, 16). 
 *  
 *  @note The returned CGPoint is relative to the specified coordinateSystemOrigin value. If HUMCoodinateSystemOriginTopLeft, the position is relative to the top-left of the screen.
 *		  If HUMCoodinateSystemOriginBottomLeft, the position is relative to the bottom-left of the screen.
 */
- (CGPoint)positionForTileLocation:(CGPoint)tileLocation;

/**
 *	Converts a position on the screen to the position of the tile.
 *
 *	@param	position	A position on the screen (eg. 47, 14)
 *
 *	@return	The location of the tile within the tile matrix (eg. 2, 0)
 *  
 *  @note The provided CGPoint is relative to the specified coordinateSystemOrigin value. If HUMCoodinateSystemOriginTopLeft, the position is relative to the top-left of the screen.
 *		  If HUMCoodinateSystemOriginBottomLeft, the position is relative to the bottom-left of the screen.
 */
- (CGPoint)tileLocationForPosition:(CGPoint)position;

@end


/**
 *	The delegate of a HUMAStarPathFinding object must conform to the HUMAStarPathfinderDelegate protocol. All methods are required and are used to determine the
 *  walkability of tiles.
 */
@protocol HUMAStarPathfinderDelegate <NSObject>
@required
/**
 *	Determines if a particular node is walkable. Walkability is dictated by the app/game. For example, a mountain may be unwalkable whereas a swamp may be.
 *
 *	@param	pathFinder		The pathfinder being used.
 *	@param	tileLocation	The location of the tile within the tile matrix being inspected.
 *
 *	@return	Returns YES if the node at tileLocation is walkable. NO, otherwise.
 */
- (BOOL)pathfinder:(HUMAStarPathfinder*)pathFinder canWalkToNodeAtTileLocation:(CGPoint)tileLocation;
@end