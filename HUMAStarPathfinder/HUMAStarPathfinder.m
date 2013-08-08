//
//  HUMAStarPathfinder.m
//  HUMAStarPathfinder
//
//  Created by Colin Humber on 7/29/13.
//  Copyright (c) 2013 Colin Humber. All rights reserved.
//

#import "HUMAStarPathfinder.h"
#import "HUMAStarPathfinderNode.h"

@interface HUMAStarPathfinder () {
	struct {
		unsigned int delegateCanWalkToNodeAtTileLocation:1;
	} _delegateFlags;
}

@property (nonatomic, strong) HUMAStarPathfinderNode *startNode;
@property (nonatomic, strong) HUMAStarPathfinderNode *targetNode;
@property (nonatomic, assign) CGPoint startPoint;

@property (nonatomic, assign) NSInteger baseMovementCost;
@property (nonatomic, assign) CGFloat diagonalMovementCost;

@property (nonatomic, copy) NSMutableArray *openList;
@property (nonatomic, copy) NSMutableArray *closedList;
@property (nonatomic, copy) NSMutableArray *shortestPath;
@end

@implementation HUMAStarPathfinder

- (id)init {
	NSLog(@"External clients are not allowed to call -[%@ init] directly! Please use -initWithTileMapSize:tileSize: or +pathfinderWithTileMapSize:tileSize: instead.", [self class]);
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

+ (instancetype)pathfinderWithTileMapSize:(CGSize)mapSize tileSize:(CGSize)tileSize delegate:(id<HUMAStarPathfinderDelegate>)delegate {
	return [[self alloc] initWithTileMapSize:mapSize tileSize:tileSize delegate:delegate];
}

- (id)initWithTileMapSize:(CGSize)mapSize tileSize:(CGSize)tileSize delegate:(id<HUMAStarPathfinderDelegate>)delegate {
	self = [super init];
	if (self) {
		_tileMapSize = mapSize;
		_tileSize = tileSize;
		_pathDiagonally = YES;
		_pathCanCrossBorders = YES;
		_ignoreDiagonalBarriers = NO;
		_distanceType = HUMAStarDistanceTypeManhattan;
		_coordinateSystemOrigin = HUMCoodinateSystemOriginBottomLeft;
		_baseMovementCost = 10;
		_diagonalMovementCost = sqrtf((_baseMovementCost * _baseMovementCost) + (_baseMovementCost * _baseMovementCost));
		_openList = [NSMutableArray array];
		_closedList = [NSMutableArray array];
		_shortestPath = [NSMutableArray array];
		
		[self setDelegate:delegate];
	}
	
	return self;	
}

#pragma mark - Properties
- (void)setDelegate:(id<HUMAStarPathfinderDelegate>)delegate {
	_delegate = delegate;
	
	if ([_delegate respondsToSelector:@selector(pathfinder:canWalkToNodeAtTileLocation:)]) {
		_delegateFlags.delegateCanWalkToNodeAtTileLocation = YES;
	}
}

#pragma mark - Pathfinding
- (NSArray *)findPathFromStart:(CGPoint)start toTarget:(CGPoint)target {
	self.startPoint = start;
	
	CGPoint startTileLocation = [self tileLocationForPosition:start];
	CGPoint targetTileLocation = [self tileLocationForPosition:target];
	
	self.startNode = [HUMAStarPathfinderNode nodeWithLocation:startTileLocation];
	self.targetNode = [HUMAStarPathfinderNode nodeWithLocation:targetTileLocation];
	
	if ([self.startNode isEqual:self.targetNode]) {
		return nil;
	}
	
	// check to make sure we can actually get a path to the target node
	if (![self canWalkToNodeAtTileLocation:targetTileLocation]) {
		return nil;
	}

	[self.openList removeAllObjects];
	[self.closedList removeAllObjects];
	[self.shortestPath removeAllObjects];
	
	// determine if the end node is walkable? (eg. on a wall, sky, other obstacle)

	// 1) Add the current node to the open list
	[self insertInOpenSteps:self.startNode];
	
	while (self.openList.count > 0) {
		// 2) Get the node with the lower F value
		HUMAStarPathfinderNode *checkingNode = self.openList[0];
				
		// 3) Add the checking node to the closed list and remove it from the open list
		[self.openList removeObject:checkingNode];
		[self.closedList addObject:checkingNode];
		
		if ([checkingNode isEqual:self.targetNode]) {
			self.targetNode.parentNode = checkingNode.parentNode;
			
			// 6) Traceback from the target node to the start node and build out the path
			[self generatePath];
			break;
		}
		
		// 4) Get all valid adjacent nodes
		NSArray *neighbors = [self findAdjacentNodesForNode:checkingNode];
		
		// 5) Determine the values for the current node's adjacent nodes (N, NE, E, SE, S, SW, W, NW)
		for (HUMAStarPathfinderNode *node in neighbors) {
			[self determineNodeValuesForAdjacentNode:node currentNode:checkingNode];
		}
	}
	
	return [NSArray arrayWithArray:self.shortestPath];
}

/**
 *	Sets any new G, H, and parent values for the provided adjacent node.
 *
 *	@param	adjacentNode	The node that is adjacent to the currentNode.
 *	@param	currentNode		The node that is the origin for the adjacentNode.
 */
- (void)determineNodeValuesForAdjacentNode:(HUMAStarPathfinderNode *)adjacentNode currentNode:(HUMAStarPathfinderNode *)currentNode {
	BOOL neighborInOpenList = [self.openList containsObject:adjacentNode];
	HUMAStarPathfinderNode *neighborNode = neighborInOpenList ? [self.openList objectAtIndex:[self.openList indexOfObject:adjacentNode]] : adjacentNode;
	
	if ([self.closedList containsObject:neighborNode]) {
		return;
	}
	
	NSInteger newGCost = currentNode.gCost + [self costToMoveFromNode:currentNode toNode:adjacentNode];
	
	if (neighborInOpenList) {
		neighborNode = [self.openList objectAtIndex:[self.openList indexOfObject:adjacentNode]];
	}
	
	if (neighborInOpenList == NO || newGCost < adjacentNode.gCost) {
		neighborNode.gCost = newGCost;
		neighborNode.hValue = neighborNode.hValue > 0 ? adjacentNode.hValue : [self calculateHeuristicForNode:neighborNode];
		neighborNode.parentNode = currentNode;
		
		if (neighborInOpenList == NO) {
			[self insertInOpenSteps:neighborNode];
		}
		else {
			[self.openList removeObjectAtIndex:[self.openList indexOfObject:neighborNode]];
			[self insertInOpenSteps:neighborNode];
			// the neighbor can be reached with a lower gCost changing the fValue.
			// we need to adjust the open list to compensate. The may be automatically done when adding an object to the open list
		}
	}
}

/**
 *	Generates an array of points connecting the start node to the target node by backtracing through each parent, starting at the target node.
 */
- (void)generatePath {
	HUMAStarPathfinderNode *node = self.targetNode;
	
	while (node.parentNode) {
		CGPoint screenPosition = [self positionForTileLocation:node.tileLocation];
		[self.shortestPath insertObject:[NSValue valueWithCGPoint:screenPosition] atIndex:0];
		node = node.parentNode;
	}
	
	[self.shortestPath insertObject:[NSValue valueWithCGPoint:self.startPoint] atIndex:0];
}

/**
 *	Calculates the cost to move from one node to another.
 *
 *	@param	fromNode	The start node.
 *	@param	toNode	The destination node.
 *
 *	@return	The base movement cost, if moving horizontally or vertically. The diagonal movement cost, if moving diagonally.
 */
- (NSInteger)costToMoveFromNode:(HUMAStarPathfinderNode *)fromNode toNode:(HUMAStarPathfinderNode *)toNode {
	CGPoint fromLocation = fromNode.tileLocation;
	CGPoint toLocation = toNode.tileLocation;
	
	if ((fromLocation.x != toLocation.x) && (fromLocation.y != toLocation.y)) {
		return self.diagonalMovementCost;
	}
	else {
		return self.baseMovementCost;
	}
}

/**
 *	Calculates the estimated minimum cost (heuristic) the provided node to the target node using the set heuristic type.
 *
 *	@param	node	The source node being used to calculate the heuristic.
 *
 *	@return	The provided node's heuristic.
 */
- (CGFloat)calculateHeuristicForNode:(HUMAStarPathfinderNode *)node {
	CGPoint nodeTileLocation = node.tileLocation;
	CGPoint targetTileLocation = self.targetNode.tileLocation;
	
	NSInteger distanceX = abs(nodeTileLocation.x - targetTileLocation.x);
	NSInteger distanceY = abs(nodeTileLocation.y - targetTileLocation.y);

	CGFloat heuristic = 0.0f;
	
	switch (self.distanceType) {
		case HUMAStarDistanceTypeEuclidian:
			heuristic = sqrtf((distanceX * distanceX) + (distanceY * distanceY));
			break;
			
		case HUMAStarDistanceTypeChebyshev:
			heuristic = MAX(distanceX, distanceY);
			break;
			
		case HUMAStarDistanceTypeManhattan:
		default:
			heuristic = distanceX + distanceY;
			break;
	}
	
	
	return heuristic;
}

/**
 *	Finds all valid adjacent nodes neighboring the provided node.
 *
 *	@param	node	The origin node.
 *
 *	@return	An NSArray of all valid adjacent nodes.
 */
- (NSArray *)findAdjacentNodesForNode:(HUMAStarPathfinderNode *)node {
	CGPoint nodeTileLocation = node.tileLocation;
	NSMutableArray *neighbors = [NSMutableArray arrayWithCapacity:8];
	BOOL hasNorth = NO, hasSouth = NO, hasEast = NO, hasWest = NO;
	BOOL checkNorthEast = YES, checkSouthEast = YES, checkSouthWest = YES, checkNorthWest = YES;
	// link adjacent nodes to the checking node ignoring whether they are walkable or not.
	// if a tile location is outside the bounds of the map then ignore them

	// N node
	CGPoint tileLocation = CGPointMake(nodeTileLocation.x, nodeTileLocation.y - 1);
	if ([self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
		[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		hasNorth = YES;
	}
	
	// E node
	tileLocation = CGPointMake(node.tileLocation.x + 1, node.tileLocation.y);
	if ([self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
		[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		hasEast = YES;
	}
	
	// S node
	tileLocation = CGPointMake(node.tileLocation.x, node.tileLocation.y + 1);
	if ([self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
		[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		hasSouth = YES;
	}
	
	// W node
	tileLocation = CGPointMake(node.tileLocation.x - 1, node.tileLocation.y);
	if ([self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
		[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		hasWest = YES;
	}
	
	if (self.pathDiagonally) {
		if (!self.ignoreDiagonalBarriers) {
			// determine if we have diagonal neighbors. If crossing borders is allowed, we only need one of the two cardinal
			// tiles to be valid. Otherwise, we need both.
			if (self.pathCanCrossBorders) {
				checkNorthEast = hasNorth || hasEast;
				checkSouthEast = hasSouth || hasEast;
				checkSouthWest = hasSouth || hasWest;
				checkNorthWest = hasNorth || hasWest;
			}
			else {
				checkNorthEast = hasNorth && hasEast;
				checkSouthEast = hasSouth && hasEast;
				checkSouthWest = hasSouth && hasWest;
				checkNorthWest = hasNorth && hasWest;
			}
		}
				
		// NE node
		tileLocation = CGPointMake(node.tileLocation.x + 1, node.tileLocation.y - 1);
		if (checkNorthEast && [self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
			[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		}
		
		// SE node
		tileLocation = CGPointMake(node.tileLocation.x + 1, node.tileLocation.y + 1);
		if (checkSouthEast && [self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
			[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		}

		// SW node
		tileLocation = CGPointMake(node.tileLocation.x - 1, node.tileLocation.y + 1);
		if (checkSouthWest &&[self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
			[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		}
		
		// NW node
		tileLocation = CGPointMake(node.tileLocation.x - 1, node.tileLocation.y - 1);
		if (checkNorthWest &&[self isTileValidAtLocation:tileLocation] && [self canWalkToNodeAtTileLocation:tileLocation]) {
			[neighbors addObject:[HUMAStarPathfinderNode nodeWithLocation:tileLocation]];
		}
	}
	return neighbors;
}

#pragma mark - Tile Helpers
/**
 *	Determines if a node is walkable. If a delegate is provided, the delegate will be asked. Otherwise, YES.
 *
 *	@param	location	The tile location in question.
 *
 *	@return	YES, if the tile can be traversed. NO, otherwise.
 */
- (BOOL)canWalkToNodeAtTileLocation:(CGPoint)location {
	BOOL walkable = YES;
	
	if (_delegateFlags.delegateCanWalkToNodeAtTileLocation) {
		walkable = [self.delegate pathfinder:self canWalkToNodeAtTileLocation:location];
	}
	
	return walkable;
}

/**
 *	Determines if a tile is valid based on its location.
 *
 *	@param	tileLocation		The location of the tile within the tile matrix.
 *
 *	@return	YES, if the tile is valid. NO, otherwise.
 */
- (BOOL)isTileValidAtLocation:(CGPoint)tileLocation {
	BOOL validTile = YES;
	if (tileLocation.x < 0 ||
		tileLocation.y < 0 ||
		tileLocation.x >= self.tileMapSize.width ||
		tileLocation.y >= self.tileMapSize.height) {
		validTile = NO;
	}
	
	return validTile;
}

- (CGPoint)tileLocationForPosition:(CGPoint)position {
	CGSize tileSize = self.tileSize;
	CGSize mapSize = self.tileMapSize;
	
	NSInteger x = position.x / tileSize.width;
	NSInteger y = 0;
	
	if (self.coordinateSystemOrigin == HUMCoodinateSystemOriginBottomLeft) {
		y = ((mapSize.height * tileSize.height) - position.y) / tileSize.height;
	}
	else if (self.coordinateSystemOrigin == HUMCoodinateSystemOriginTopLeft) {
		y = position.y / tileSize.height;
	}
	
	return CGPointMake(x, y);
}

- (CGPoint)positionForTileLocation:(CGPoint)tileLocation {
	CGSize mapSize = self.tileMapSize;
	CGSize tileSize = self.tileSize;

	CGFloat x = (tileLocation.x * tileSize.width) + tileSize.width / 2.0f;
	CGFloat y = 0.0f;
	
	if (self.coordinateSystemOrigin == HUMCoodinateSystemOriginBottomLeft) {
		y = (mapSize.height * tileSize.height) - (tileLocation.y * tileSize.height) - tileSize.height / 2.0f;
	}
	else if (self.coordinateSystemOrigin == HUMCoodinateSystemOriginTopLeft) {
		y = (tileLocation.y * tileSize.height) + tileSize.height / 2.0f;
	}
	
	return CGPointMake(x, y);
}

#pragma mark - CHANGE LATER TO BINARY HEAP
- (void)insertInOpenSteps:(HUMAStarPathfinderNode *)node {
	int stepFScore = node.fValue; // Compute only once the step F score's
	int count = [self.openList count];
	int i = 0; // It will be the index at which we will insert the step
	for (; i < count; i++) {
		if (stepFScore <= [[self.openList objectAtIndex:i] fValue]) { // if the step F score's is lower or equals to the step at index i
			// Then we found the index at which we have to insert the new step
			break;
		}
	}
	// Insert the new step at the good index to preserve the F score ordering
	[self.openList insertObject:node atIndex:i];
}


- (HUMAStarPathfinderNode *)smallestFValueNode {
	int smallest = NSIntegerMax;
	HUMAStarPathfinderNode *smallestNode = nil;
	
	for (HUMAStarPathfinderNode *node in self.openList) {
		if (node.fValue < smallest) {
			smallest = node.fValue;
			smallestNode = node;
		}
	}
	
	return smallestNode;
}

@end
