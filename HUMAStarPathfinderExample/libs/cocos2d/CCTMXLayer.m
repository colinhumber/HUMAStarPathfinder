/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2009-2010 Ricardo Quesada
 * Copyright (c) 2011 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *
 * TMX Tiled Map support:
 * http://www.mapeditor.org
 *
 */

#import "CCTMXLayer.h"
#import "CCTMXTiledMap.h"
#import "CCTMXXMLParser.h"
#import "CCSprite.h"
#import "CCSpriteBatchNode.h"
#import "CCTextureCache.h"
#import "CCShaderCache.h"
#import "CCGLProgram.h"
#import "Support/CGPointExtension.h"


#pragma mark -
#pragma mark CCTMXLayer

int compareInts (const void * a, const void * b);


@interface CCTMXLayer ()
-(CGPoint) positionForIsoAt:(CGPoint)pos;
-(CGPoint) positionForOrthoAt:(CGPoint)pos;
-(CGPoint) positionForHexAt:(CGPoint)pos;

-(CGPoint) calculateLayerOffset:(CGPoint)offset;

/* optimization methos */
-(CCSprite*) appendTileForGID:(uint32_t)gid at:(CGPoint)pos;
-(CCSprite*) insertTileForGID:(uint32_t)gid at:(CGPoint)pos;
-(CCSprite*) updateTileForGID:(uint32_t)gid at:(CGPoint)pos;

/* The layer recognizes some special properties, like cc_vertez */
-(void) parseInternalProperties;
- (void) setupTileSprite:(CCSprite*) sprite position:(CGPoint)pos withGID:(uint32_t)gid;

-(NSInteger) vertexZForPos:(CGPoint)pos;

// index
-(NSUInteger) atlasIndexForExistantZ:(NSUInteger)z;
-(NSUInteger) atlasIndexForNewZ:(NSUInteger)z;
@end

@implementation CCTMXLayer
@synthesize layerSize = _layerSize, layerName = _layerName, tiles = _tiles;
@synthesize tileset = _tileset;
@synthesize layerOrientation = _layerOrientation;
@synthesize mapTileSize = _mapTileSize;
@synthesize properties = _properties;

#pragma mark CCTMXLayer - init & alloc & dealloc

+(id) layerWithTilesetInfo:(CCTMXTilesetInfo*)tilesetInfo layerInfo:(CCTMXLayerInfo*)layerInfo mapInfo:(CCTMXMapInfo*)mapInfo
{
	return [[[self alloc] initWithTilesetInfo:tilesetInfo layerInfo:layerInfo mapInfo:mapInfo] autorelease];
}

-(id) initWithTilesetInfo:(CCTMXTilesetInfo*)tilesetInfo layerInfo:(CCTMXLayerInfo*)layerInfo mapInfo:(CCTMXMapInfo*)mapInfo
{
	// XXX: is 35% a good estimate ?
	CGSize size = layerInfo.layerSize;
	float totalNumberOfTiles = size.width * size.height;
	float capacity = totalNumberOfTiles * 0.35f + 1; // 35 percent is occupied ?

	CCTexture2D *tex = nil;
	if( tilesetInfo )
		tex = [[CCTextureCache sharedTextureCache] addImage:tilesetInfo.sourceImage];

	if((self = [super initWithTexture:tex capacity:capacity])) {

		// layerInfo
		self.layerName = layerInfo.name;
		_layerSize = size;
		_tiles = layerInfo.tiles;
		_minGID = layerInfo.minGID;
		_maxGID = layerInfo.maxGID;
		_opacity = layerInfo.opacity;
		self.properties = [NSMutableDictionary dictionaryWithDictionary:layerInfo.properties];

		// tilesetInfo
		self.tileset = tilesetInfo;

		// mapInfo
		_mapTileSize = mapInfo.tileSize;
		_layerOrientation = mapInfo.orientation;

		// offset (after layer orientation is set);
		CGPoint offset = [self calculateLayerOffset:layerInfo.offset];
		[self setPosition:CC_POINT_PIXELS_TO_POINTS(offset)];

		_atlasIndexArray = ccCArrayNew(totalNumberOfTiles);

		[self setContentSize:CC_SIZE_PIXELS_TO_POINTS(CGSizeMake( _layerSize.width * _mapTileSize.width, _layerSize.height * _mapTileSize.height ))];

		_useAutomaticVertexZ= NO;
		_vertexZvalue = 0;
	}

	return self;
}

- (void) dealloc
{
	[_layerName release];
	[_tileset release];
	[_reusedTile release];
	[_properties release];

	if( _atlasIndexArray ) {
		ccCArrayFree(_atlasIndexArray);
		_atlasIndexArray = NULL;
	}

	if( _tiles ) {
		free(_tiles);
		_tiles = NULL;
	}

	[super dealloc];
}

-(void) releaseMap
{
	if( _tiles) {
		free( _tiles);
		_tiles = NULL;
	}

	if( _atlasIndexArray ) {
		ccCArrayFree(_atlasIndexArray);
		_atlasIndexArray = NULL;
	}
}

#pragma mark CCTMXLayer - setup Tiles

-(CCSprite*) reusedTileWithRect:(CGRect)rect
{	
	if( ! _reusedTile ) {
		_reusedTile = [[CCSprite alloc] initWithTexture:_textureAtlas.texture rect:rect rotated:NO];
		[_reusedTile setBatchNode:self];
	}
	else
	{
		// XXX HACK: Needed because if "batch node" is nil,
		// then the Sprite'squad will be reset
		[_reusedTile setBatchNode:nil];

		// Re-init the sprite
		[_reusedTile setTextureRect:rect rotated:NO untrimmedSize:rect.size];

		// restore the batch node
		[_reusedTile setBatchNode:self];
	}

	return _reusedTile;
}

-(void) setupTiles
{
	// Optimization: quick hack that sets the image size on the tileset
	_tileset.imageSize = [_textureAtlas.texture contentSizeInPixels];

	// By default all the tiles are aliased
	// pros:
	//  - easier to render
	// cons:
	//  - difficult to scale / rotate / etc.
	[_textureAtlas.texture setAliasTexParameters];

	// Parse cocos2d properties
	[self parseInternalProperties];

	for( NSUInteger y = 0; y < _layerSize.height; y++ ) {
		for( NSUInteger x = 0; x < _layerSize.width; x++ ) {

			NSUInteger pos = x + _layerSize.width * y;
			uint32_t gid = _tiles[ pos ];

			// gid are stored in little endian.
			// if host is big endian, then swap
			gid = CFSwapInt32LittleToHost( gid );

			// XXX: gid == 0 --> empty tile
			if( gid != 0 ) {
				[self appendTileForGID:gid at:ccp(x,y)];

				// Optimization: update min and max GID rendered by the layer
				_minGID = MIN(gid, _minGID);
				_maxGID = MAX(gid, _maxGID);
//				_minGID = MIN((gid & kFlippedMask), _minGID);
//				_maxGID = MAX((gid & kFlippedMask), _maxGID);
			}
		}
	}

	NSAssert( _maxGID >= _tileset.firstGid &&
			 _minGID >= _tileset.firstGid, @"TMX: Only 1 tilset per layer is supported");
}

#pragma mark CCTMXLayer - Properties

-(id) propertyNamed:(NSString *)propertyName
{
	return [_properties valueForKey:propertyName];
}

-(void) parseInternalProperties
{
	// if cc_vertex=automatic, then tiles will be rendered using vertexz

	NSString *vertexz = [self propertyNamed:@"cc_vertexz"];
	if( vertexz ) {

		// If "automatic" is on, then parse the "cc_alpha_func" too
		if( [vertexz isEqualToString:@"automatic"] ) {
			_useAutomaticVertexZ = YES;

			NSString *alphaFuncVal = [self propertyNamed:@"cc_alpha_func"];
			float alphaFuncValue = [alphaFuncVal floatValue];

			self.shaderProgram = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionTextureColorAlphaTest];

			GLint alphaValueLocation = glGetUniformLocation(self.shaderProgram.program, kCCUniformAlphaTestValue_s);

			// NOTE: alpha test shader is hard-coded to use the equivalent of a glAlphaFunc(GL_GREATER) comparison
			[self.shaderProgram setUniformLocation:alphaValueLocation withF1:alphaFuncValue];
		}
		else
			_vertexZvalue = [vertexz intValue];
	}
}

#pragma mark CCTMXLayer - obtaining tiles/gids

-(CCSprite*) tileAt:(CGPoint)pos
{
	NSAssert( pos.x < _layerSize.width && pos.y < _layerSize.height && pos.x >=0 && pos.y >=0, @"TMXLayer: invalid position");
	NSAssert( _tiles && _atlasIndexArray, @"TMXLayer: the tiles map has been released");

	CCSprite *tile = nil;
	uint32_t gid = [self tileGIDAt:pos];

	// if GID == 0, then no tile is present
	if( gid ) {
		int z = pos.x + pos.y * _layerSize.width;
		tile = (CCSprite*) [self getChildByTag:z];

		// tile not created yet. create it
		if( ! tile ) {
			CGRect rect = [_tileset rectForGID:gid];
			rect = CC_RECT_PIXELS_TO_POINTS(rect);
			tile = [[CCSprite alloc] initWithTexture:self.texture rect:rect];
			[tile setBatchNode:self];

            CGPoint p = [self positionAt:pos];
            [tile setPosition:p];
			[tile setVertexZ: [self vertexZForPos:pos]];
			tile.anchorPoint = CGPointZero;
			[tile setOpacity:_opacity];

			NSUInteger indexForZ = [self atlasIndexForExistantZ:z];
			[self addSpriteWithoutQuad:tile z:indexForZ tag:z];
			[tile release];
		}
	}
	return tile;
}

-(uint32_t) tileGIDAt:(CGPoint)pos
{
	return [self tileGIDAt:pos withFlags:NULL];
}

-(uint32_t) tileGIDAt:(CGPoint)pos withFlags:(ccTMXTileFlags*)flags
{
	NSAssert( pos.x < _layerSize.width && pos.y < _layerSize.height && pos.x >=0 && pos.y >=0, @"TMXLayer: invalid position");
	NSAssert( _tiles && _atlasIndexArray, @"TMXLayer: the tiles map has been released");

	NSInteger idx = pos.x + pos.y * _layerSize.width;

	// Bits on the far end of the 32-bit global tile ID are used for tile flags

	uint32_t tile = _tiles[idx];
	
	// issue1264, flipped tiles can be changed dynamically
	if (flags)
		*flags = tile & kCCFlipedAll;

	return ( tile & kCCFlippedMask);
}

#pragma mark CCTMXLayer - adding helper methods

- (void) setupTileSprite:(CCSprite*) sprite position:(CGPoint)pos withGID:(uint32_t)gid
{
	[sprite setPosition: [self positionAt:pos]];
	[sprite setVertexZ: [self vertexZForPos:pos]];
	sprite.anchorPoint = CGPointZero;
	[sprite setOpacity:_opacity];
	
	//issue 1264, flip can be undone as well
	sprite.flipX = NO;
	sprite.flipY = NO;
	sprite.rotation = 0;
	sprite.anchorPoint = ccp(0,0);
	
	// Rotation in tiled is achieved using 3 flipped states, flipping across the horizontal, vertical, and diagonal axes of the tiles.
	if (gid & kCCTMXTileDiagonalFlag)
	{
		// put the anchor in the middle for ease of rotation.
		sprite.anchorPoint = ccp(0.5f,0.5f);
		[sprite setPosition: ccp([self positionAt:pos].x + sprite.contentSize.height/2,
								 [self positionAt:pos].y + sprite.contentSize.width/2 )
		 ];

		uint32_t flag = gid & (kCCTMXTileHorizontalFlag | kCCTMXTileVerticalFlag );

		// handle the 4 diagonally flipped states.
		if (flag == kCCTMXTileHorizontalFlag)
		{
			sprite.rotation = 90;
		}
		else if (flag == kCCTMXTileVerticalFlag)
		{
			sprite.rotation = 270;
		}
		else if (flag == (kCCTMXTileVerticalFlag | kCCTMXTileHorizontalFlag) )
		{
			sprite.rotation = 90;
			sprite.flipX = YES;
		}
		else
		{
			sprite.rotation = 270;
			sprite.flipX = YES;
		}
	}
	else
	{
		if (gid & kCCTMXTileHorizontalFlag)
			sprite.flipX = YES;
		
		if (gid & kCCTMXTileVerticalFlag)
			sprite.flipY = YES;
	}
}

-(CCSprite*) insertTileForGID:(uint32_t)gid at:(CGPoint)pos
{
	CGRect rect = [_tileset rectForGID:gid];
	rect = CC_RECT_PIXELS_TO_POINTS(rect);

	NSInteger z = pos.x + pos.y * _layerSize.width;

	CCSprite *tile = [self reusedTileWithRect:rect];

	[self setupTileSprite:tile position:pos withGID:gid];

	// get atlas index
	NSUInteger indexForZ = [self atlasIndexForNewZ:z];

	// Optimization: add the quad without adding a child
	[self insertQuadFromSprite:tile quadIndex:indexForZ];

	// insert it into the local atlasindex array
	ccCArrayInsertValueAtIndex(_atlasIndexArray, (void*)z, indexForZ);

	// update possible children
	CCSprite *sprite;
	CCARRAY_FOREACH(_children, sprite) {
		NSUInteger ai = [sprite atlasIndex];
		if( ai >= indexForZ)
			[sprite setAtlasIndex: ai+1];
	}

	_tiles[z] = gid;

	return tile;
}

-(CCSprite*) updateTileForGID:(uint32_t)gid at:(CGPoint)pos
{
	CGRect rect = [_tileset rectForGID:gid];
	rect = CC_RECT_PIXELS_TO_POINTS(rect);

	int z = pos.x + pos.y * _layerSize.width;

	CCSprite *tile = [self reusedTileWithRect:rect];

	[self setupTileSprite:tile position:pos withGID:gid];
	
	// get atlas index
	NSUInteger indexForZ = [self atlasIndexForExistantZ:z];

	[tile setAtlasIndex:indexForZ];
	[tile setDirty:YES];
	[tile updateTransform];
	_tiles[z] = gid;

	return tile;
}


// used only when parsing the map. useless after the map was parsed
// since lot's of assumptions are no longer true
-(CCSprite*) appendTileForGID:(uint32_t)gid at:(CGPoint)pos
{
	CGRect rect = [_tileset rectForGID:gid];
	rect = CC_RECT_PIXELS_TO_POINTS(rect);

	NSInteger z = pos.x + pos.y * _layerSize.width;

	CCSprite *tile = [self reusedTileWithRect:rect];

	[self setupTileSprite:tile position:pos withGID:gid];

	// optimization:
	// The difference between appendTileForGID and insertTileforGID is that append is faster, since
	// it appends the tile at the end of the texture atlas
	NSUInteger indexForZ = _atlasIndexArray->num;


	// don't add it using the "standard" way.
	[self insertQuadFromSprite:tile quadIndex:indexForZ];


	// append should be after addQuadFromSprite since it modifies the quantity values
	ccCArrayInsertValueAtIndex(_atlasIndexArray, (void*)z, indexForZ);

	return tile;
}

#pragma mark CCTMXLayer - atlasIndex and Z

int compareInts (const void * a, const void * b)
{
	return ( *(int*)a - *(int*)b );
}

-(NSUInteger) atlasIndexForExistantZ:(NSUInteger)z
{
	NSInteger key = z;
	NSInteger *item = bsearch((void*)&key, (void*)&_atlasIndexArray->arr[0], _atlasIndexArray->num, sizeof(void*), compareInts);

	NSAssert( item, @"TMX atlas index not found. Shall not happen");

	NSUInteger index = ((NSInteger)item - (NSInteger)_atlasIndexArray->arr) / sizeof(void*);
	return index;
}

-(NSUInteger)atlasIndexForNewZ:(NSUInteger)z
{
	// XXX: This can be improved with a sort of binary search
	NSUInteger i = 0;
	for(i = 0; i< _atlasIndexArray->num; i++) {
		NSUInteger val = (NSUInteger) _atlasIndexArray->arr[i];
		if( z < val )
			break;
	}
	return i;
}

#pragma mark CCTMXLayer - adding / remove tiles
-(void) setTileGID:(uint32_t)gid at:(CGPoint)pos
{
	[self setTileGID:gid at:pos withFlags:NO];	
}

-(void) setTileGID:(uint32_t)gid at:(CGPoint)pos withFlags:(ccTMXTileFlags)flags
{
	NSAssert( pos.x < _layerSize.width && pos.y < _layerSize.height && pos.x >=0 && pos.y >=0, @"TMXLayer: invalid position");
	NSAssert( _tiles && _atlasIndexArray, @"TMXLayer: the tiles map has been released");
	NSAssert( gid == 0 || gid >= _tileset.firstGid, @"TMXLayer: invalid gid" );

	ccTMXTileFlags currentFlags;
	uint32_t currentGID = [self tileGIDAt:pos withFlags:&currentFlags];
	
	if (currentGID != gid || currentFlags != flags )
	{
		uint32_t gidAndFlags = gid | flags;

		// setting gid=0 is equal to remove the tile
		if( gid == 0 )
			[self removeTileAt:pos];

		// empty tile. create a new one
		else if( currentGID == 0 )
			[self insertTileForGID:gidAndFlags at:pos];

		// modifying an existing tile with a non-empty tile
		else {

			NSUInteger z = pos.x + pos.y * _layerSize.width;
			CCSprite *sprite = (CCSprite*)[self getChildByTag:z];
			if( sprite ) {
				CGRect rect = [_tileset rectForGID:gid];
				rect = CC_RECT_PIXELS_TO_POINTS(rect);

				[sprite setTextureRect:rect rotated:NO untrimmedSize:rect.size];

				if (flags) 
					[self setupTileSprite:sprite position:[sprite position] withGID:gidAndFlags];

				_tiles[z] = gidAndFlags;
			} else
				[self updateTileForGID:gidAndFlags at:pos];
		}
	}
}

-(void) addChild: (CCNode*)node z:(NSInteger)z tag:(NSInteger)tag
{
	NSAssert(NO, @"addChild: is not supported on CCTMXLayer. Instead use setTileGID:at:/tileAt:");
}

-(void) removeChild:(CCSprite*)sprite cleanup:(BOOL)cleanup
{
	// allows removing nil objects
	if( ! sprite )
		return;

	NSAssert( [_children containsObject:sprite], @"Tile does not belong to TMXLayer");

	NSUInteger atlasIndex = [sprite atlasIndex];
	NSUInteger zz = (NSUInteger) _atlasIndexArray->arr[atlasIndex];
	_tiles[zz] = 0;
	ccCArrayRemoveValueAtIndex(_atlasIndexArray, atlasIndex);
	[super removeChild:sprite cleanup:cleanup];
}

-(void) removeTileAt:(CGPoint)pos
{
	NSAssert( pos.x < _layerSize.width && pos.y < _layerSize.height && pos.x >=0 && pos.y >=0, @"TMXLayer: invalid position");
	NSAssert( _tiles && _atlasIndexArray, @"TMXLayer: the tiles map has been released");

	uint32_t gid = [self tileGIDAt:pos];

	if( gid ) {

		NSUInteger z = pos.x + pos.y * _layerSize.width;
		NSUInteger atlasIndex = [self atlasIndexForExistantZ:z];

		// remove tile from GID map
		_tiles[z] = 0;

		// remove tile from atlas position array
		ccCArrayRemoveValueAtIndex(_atlasIndexArray, atlasIndex);

		// remove it from sprites and/or texture atlas
		id sprite = [self getChildByTag:z];
		if( sprite )
			[super removeChild:sprite cleanup:YES];
		else {
			[_textureAtlas removeQuadAtIndex:atlasIndex];

			// update possible children
			CCARRAY_FOREACH(_children, sprite) {
				NSUInteger ai = [sprite atlasIndex];
				if( ai >= atlasIndex) {
					[sprite setAtlasIndex: ai-1];
				}
			}
		}
	}
}

#pragma mark CCTMXLayer - obtaining positions, offset

-(CGPoint) calculateLayerOffset:(CGPoint)pos
{
	CGPoint ret = CGPointZero;
	switch( _layerOrientation ) {
		case CCTMXOrientationOrtho:
			ret = ccp( pos.x * _mapTileSize.width, -pos.y *_mapTileSize.height);
			break;
		case CCTMXOrientationIso:
			ret = ccp( (_mapTileSize.width /2) * (pos.x - pos.y),
					  (_mapTileSize.height /2 ) * (-pos.x - pos.y) );
			break;
		case CCTMXOrientationHex:
			NSAssert(CGPointEqualToPoint(pos, CGPointZero), @"offset for hexagonal map not implemented yet");
			break;
	}
	return ret;
}

-(CGPoint) positionAt:(CGPoint)pos
{
	CGPoint ret = CGPointZero;
	switch( _layerOrientation ) {
		case CCTMXOrientationOrtho:
			ret = [self positionForOrthoAt:pos];
			break;
		case CCTMXOrientationIso:
			ret = [self positionForIsoAt:pos];
			break;
		case CCTMXOrientationHex:
			ret = [self positionForHexAt:pos];
			break;
	}

	ret = CC_POINT_PIXELS_TO_POINTS( ret );
	return ret;
}

-(CGPoint) positionForOrthoAt:(CGPoint)pos
{
	CGPoint xy = {
		pos.x * _mapTileSize.width,
		(_layerSize.height - pos.y - 1) * _mapTileSize.height,
	};
	return xy;
}

-(CGPoint) positionForIsoAt:(CGPoint)pos
{
	CGPoint xy = {
		_mapTileSize.width /2 * ( _layerSize.width + pos.x - pos.y - 1),
		_mapTileSize.height /2 * (( _layerSize.height * 2 - pos.x - pos.y) - 2),
	};
	return xy;
}

-(CGPoint) positionForHexAt:(CGPoint)pos
{
	float diffY = 0;
	if( (int)pos.x % 2 == 1 )
		diffY = -_mapTileSize.height/2 ;

	CGPoint xy = {
		pos.x * _mapTileSize.width*3/4,
		(_layerSize.height - pos.y - 1) * _mapTileSize.height + diffY
	};
	return xy;
}

-(NSInteger) vertexZForPos:(CGPoint)pos
{
	NSInteger ret = 0;
	NSUInteger maxVal = 0;
	if( _useAutomaticVertexZ ) {
		switch( _layerOrientation ) {
			case CCTMXOrientationIso:
				maxVal = _layerSize.width + _layerSize.height;
				ret = -(maxVal - (pos.x + pos.y));
				break;
			case CCTMXOrientationOrtho:
				ret = -(_layerSize.height-pos.y);
				break;
			case CCTMXOrientationHex:
				NSAssert(NO,@"TMX Hexa zOrder not supported");
				break;
			default:
				NSAssert(NO,@"TMX invalid value");
				break;
		}
	} else
		ret = _vertexZvalue;

	return ret;
}

@end

