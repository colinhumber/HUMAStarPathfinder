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


#import <stdarg.h>

#import "Platforms/CCGL.h"

#import "CCLayer.h"
#import "CCDirector.h"
#import "ccMacros.h"
#import "CCShaderCache.h"
#import "CCGLProgram.h"
#import "ccGLStateCache.h"
#import "Support/TransformUtils.h"
#import "Support/CGPointExtension.h"

#ifdef __CC_PLATFORM_IOS
#import "Platforms/iOS/CCTouchDispatcher.h"
#import "Platforms/iOS/CCDirectorIOS.h"
#elif defined(__CC_PLATFORM_MAC)
#import "Platforms/Mac/CCEventDispatcher.h"
#import "Platforms/Mac/CCDirectorMac.h"
#endif

// extern
#import "kazmath/GL/matrix.h"

#pragma mark -
#pragma mark Layer

#if __CC_PLATFORM_IOS
@interface CCLayer ()
-(void) registerWithTouchDispatcher;
@end
#endif // __CC_PLATFORM_IOS

@implementation CCLayer

#pragma mark Layer - Init
-(id) init
{
	if( (self=[super init]) ) {

		CGSize s = [[CCDirector sharedDirector] winSize];
		_anchorPoint = ccp(0.5f, 0.5f);
		[self setContentSize:s];
		self.ignoreAnchorPointForPosition = YES;

		_touchEnabled = NO;
		_touchPriority = 0;
		_touchMode = kCCTouchesAllAtOnce;

#ifdef __CC_PLATFORM_IOS
		_accelerometerEnabled = NO;
#elif defined(__CC_PLATFORM_MAC)
        _gestureEnabled = NO;
        _gesturePriority = 0;
		_mouseEnabled = NO;
		_keyboardEnabled = NO;
#endif
	}

	return self;
}

#pragma mark Layer - iOS - Touch and Accelerometer related

#ifdef __CC_PLATFORM_IOS
-(void) registerWithTouchDispatcher
{
	CCDirector *director = [CCDirector sharedDirector];
	
	if( _touchMode == kCCTouchesAllAtOnce )
		[[director touchDispatcher] addStandardDelegate:self priority:_touchPriority];
	else /* one by one */
		[[director touchDispatcher] addTargetedDelegate:self priority:_touchPriority swallowsTouches:YES];
}

-(BOOL) isAccelerometerEnabled
{
	return _accelerometerEnabled;
}

-(void) setAccelerometerEnabled:(BOOL)enabled
{
	if( enabled != _accelerometerEnabled ) {
		_accelerometerEnabled = enabled;
		if( _isRunning ) {
			if( enabled )
				[[UIAccelerometer sharedAccelerometer] setDelegate:(id<UIAccelerometerDelegate>)self];
			else
				[[UIAccelerometer sharedAccelerometer] setDelegate:nil];
		}
	}
}

-(void) setAccelerometerInterval:(float)interval
{
	[[UIAccelerometer sharedAccelerometer] setUpdateInterval:interval];
}

-(BOOL) isTouchEnabled
{
	return _touchEnabled;
}

-(void) setTouchEnabled:(BOOL)enabled
{	
	if( _touchEnabled != enabled ) {
		_touchEnabled = enabled;
		if( _isRunning) {
			if( enabled )
				[self registerWithTouchDispatcher];
			else {
				CCDirector *director = [CCDirector sharedDirector];
				[[director touchDispatcher] removeDelegate:self];
			}
		}
	}
}

-(NSInteger) touchPriority
{
	return _touchPriority;
}
-(void) setTouchPriority:(NSInteger)touchPriority
{
	if( _touchPriority != touchPriority ) {
		_touchPriority = touchPriority;
		
		if( _touchEnabled) {
			[self setTouchEnabled:NO];
			[self setTouchEnabled:YES];
		}
	}
}

-(ccTouchesMode) touchMode
{
	return _touchMode;
}
-(void) setTouchMode:(ccTouchesMode)touchMode
{
	if( _touchMode != touchMode ) {
		_touchMode = touchMode;
		if( _touchEnabled) {
			[self setTouchEnabled:NO];
			[self setTouchEnabled:YES];
		}
	}
}

#elif defined(__CC_PLATFORM_MAC)

#pragma mark CCLayer - OS X - Mouse, Keyboard & Touch events


-(BOOL) isMouseEnabled
{
	return _mouseEnabled;
}

-(void) setMouseEnabled:(BOOL)enabled
{
	if( _mouseEnabled != enabled ) {
		_mouseEnabled = enabled;
		
		if( _isRunning ) {
			CCDirector *director = [CCDirector sharedDirector];
			if( enabled )
				[[director eventDispatcher] addMouseDelegate:self priority:_mousePriority];
			else
				[[director eventDispatcher] removeMouseDelegate:self];
		}
	}	
}

-(NSInteger) mousePriority
{
	return _mousePriority;
}

-(void) setMousePriority:(NSInteger)mousePriority
{
	if( _mousePriority != mousePriority ) {
		_mousePriority = mousePriority;
		if( _mouseEnabled ) {
			[self setMouseEnabled:NO];
			[self setMouseEnabled:YES];
		}
	}
}

-(BOOL) isKeyboardEnabled
{
	return _keyboardEnabled;
}

-(void) setKeyboardEnabled:(BOOL)enabled
{
	if( _keyboardEnabled != enabled ) {
		_keyboardEnabled = enabled;

		if( _isRunning ) {
			CCDirector *director = [CCDirector sharedDirector];
			if( enabled )
				[[director eventDispatcher] addKeyboardDelegate:self priority:_keyboardPriority ];
			else
				[[director eventDispatcher] removeKeyboardDelegate:self];
		}
	}
}

-(NSInteger) keyboardPriority
{
	return _keyboardPriority;
}

-(void) setKeyboardPriority:(NSInteger)keyboardPriority
{
	if( _keyboardPriority != keyboardPriority ) {
		_keyboardPriority = keyboardPriority;
		if( _keyboardEnabled ) {
			[self setKeyboardEnabled:NO];
			[self setKeyboardEnabled:YES];
		}
	}
}

-(BOOL) isTouchEnabled
{
	return _touchEnabled;
}

-(void) setTouchEnabled:(BOOL)enabled
{
	if( _touchEnabled != enabled ) {
		_touchEnabled = enabled;
		if( _isRunning ) {
			CCDirector *director = [CCDirector sharedDirector];
			if( enabled )
				[[director eventDispatcher] addTouchDelegate:self priority:_touchPriority];
			else
				[[director eventDispatcher] removeTouchDelegate:self];
		}
	}
}

-(NSInteger) touchPriority
{
	return _touchPriority;
}
-(void) setTouchPriority:(NSInteger)touchPriority
{
	if( _touchPriority != touchPriority ) {
		_touchPriority = touchPriority;
		
		if( _touchEnabled) {
			[self setTouchEnabled:NO];
			[self setTouchEnabled:YES];
		}
	}
}

-(BOOL) isGestureEnabled
{
	return _gestureEnabled;
}

-(void) setGestureEnabled:(BOOL)enabled
{
	if( _gestureEnabled != enabled ) {
		_gestureEnabled = enabled;
		if( _isRunning ) {
			CCDirector *director = [CCDirector sharedDirector];
			if( enabled )
				[[director eventDispatcher] addGestureDelegate:self priority:_gesturePriority];
			else
				[[director eventDispatcher] removeGestureDelegate:self];
		}
	}
}

-(NSInteger) gesturePriority
{
	return _gesturePriority;
}

-(void) setGesturePriority:(NSInteger)gesturePriority
{
	if( _gesturePriority != gesturePriority ) {
		_gesturePriority = gesturePriority;
		
		if( _gestureEnabled) {
			[self setGestureEnabled:NO];
			[self setGestureEnabled:YES];
		}
	}
}

#endif // Mac


#pragma mark Layer - Callbacks
-(void) onEnter
{
#ifdef __CC_PLATFORM_IOS
	// register 'parent' nodes first
	// since events are propagated in reverse order
	if (_touchEnabled)
		[self registerWithTouchDispatcher];

#elif defined(__CC_PLATFORM_MAC)
	CCDirector *director = [CCDirector sharedDirector];
	CCEventDispatcher *eventDispatcher = [director eventDispatcher];

	if( _mouseEnabled )
		[eventDispatcher addMouseDelegate:self priority:_mousePriority];

	if( _keyboardEnabled)
		[eventDispatcher addKeyboardDelegate:self priority:_keyboardPriority];

	if( _touchEnabled)
		[eventDispatcher addTouchDelegate:self priority:_touchPriority];
    
	if( _gestureEnabled)
		[eventDispatcher addGestureDelegate:self priority:_gesturePriority];
    
#endif

	// then iterate over all the children
	[super onEnter];
}

// issue #624.
// Can't register mouse, touches here because of #issue #1018, and #1021
-(void) onEnterTransitionDidFinish
{
#ifdef __CC_PLATFORM_IOS
	if( _accelerometerEnabled )
		[[UIAccelerometer sharedAccelerometer] setDelegate:(id<UIAccelerometerDelegate>)self];
#endif

	[super onEnterTransitionDidFinish];
}


-(void) onExit
{
	CCDirector *director = [CCDirector sharedDirector];

#ifdef __CC_PLATFORM_IOS
	if( _touchEnabled )
		[[director touchDispatcher] removeDelegate:self];

	if( _accelerometerEnabled )
		[[UIAccelerometer sharedAccelerometer] setDelegate:nil];

#elif defined(__CC_PLATFORM_MAC)
	CCEventDispatcher *eventDispatcher = [director eventDispatcher];
	if( _mouseEnabled )
		[eventDispatcher removeMouseDelegate:self];

	if( _keyboardEnabled )
		[eventDispatcher removeKeyboardDelegate:self];

	if( _touchEnabled )
		[eventDispatcher removeTouchDelegate:self];
    
	if( _gestureEnabled )
		[eventDispatcher removeGestureDelegate:self];
    
#endif

	[super onExit];
}

#ifdef __CC_PLATFORM_IOS
-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
	NSAssert(NO, @"Layer#ccTouchBegan override me");
	return YES;
}
#endif
@end


#pragma mark - LayerRGBA

@implementation CCLayerRGBA

@synthesize cascadeColorEnabled = _cascadeColorEnabled;
@synthesize cascadeOpacityEnabled = _cascadeOpacityEnabled;

-(id) init
{
	if ( (self=[super init]) ) {
        _displayedOpacity = _realOpacity = 255;
        _displayedColor = _realColor = ccWHITE;
		self.cascadeOpacityEnabled = NO;
		self.cascadeColorEnabled = NO;
    }
    return self;
}

-(GLubyte) opacity
{
	return _realOpacity;
}

-(GLubyte) displayedOpacity
{
	return _displayedOpacity;
}

/** Override synthesized setOpacity to recurse items */
- (void) setOpacity:(GLubyte)opacity
{
	_displayedOpacity = _realOpacity = opacity;

	if( _cascadeOpacityEnabled ) {
		GLubyte parentOpacity = 255;
		if( [_parent conformsToProtocol:@protocol(CCRGBAProtocol)] && [(id<CCRGBAProtocol>)_parent isCascadeOpacityEnabled] )
			parentOpacity = [(id<CCRGBAProtocol>)_parent displayedOpacity];
		[self updateDisplayedOpacity:parentOpacity];
	}
}

-(ccColor3B) color
{
	return _realColor;
}

-(ccColor3B) displayedColor
{
	return _displayedColor;
}

- (void) setColor:(ccColor3B)color
{
	_displayedColor = _realColor = color;
	
	if( _cascadeColorEnabled ) {
		ccColor3B parentColor = ccWHITE;
		if( [_parent conformsToProtocol:@protocol(CCRGBAProtocol)] && [(id<CCRGBAProtocol>)_parent isCascadeColorEnabled] )
			parentColor = [(id<CCRGBAProtocol>)_parent displayedColor];
		[self updateDisplayedColor:parentColor];
	}
}

- (void)updateDisplayedOpacity:(GLubyte)parentOpacity
{
	_displayedOpacity = _realOpacity * parentOpacity/255.0;

    if (_cascadeOpacityEnabled) {
        id<CCRGBAProtocol> item;
        CCARRAY_FOREACH(_children, item) {
            if ([item conformsToProtocol:@protocol(CCRGBAProtocol)]) {
                [item updateDisplayedOpacity:_displayedOpacity];
            }
        }
    }
}

- (void)updateDisplayedColor:(ccColor3B)parentColor
{
	_displayedColor.r = _realColor.r * parentColor.r/255.0;
	_displayedColor.g = _realColor.g * parentColor.g/255.0;
	_displayedColor.b = _realColor.b * parentColor.b/255.0;

    if (_cascadeColorEnabled) {
        id<CCRGBAProtocol> item;
        CCARRAY_FOREACH(_children, item) {
            if ([item conformsToProtocol:@protocol(CCRGBAProtocol)]) {
                [item updateDisplayedColor:_displayedColor];
            }
        }
    }
}

@end


#pragma mark -
#pragma mark LayerColor

@interface CCLayerColor (Private)
-(void) updateColor;
@end

@implementation CCLayerColor

// Opacity and RGB color protocol
@synthesize blendFunc = _blendFunc;


+ (id) layerWithColor:(ccColor4B)color width:(GLfloat)w  height:(GLfloat) h
{
	return [[[self alloc] initWithColor:color width:w height:h] autorelease];
}

+ (id) layerWithColor:(ccColor4B)color
{
	return [[(CCLayerColor*)[self alloc] initWithColor:color] autorelease];
}

-(id) init
{
	CGSize s = [[CCDirector sharedDirector] winSize];
	return [self initWithColor:ccc4(0,0,0,0) width:s.width height:s.height];
}

// Designated initializer
- (id) initWithColor:(ccColor4B)color width:(GLfloat)w  height:(GLfloat) h
{
	if( (self=[super init]) ) {

		// default blend function
		_blendFunc = (ccBlendFunc) { GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA };

		_displayedColor.r = _realColor.r = color.r;
		_displayedColor.g = _realColor.g = color.g;
		_displayedColor.b = _realColor.b = color.b;
		_displayedOpacity = _realOpacity = color.a;

		for (NSUInteger i = 0; i<sizeof(_squareVertices) / sizeof( _squareVertices[0]); i++ ) {
			_squareVertices[i].x = 0.0f;
			_squareVertices[i].y = 0.0f;
		}

		[self updateColor];
		[self setContentSize:CGSizeMake(w, h) ];

		self.shaderProgram = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionColor];
	}
	return self;
}

- (id) initWithColor:(ccColor4B)color
{
	CGSize s = [[CCDirector sharedDirector] winSize];
	return [self initWithColor:color width:s.width height:s.height];
}


// override contentSize
-(void) setContentSize: (CGSize) size
{
	_squareVertices[1].x = size.width;
	_squareVertices[2].y = size.height;
	_squareVertices[3].x = size.width;
	_squareVertices[3].y = size.height;

	[super setContentSize:size];
}

- (void) changeWidth: (GLfloat) w height:(GLfloat) h
{
	[self setContentSize:CGSizeMake(w, h)];
}

-(void) changeWidth: (GLfloat) w
{
	[self setContentSize:CGSizeMake(w, _contentSize.height)];
}

-(void) changeHeight: (GLfloat) h
{
	[self setContentSize:CGSizeMake(_contentSize.width, h)];
}

- (void) updateColor
{
	for( NSUInteger i = 0; i < 4; i++ )
	{
		_squareColors[i].r = _displayedColor.r / 255.0f;
		_squareColors[i].g = _displayedColor.g / 255.0f;
		_squareColors[i].b = _displayedColor.b / 255.0f;
		_squareColors[i].a = _displayedOpacity / 255.0f;
	}
}

- (void) draw
{
	CC_NODE_DRAW_SETUP();

	ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position | kCCVertexAttribFlag_Color );

	//
	// Attributes
	//
	glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, _squareVertices);
	glVertexAttribPointer(kCCVertexAttrib_Color, 4, GL_FLOAT, GL_FALSE, 0, _squareColors);

	ccGLBlendFunc( _blendFunc.src, _blendFunc.dst );

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	CC_INCREMENT_GL_DRAWS(1);
}

#pragma mark Protocols
// Color Protocol

-(void) setColor:(ccColor3B)color
{
    [super setColor:color];
	[self updateColor];
}

-(void) setOpacity: (GLubyte) opacity
{
    [super setOpacity:opacity];
	[self updateColor];
}
@end


#pragma mark -
#pragma mark LayerGradient

@implementation CCLayerGradient

@synthesize startOpacity = _startOpacity;
@synthesize endColor = _endColor, endOpacity = _endOpacity;
@synthesize vector = _vector;

+ (id) layerWithColor: (ccColor4B) start fadingTo: (ccColor4B) end
{
    return [[[self alloc] initWithColor:start fadingTo:end] autorelease];
}

+ (id) layerWithColor: (ccColor4B) start fadingTo: (ccColor4B) end alongVector: (CGPoint) v
{
    return [[[self alloc] initWithColor:start fadingTo:end alongVector:v] autorelease];
}

- (id) init
{
	return [self initWithColor:ccc4(0, 0, 0, 255) fadingTo:ccc4(0, 0, 0, 255)];
}

- (id) initWithColor: (ccColor4B) start fadingTo: (ccColor4B) end
{
    return [self initWithColor:start fadingTo:end alongVector:ccp(0, -1)];
}

- (id) initWithColor: (ccColor4B) start fadingTo: (ccColor4B) end alongVector: (CGPoint) v
{
	_endColor.r = end.r;
	_endColor.g = end.g;
	_endColor.b = end.b;

	_endOpacity		= end.a;
	_startOpacity	= start.a;
	_vector = v;

	start.a	= 255;
	_compressedInterpolation = YES;

	return [super initWithColor:start];
}

- (void) updateColor
{
    [super updateColor];

	float h = ccpLength(_vector);
    if (h == 0)
		return;

	float c = sqrtf(2);
    CGPoint u = ccp(_vector.x / h, _vector.y / h);

	// Compressed Interpolation mode
	if( _compressedInterpolation ) {
		float h2 = 1 / ( fabsf(u.x) + fabsf(u.y) );
		u = ccpMult(u, h2 * (float)c);
	}

	float opacityf = (float)_displayedOpacity/255.0f;

    ccColor4F S = {
		_displayedColor.r / 255.0f,
		_displayedColor.g / 255.0f,
		_displayedColor.b / 255.0f,
		_startOpacity*opacityf / 255.0f,
	};

    ccColor4F E = {
		_endColor.r / 255.0f,
		_endColor.g / 255.0f,
		_endColor.b / 255.0f,
		_endOpacity*opacityf / 255.0f,
	};


    // (-1, -1)
	_squareColors[0].r = E.r + (S.r - E.r) * ((c + u.x + u.y) / (2.0f * c));
	_squareColors[0].g = E.g + (S.g - E.g) * ((c + u.x + u.y) / (2.0f * c));
	_squareColors[0].b = E.b + (S.b - E.b) * ((c + u.x + u.y) / (2.0f * c));
	_squareColors[0].a = E.a + (S.a - E.a) * ((c + u.x + u.y) / (2.0f * c));
    // (1, -1)
	_squareColors[1].r = E.r + (S.r - E.r) * ((c - u.x + u.y) / (2.0f * c));
	_squareColors[1].g = E.g + (S.g - E.g) * ((c - u.x + u.y) / (2.0f * c));
	_squareColors[1].b = E.b + (S.b - E.b) * ((c - u.x + u.y) / (2.0f * c));
	_squareColors[1].a = E.a + (S.a - E.a) * ((c - u.x + u.y) / (2.0f * c));
	// (-1, 1)
	_squareColors[2].r = E.r + (S.r - E.r) * ((c + u.x - u.y) / (2.0f * c));
	_squareColors[2].g = E.g + (S.g - E.g) * ((c + u.x - u.y) / (2.0f * c));
	_squareColors[2].b = E.b + (S.b - E.b) * ((c + u.x - u.y) / (2.0f * c));
	_squareColors[2].a = E.a + (S.a - E.a) * ((c + u.x - u.y) / (2.0f * c));
	// (1, 1)
	_squareColors[3].r = E.r + (S.r - E.r) * ((c - u.x - u.y) / (2.0f * c));
	_squareColors[3].g = E.g + (S.g - E.g) * ((c - u.x - u.y) / (2.0f * c));
	_squareColors[3].b = E.b + (S.b - E.b) * ((c - u.x - u.y) / (2.0f * c));
	_squareColors[3].a = E.a + (S.a - E.a) * ((c - u.x - u.y) / (2.0f * c));
}

-(ccColor3B) startColor
{
	return _realColor;
}

-(void) setStartColor:(ccColor3B)color
{
	[self setColor:color];
}

-(void) setEndColor:(ccColor3B)color
{
    _endColor = color;
    [self updateColor];
}

-(void) setStartOpacity: (GLubyte) o
{
	_startOpacity = o;
    [self updateColor];
}

-(void) setEndOpacity: (GLubyte) o
{
    _endOpacity = o;
    [self updateColor];
}

-(void) setVector: (CGPoint) v
{
    _vector = v;
    [self updateColor];
}

-(BOOL) compressedInterpolation
{
	return _compressedInterpolation;
}

-(void) setCompressedInterpolation:(BOOL)compress
{
	_compressedInterpolation = compress;
	[self updateColor];
}
@end

#pragma mark -
#pragma mark MultiplexLayer

@implementation CCLayerMultiplex
+(id) layerWithArray:(NSArray *)arrayOfLayers
{
	return [[[self alloc] initWithArray:arrayOfLayers] autorelease];
}

+(id) layerWithLayers: (CCLayer*) layer, ...
{
	va_list args;
	va_start(args,layer);

	id s = [[[self alloc] initWithLayers: layer vaList:args] autorelease];

	va_end(args);
	return s;
}

-(id) initWithArray:(NSArray *)arrayOfLayers
{
	if( (self=[super init])) {
		_layers = [arrayOfLayers mutableCopy];

		_enabledLayer = 0;

		[self addChild: [_layers objectAtIndex:_enabledLayer]];
	}


	return self;
}

-(id) initWithLayers: (CCLayer*) layer vaList:(va_list) params
{
	if( (self=[super init]) ) {

		_layers = [[NSMutableArray arrayWithCapacity:5] retain];

		[_layers addObject: layer];

		CCLayer *l = va_arg(params,CCLayer*);
		while( l ) {
			[_layers addObject: l];
			l = va_arg(params,CCLayer*);
		}

		_enabledLayer = 0;
		[self addChild: [_layers objectAtIndex: _enabledLayer]];
	}

	return self;
}

-(void) dealloc
{
	[_layers release];
	[super dealloc];
}

-(void) switchTo: (unsigned int) n
{
	NSAssert( n < [_layers count], @"Invalid index in MultiplexLayer switchTo message" );

	[self removeChild: [_layers objectAtIndex:_enabledLayer] cleanup:YES];

	_enabledLayer = n;

	[self addChild: [_layers objectAtIndex:n]];
}

-(void) switchToAndReleaseMe: (unsigned int) n
{
	NSAssert( n < [_layers count], @"Invalid index in MultiplexLayer switchTo message" );

	[self removeChild: [_layers objectAtIndex:_enabledLayer] cleanup:YES];

	[_layers replaceObjectAtIndex:_enabledLayer withObject:[NSNull null]];

	_enabledLayer = n;

	[self addChild: [_layers objectAtIndex:n]];
}
@end
