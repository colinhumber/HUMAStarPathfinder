/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2010 Ricardo Quesada
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
 */


// ideas taken from:
//	 . The ocean spray in your face [Jeff Lander]
//		http://www.double.co.nz/dust/col0798.pdf
//	 . Building an Advanced Particle System [John van der Burg]
//		http://www.gamasutra.com/features/20000623/vanderburg_01.htm
//   . LOVE game engine
//		http://love2d.org/
//
//
// Radius mode support, from 71 squared
//		http://particledesigner.71squared.com/
//
// IMPORTANT: Particle Designer is supported by cocos2d, but
// 'Radius Mode' in Particle Designer uses a fixed emit rate of 30 hz. Since that can't be guarateed in cocos2d,
//  cocos2d uses a another approach, but the results are almost identical.
//

// opengl
#import "Platforms/CCGL.h"

// cocos2d
#import "ccConfig.h"
#import "CCParticleSystem.h"
#import "CCParticleBatchNode.h"
#import "CCTextureCache.h"
#import "CCTextureAtlas.h"
#import "ccMacros.h"
#import "Support/CCProfiling.h"

// support
#import "Support/OpenGL_Internal.h"
#import "Support/CGPointExtension.h"
#import "Support/base64.h"
#import "Support/ZipUtils.h"
#import "Support/CCFileUtils.h"

@interface CCParticleSystem ()
-(void) updateBlendFunc;
@end

@implementation CCParticleSystem
@synthesize active = _active, duration = _duration;
@synthesize sourcePosition = _sourcePosition, posVar = _posVar;
@synthesize particleCount = _particleCount;
@synthesize life = _life, lifeVar = _lifeVar;
@synthesize angle = _angle, angleVar = _angleVar;
@synthesize startColor = _startColor, startColorVar = _startColorVar;
@synthesize endColor = _endColor, endColorVar = _endColorVar;
@synthesize startSpin = _startSpin, startSpinVar = _startSpinVar;
@synthesize endSpin = _endSpin, endSpinVar = _endSpinVar;
@synthesize emissionRate = _emissionRate;
@synthesize startSize = _startSize, startSizeVar = _startSizeVar;
@synthesize endSize = _endSize, endSizeVar = _endSizeVar;
@synthesize opacityModifyRGB = _opacityModifyRGB;
@synthesize blendFunc = _blendFunc;
@synthesize positionType = _positionType;
@synthesize autoRemoveOnFinish = _autoRemoveOnFinish;
@synthesize emitterMode = _emitterMode;
@synthesize atlasIndex = _atlasIndex;
@synthesize totalParticles = _totalParticles;

+(id) particleWithFile:(NSString*) plistFile
{
	return [[[self alloc] initWithFile:plistFile] autorelease];
}

+(id) particleWithTotalParticles:(NSUInteger) numberOfParticles
{
	return [[[self alloc] initWithTotalParticles:numberOfParticles] autorelease];
}

-(id) init {
	return [self initWithTotalParticles:150];
}

-(id) initWithFile:(NSString *)plistFile
{
	NSString *path = [[CCFileUtils sharedFileUtils] fullPathForFilename:plistFile];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];

	NSAssert( dict != nil, @"Particles: file not found");
	
	return [self initWithDictionary:dict path:[plistFile stringByDeletingLastPathComponent]];
}


-(id) initWithDictionary:(NSDictionary *)dictionary
{
	return [self initWithDictionary:dictionary path:@""];
}

-(id) initWithDictionary:(NSDictionary *)dictionary path:(NSString*)dirname
{
	NSUInteger maxParticles = [[dictionary valueForKey:@"maxParticles"] integerValue];
	// self, not super

	if ((self=[self initWithTotalParticles:maxParticles] ) )
	{
		// angle
		_angle = [[dictionary valueForKey:@"angle"] floatValue];
		_angleVar = [[dictionary valueForKey:@"angleVariance"] floatValue];

		// duration
		_duration = [[dictionary valueForKey:@"duration"] floatValue];

		// blend function
		_blendFunc.src = [[dictionary valueForKey:@"blendFuncSource"] intValue];
		_blendFunc.dst = [[dictionary valueForKey:@"blendFuncDestination"] intValue];

		// color
		float r,g,b,a;

		r = [[dictionary valueForKey:@"startColorRed"] floatValue];
		g = [[dictionary valueForKey:@"startColorGreen"] floatValue];
		b = [[dictionary valueForKey:@"startColorBlue"] floatValue];
		a = [[dictionary valueForKey:@"startColorAlpha"] floatValue];
		_startColor = (ccColor4F) {r,g,b,a};

		r = [[dictionary valueForKey:@"startColorVarianceRed"] floatValue];
		g = [[dictionary valueForKey:@"startColorVarianceGreen"] floatValue];
		b = [[dictionary valueForKey:@"startColorVarianceBlue"] floatValue];
		a = [[dictionary valueForKey:@"startColorVarianceAlpha"] floatValue];
		_startColorVar = (ccColor4F) {r,g,b,a};

		r = [[dictionary valueForKey:@"finishColorRed"] floatValue];
		g = [[dictionary valueForKey:@"finishColorGreen"] floatValue];
		b = [[dictionary valueForKey:@"finishColorBlue"] floatValue];
		a = [[dictionary valueForKey:@"finishColorAlpha"] floatValue];
		_endColor = (ccColor4F) {r,g,b,a};

		r = [[dictionary valueForKey:@"finishColorVarianceRed"] floatValue];
		g = [[dictionary valueForKey:@"finishColorVarianceGreen"] floatValue];
		b = [[dictionary valueForKey:@"finishColorVarianceBlue"] floatValue];
		a = [[dictionary valueForKey:@"finishColorVarianceAlpha"] floatValue];
		_endColorVar = (ccColor4F) {r,g,b,a};

		// particle size
		_startSize = [[dictionary valueForKey:@"startParticleSize"] floatValue];
		_startSizeVar = [[dictionary valueForKey:@"startParticleSizeVariance"] floatValue];
		_endSize = [[dictionary valueForKey:@"finishParticleSize"] floatValue];
		_endSizeVar = [[dictionary valueForKey:@"finishParticleSizeVariance"] floatValue];

		// position
		float x = [[dictionary valueForKey:@"sourcePositionx"] floatValue];
		float y = [[dictionary valueForKey:@"sourcePositiony"] floatValue];
		self.position = ccp(x,y);
		_posVar.x = [[dictionary valueForKey:@"sourcePositionVariancex"] floatValue];
		_posVar.y = [[dictionary valueForKey:@"sourcePositionVariancey"] floatValue];

		// Spinning
		_startSpin = [[dictionary valueForKey:@"rotationStart"] floatValue];
		_startSpinVar = [[dictionary valueForKey:@"rotationStartVariance"] floatValue];
		_endSpin = [[dictionary valueForKey:@"rotationEnd"] floatValue];
		_endSpinVar = [[dictionary valueForKey:@"rotationEndVariance"] floatValue];

		_emitterMode = [[dictionary valueForKey:@"emitterType"] intValue];

		// Mode A: Gravity + tangential accel + radial accel
		if( _emitterMode == kCCParticleModeGravity ) {
			// gravity
			_mode.A.gravity.x = [[dictionary valueForKey:@"gravityx"] floatValue];
			_mode.A.gravity.y = [[dictionary valueForKey:@"gravityy"] floatValue];

			//
			// speed
			_mode.A.speed = [[dictionary valueForKey:@"speed"] floatValue];
			_mode.A.speedVar = [[dictionary valueForKey:@"speedVariance"] floatValue];

			// radial acceleration
			NSString *tmp = [dictionary valueForKey:@"radialAcceleration"];
			_mode.A.radialAccel = tmp ? [tmp floatValue] : 0;

			tmp = [dictionary valueForKey:@"radialAccelVariance"];
			_mode.A.radialAccelVar = tmp ? [tmp floatValue] : 0;

			// tangential acceleration
			tmp = [dictionary valueForKey:@"tangentialAcceleration"];
			_mode.A.tangentialAccel = tmp ? [tmp floatValue] : 0;

			tmp = [dictionary valueForKey:@"tangentialAccelVariance"];
			_mode.A.tangentialAccelVar = tmp ? [tmp floatValue] : 0;
		}

		// or Mode B: radius movement
		else if( _emitterMode == kCCParticleModeRadius ) {
			float maxRadius = [[dictionary valueForKey:@"maxRadius"] floatValue];
			float maxRadiusVar = [[dictionary valueForKey:@"maxRadiusVariance"] floatValue];
			float minRadius = [[dictionary valueForKey:@"minRadius"] floatValue];

			_mode.B.startRadius = maxRadius;
			_mode.B.startRadiusVar = maxRadiusVar;
			_mode.B.endRadius = minRadius;
			_mode.B.endRadiusVar = 0;
			_mode.B.rotatePerSecond = [[dictionary valueForKey:@"rotatePerSecond"] floatValue];
			_mode.B.rotatePerSecondVar = [[dictionary valueForKey:@"rotatePerSecondVariance"] floatValue];

		} else {
			NSAssert( NO, @"Invalid emitterType in config file");
		}

		// life span
		_life = [[dictionary valueForKey:@"particleLifespan"] floatValue];
		_lifeVar = [[dictionary valueForKey:@"particleLifespanVariance"] floatValue];

		// emission Rate
		_emissionRate = _totalParticles/_life;

		//don't get the internal texture if a batchNode is used
		if (!_batchNode)
		{
			// Set a compatible default for the alpha transfer
			_opacityModifyRGB = NO;

			// texture
			// Try to get the texture from the cache

			NSString *textureName = [dictionary valueForKey:@"textureFileName"];
			NSString *textureDir = [textureName stringByDeletingLastPathComponent];
			
			// For backward compatibility, only append the dirname if both dirnames are the same
			if( ! [textureDir isEqualToString:dirname] )
				textureName = [dirname stringByAppendingPathComponent:textureName];

			CCTexture2D *tex = [[CCTextureCache sharedTextureCache] addImage:textureName];

			if( tex )
				[self setTexture:tex];
			else {

				NSString *textureData = [dictionary valueForKey:@"textureImageData"];
				NSAssert( textureData, @"CCParticleSystem: Couldn't load texture");

				// if it fails, try to get it from the base64-gzipped data
				unsigned char *buffer = NULL;
				int len = base64Decode((unsigned char*)[textureData UTF8String], (unsigned int)[textureData length], &buffer);
				NSAssert( buffer != NULL, @"CCParticleSystem: error decoding textureImageData");

				unsigned char *deflated = NULL;
				NSUInteger deflatedLen = ccInflateMemory(buffer, len, &deflated);
				free( buffer );

				NSAssert( deflated != NULL, @"CCParticleSystem: error ungzipping textureImageData");
				NSData *data = [[NSData alloc] initWithBytes:deflated length:deflatedLen];

#ifdef __CC_PLATFORM_IOS
				UIImage *image = [[UIImage alloc] initWithData:data];
#elif defined(__CC_PLATFORM_MAC)
				NSBitmapImageRep *image = [[NSBitmapImageRep alloc] initWithData:data];
#endif

				free(deflated); deflated = NULL;

				[self setTexture:  [ [CCTextureCache sharedTextureCache] addCGImage:[image CGImage] forKey:textureName]];
				[data release];
				[image release];
			}

			NSAssert( [self texture] != NULL, @"CCParticleSystem: error loading the texture");
		}
	}

	return self;
}

-(id) initWithTotalParticles:(NSUInteger) numberOfParticles
{
	if( (self=[super init]) ) {

		_totalParticles = numberOfParticles;

		_particles = calloc( _totalParticles, sizeof(tCCParticle) );

		if( ! _particles ) {
			CCLOG(@"Particle system: not enough memory");
			[self release];
			return nil;
		}
        _allocatedParticles = numberOfParticles;

		if (_batchNode)
		{
			for (int i = 0; i < _totalParticles; i++)
			{
				_particles[i].atlasIndex=i;
			}
		}

		// default, active
		_active = YES;

		// default blend function
		_blendFunc = (ccBlendFunc) { CC_BLEND_SRC, CC_BLEND_DST };

		// default movement type;
		_positionType = kCCPositionTypeFree;

		// by default be in mode A:
		_emitterMode = kCCParticleModeGravity;

		_autoRemoveOnFinish = NO;

		// Optimization: compile updateParticle method
		_updateParticleSel = @selector(updateQuadWithParticle:newPosition:);
		_updateParticleImp = (CC_UPDATE_PARTICLE_IMP) [self methodForSelector:_updateParticleSel];

		//for batchNode
		_transformSystemDirty = NO;

		// update after action in run!
		[self scheduleUpdateWithPriority:1];
	}
	return self;
}

-(void) dealloc
{
	// Since the scheduler retains the "target (in this case the ParticleSystem)
	// it is not needed to call "unscheduleUpdate" here. In fact, it will be called in "cleanup"
//	[self unscheduleUpdate];

	free( _particles );

	[_texture release];

	[super dealloc];
}

-(void) initParticle: (tCCParticle*) particle
{
	//CGPoint currentPosition = _position;
	// timeToLive
	// no negative life. prevent division by 0
	particle->timeToLive = _life + _lifeVar * CCRANDOM_MINUS1_1();
	particle->timeToLive = MAX(0, particle->timeToLive);

	// position
	particle->pos.x = _sourcePosition.x + _posVar.x * CCRANDOM_MINUS1_1();
	particle->pos.y = _sourcePosition.y + _posVar.y * CCRANDOM_MINUS1_1();

	// Color
	ccColor4F start;
	start.r = clampf( _startColor.r + _startColorVar.r * CCRANDOM_MINUS1_1(), 0, 1);
	start.g = clampf( _startColor.g + _startColorVar.g * CCRANDOM_MINUS1_1(), 0, 1);
	start.b = clampf( _startColor.b + _startColorVar.b * CCRANDOM_MINUS1_1(), 0, 1);
	start.a = clampf( _startColor.a + _startColorVar.a * CCRANDOM_MINUS1_1(), 0, 1);

	ccColor4F end;
	end.r = clampf( _endColor.r + _endColorVar.r * CCRANDOM_MINUS1_1(), 0, 1);
	end.g = clampf( _endColor.g + _endColorVar.g * CCRANDOM_MINUS1_1(), 0, 1);
	end.b = clampf( _endColor.b + _endColorVar.b * CCRANDOM_MINUS1_1(), 0, 1);
	end.a = clampf( _endColor.a + _endColorVar.a * CCRANDOM_MINUS1_1(), 0, 1);

	particle->color = start;
	particle->deltaColor.r = (end.r - start.r) / particle->timeToLive;
	particle->deltaColor.g = (end.g - start.g) / particle->timeToLive;
	particle->deltaColor.b = (end.b - start.b) / particle->timeToLive;
	particle->deltaColor.a = (end.a - start.a) / particle->timeToLive;

	// size
	float startS = _startSize + _startSizeVar * CCRANDOM_MINUS1_1();
	startS = MAX(0, startS); // No negative value

	particle->size = startS;
	if( _endSize == kCCParticleStartSizeEqualToEndSize )
		particle->deltaSize = 0;
	else {
		float endS = _endSize + _endSizeVar * CCRANDOM_MINUS1_1();
		endS = MAX(0, endS);	// No negative values
		particle->deltaSize = (endS - startS) / particle->timeToLive;
	}

	// rotation
	float startA = _startSpin + _startSpinVar * CCRANDOM_MINUS1_1();
	float endA = _endSpin + _endSpinVar * CCRANDOM_MINUS1_1();
	particle->rotation = startA;
	particle->deltaRotation = (endA - startA) / particle->timeToLive;

	// position
	if( _positionType == kCCPositionTypeFree )
		particle->startPos = [self convertToWorldSpace:CGPointZero];

	else if( _positionType == kCCPositionTypeRelative )
		particle->startPos = _position;


	// direction
	float a = CC_DEGREES_TO_RADIANS( _angle + _angleVar * CCRANDOM_MINUS1_1() );

	// Mode Gravity: A
	if( _emitterMode == kCCParticleModeGravity ) {

		CGPoint v = {cosf( a ), sinf( a )};
		float s = _mode.A.speed + _mode.A.speedVar * CCRANDOM_MINUS1_1();

		// direction
		particle->mode.A.dir = ccpMult( v, s );

		// radial accel
		particle->mode.A.radialAccel = _mode.A.radialAccel + _mode.A.radialAccelVar * CCRANDOM_MINUS1_1();

		// tangential accel
		particle->mode.A.tangentialAccel = _mode.A.tangentialAccel + _mode.A.tangentialAccelVar * CCRANDOM_MINUS1_1();
	}

	// Mode Radius: B
	else {
		// Set the default diameter of the particle from the source position
		float startRadius = _mode.B.startRadius + _mode.B.startRadiusVar * CCRANDOM_MINUS1_1();
		float endRadius = _mode.B.endRadius + _mode.B.endRadiusVar * CCRANDOM_MINUS1_1();

		particle->mode.B.radius = startRadius;

		if( _mode.B.endRadius == kCCParticleStartRadiusEqualToEndRadius )
			particle->mode.B.deltaRadius = 0;
		else
			particle->mode.B.deltaRadius = (endRadius - startRadius) / particle->timeToLive;

		particle->mode.B.angle = a;
		particle->mode.B.degreesPerSecond = CC_DEGREES_TO_RADIANS(_mode.B.rotatePerSecond + _mode.B.rotatePerSecondVar * CCRANDOM_MINUS1_1());
	}
}

-(BOOL) addParticle
{
	if( [self isFull] )
		return NO;

	tCCParticle * particle = &_particles[ _particleCount ];

	[self initParticle: particle];
	_particleCount++;

	return YES;
}

-(void) stopSystem
{
	_active = NO;
	_elapsed = _duration;
	_emitCounter = 0;
}

-(void) resetSystem
{
	_active = YES;
	_elapsed = 0;
	for(_particleIdx = 0; _particleIdx < _particleCount; ++_particleIdx) {
		tCCParticle *p = &_particles[_particleIdx];
		p->timeToLive = 0;
	}

}

-(BOOL) isFull
{
	return (_particleCount == _totalParticles);
}

#pragma mark ParticleSystem - MainLoop
-(void) update: (ccTime) dt
{
	CC_PROFILER_START_CATEGORY(kCCProfilerCategoryParticles , @"CCParticleSystem - update");

	if( _active && _emissionRate ) {
		float rate = 1.0f / _emissionRate;
		
		//issue #1201, prevent bursts of particles, due to too high emitCounter
		if (_particleCount < _totalParticles)
			_emitCounter += dt; 
		
		while( _particleCount < _totalParticles && _emitCounter > rate ) {
			[self addParticle];
			_emitCounter -= rate;
		}

		_elapsed += dt;

		if(_duration != -1 && _duration < _elapsed)
			[self stopSystem];
	}

	_particleIdx = 0;

	CGPoint currentPosition = CGPointZero;
	if( _positionType == kCCPositionTypeFree )
		currentPosition = [self convertToWorldSpace:CGPointZero];

	else if( _positionType == kCCPositionTypeRelative )
		currentPosition = _position;

	if (_visible)
	{
		while( _particleIdx < _particleCount )
		{
			tCCParticle *p = &_particles[_particleIdx];

			// life
			p->timeToLive -= dt;

			if( p->timeToLive > 0 ) {

				// Mode A: gravity, direction, tangential accel & radial accel
				if( _emitterMode == kCCParticleModeGravity ) {
					CGPoint tmp, radial, tangential;

					radial = CGPointZero;
					// radial acceleration
					if(p->pos.x || p->pos.y)
						radial = ccpNormalize(p->pos);

					tangential = radial;
					radial = ccpMult(radial, p->mode.A.radialAccel);

					// tangential acceleration
					float newy = tangential.x;
					tangential.x = -tangential.y;
					tangential.y = newy;
					tangential = ccpMult(tangential, p->mode.A.tangentialAccel);

					// (gravity + radial + tangential) * dt
					tmp = ccpAdd( ccpAdd( radial, tangential), _mode.A.gravity);
					tmp = ccpMult( tmp, dt);
					p->mode.A.dir = ccpAdd( p->mode.A.dir, tmp);
					tmp = ccpMult(p->mode.A.dir, dt);
					p->pos = ccpAdd( p->pos, tmp );
				}

				// Mode B: radius movement
				else {
					// Update the angle and radius of the particle.
					p->mode.B.angle += p->mode.B.degreesPerSecond * dt;
					p->mode.B.radius += p->mode.B.deltaRadius * dt;

					p->pos.x = - cosf(p->mode.B.angle) * p->mode.B.radius;
					p->pos.y = - sinf(p->mode.B.angle) * p->mode.B.radius;
				}

				// color
				p->color.r += (p->deltaColor.r * dt);
				p->color.g += (p->deltaColor.g * dt);
				p->color.b += (p->deltaColor.b * dt);
				p->color.a += (p->deltaColor.a * dt);

				// size
				p->size += (p->deltaSize * dt);
				p->size = MAX( 0, p->size );

				// angle
				p->rotation += (p->deltaRotation * dt);

				//
				// update values in quad
				//

				CGPoint	newPos;

				if( _positionType == kCCPositionTypeFree || _positionType == kCCPositionTypeRelative )
				{
					CGPoint diff = ccpSub( currentPosition, p->startPos );
					newPos = ccpSub(p->pos, diff);
				} else
					newPos = p->pos;

				// translate newPos to correct position, since matrix transform isn't performed in batchnode
				// don't update the particle with the new position information, it will interfere with the radius and tangential calculations
				if (_batchNode)
				{
					newPos.x+=_position.x;
					newPos.y+=_position.y;
				}

				_updateParticleImp(self, _updateParticleSel, p, newPos);

				// update particle counter
				_particleIdx++;

			} else {
				// life < 0
				NSInteger currentIndex = p->atlasIndex;

				if( _particleIdx != _particleCount-1 )
					_particles[_particleIdx] = _particles[_particleCount-1];

				if (_batchNode)
				{
					//disable the switched particle
					[_batchNode disableParticle:(_atlasIndex+currentIndex)];

					//switch indexes
					_particles[_particleCount-1].atlasIndex = currentIndex;
				}

				_particleCount--;

				if( _particleCount == 0 && _autoRemoveOnFinish ) {
					[self unscheduleUpdate];
					[_parent removeChild:self cleanup:YES];
					return;
				}
			}
		}//while
		_transformSystemDirty = NO;
	}

	if (!_batchNode)
		[self postStep];

	CC_PROFILER_STOP_CATEGORY(kCCProfilerCategoryParticles , @"CCParticleSystem - update");
}

-(void) updateWithNoTime
{
	[self update:0.0f];
}

-(void) updateQuadWithParticle:(tCCParticle*)particle newPosition:(CGPoint)pos;
{
	// should be overriden
}

-(void) postStep
{
	// should be overriden
}

#pragma mark ParticleSystem - CCTexture protocol

-(void) setTexture:(CCTexture2D*) texture
{
	if( _texture != texture ) {
		[_texture release];
		_texture = [texture retain];

		[self updateBlendFunc];
	}
}

-(CCTexture2D*) texture
{
	return _texture;
}

#pragma mark ParticleSystem - Additive Blending
-(void) setBlendAdditive:(BOOL)additive
{
	if( additive ) {
		_blendFunc.src = GL_SRC_ALPHA;
		_blendFunc.dst = GL_ONE;

	} else {

		if( _texture && ! [_texture hasPremultipliedAlpha] ) {
			_blendFunc.src = GL_SRC_ALPHA;
			_blendFunc.dst = GL_ONE_MINUS_SRC_ALPHA;
		} else {
			_blendFunc.src = CC_BLEND_SRC;
			_blendFunc.dst = CC_BLEND_DST;
		}
	}
}

-(BOOL) blendAdditive
{
	return( _blendFunc.src == GL_SRC_ALPHA && _blendFunc.dst == GL_ONE);
}

-(void) setBlendFunc:(ccBlendFunc)blendFunc
{
	if( _blendFunc.src != blendFunc.src || _blendFunc.dst != blendFunc.dst ) {
		_blendFunc = blendFunc;
		[self updateBlendFunc];
	}
}
#pragma mark ParticleSystem - Total Particles Property

- (void) setTotalParticles:(NSUInteger)tp
{
    NSAssert( tp <= _allocatedParticles, @"Particle: resizing particle array only supported for quads");
    _totalParticles = tp;
}

- (NSUInteger) _totalParticles
{
    return _totalParticles;
}

#pragma mark ParticleSystem - Properties of Gravity Mode
-(void) setTangentialAccel:(float)t
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.tangentialAccel = t;
}
-(float) tangentialAccel
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.tangentialAccel;
}

-(void) setTangentialAccelVar:(float)t
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.tangentialAccelVar = t;
}
-(float) tangentialAccelVar
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.tangentialAccelVar;
}

-(void) setRadialAccel:(float)t
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.radialAccel = t;
}
-(float) radialAccel
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.radialAccel;
}

-(void) setRadialAccelVar:(float)t
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.radialAccelVar = t;
}
-(float) radialAccelVar
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.radialAccelVar;
}

-(void) setGravity:(CGPoint)g
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.gravity = g;
}
-(CGPoint) gravity
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.gravity;
}

-(void) setSpeed:(float)speed
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.speed = speed;
}
-(float) speed
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.speed;
}

-(void) setSpeedVar:(float)speedVar
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	_mode.A.speedVar = speedVar;
}
-(float) speedVar
{
	NSAssert( _emitterMode == kCCParticleModeGravity, @"Particle Mode should be Gravity");
	return _mode.A.speedVar;
}

#pragma mark ParticleSystem - Properties of Radius Mode

-(void) setStartRadius:(float)startRadius
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	_mode.B.startRadius = startRadius;
}
-(float) startRadius
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	return _mode.B.startRadius;
}

-(void) setStartRadiusVar:(float)startRadiusVar
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	_mode.B.startRadiusVar = startRadiusVar;
}
-(float) startRadiusVar
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	return _mode.B.startRadiusVar;
}

-(void) setEndRadius:(float)endRadius
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	_mode.B.endRadius = endRadius;
}
-(float) endRadius
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	return _mode.B.endRadius;
}

-(void) setEndRadiusVar:(float)endRadiusVar
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	_mode.B.endRadiusVar = endRadiusVar;
}
-(float) endRadiusVar
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	return _mode.B.endRadiusVar;
}

-(void) setRotatePerSecond:(float)degrees
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	_mode.B.rotatePerSecond = degrees;
}
-(float) rotatePerSecond
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	return _mode.B.rotatePerSecond;
}

-(void) setRotatePerSecondVar:(float)degrees
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	_mode.B.rotatePerSecondVar = degrees;
}
-(float) rotatePerSecondVar
{
	NSAssert( _emitterMode == kCCParticleModeRadius, @"Particle Mode should be Radius");
	return _mode.B.rotatePerSecondVar;
}

#pragma mark ParticleSystem - methods for batchNode rendering

-(CCParticleBatchNode*) batchNode
{
	return _batchNode;
}

-(void) setBatchNode:(CCParticleBatchNode*) batchNode
{
	if( _batchNode != batchNode ) {

		_batchNode = batchNode; // weak reference

		if( batchNode ) {
			//each particle needs a unique index
			for (int i = 0; i < _totalParticles; i++)
			{
				_particles[i].atlasIndex=i;
			}
		}
	}
}

//don't use a transform matrix, this is faster
-(void) setScale:(float) s
{
	_transformSystemDirty = YES;
	[super setScale:s];
}

-(void) setRotation: (float)newRotation
{
	_transformSystemDirty = YES;
	[super setRotation:newRotation];
}

-(void) setScaleX: (float)newScaleX
{
	_transformSystemDirty = YES;
	[super setScaleX:newScaleX];
}

-(void) setScaleY: (float)newScaleY
{
	_transformSystemDirty = YES;
	[super setScaleY:newScaleY];
}

#pragma mark Particle - Helpers

-(void) updateBlendFunc
{
	NSAssert(! _batchNode, @"Can't change blending functions when the particle is being batched");

	BOOL premultiplied = [_texture hasPremultipliedAlpha];

	_opacityModifyRGB = NO;

	if( _texture && ( _blendFunc.src == CC_BLEND_SRC && _blendFunc.dst == CC_BLEND_DST ) ) {
		if( premultiplied )
			_opacityModifyRGB = YES;
		else {
			_blendFunc.src = GL_SRC_ALPHA;
			_blendFunc.dst = GL_ONE_MINUS_SRC_ALPHA;
		}
	}
}


@end
