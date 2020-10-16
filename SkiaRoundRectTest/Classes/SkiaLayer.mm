//
//  SkiaLayer.m
//  SkiaTextDemo
//
//  Created by lvpengwei on 2019/5/19.
//  Copyright © 2019 lvpengwei. All rights reserved.
//

#import "SkiaLayer.h"
#import <GrContext.h>
#import <gl/GrGLInterface.h>
#import <SkCanvas.h>
#import <SkGraphics.h>
#import <SkSurface.h>
#import <SkString.h>
#import <OpenGLES/ES2/gl.h>

@interface SkiaLayer () {
    GrContext *_context;
    SkCanvas *_canvas;
    EAGLContext *_eaglContext;
    GLuint framebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;
    int count;
}

@end

@implementation SkiaLayer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithBool:NO],
         kEAGLDrawablePropertyRetainedBacking,
         kEAGLColorFormatRGBA8,
         kEAGLDrawablePropertyColorFormat,
         nil];
        _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return self;
}

- (void)dealloc {
    [self releaseSurface];
}

- (void)releaseSurface {
    if (_context == NULL) return;
    [EAGLContext setCurrentContext:_eaglContext];
    if (framebuffer) {
        glDeleteFramebuffers(1, &framebuffer);
        framebuffer = 0;
    }
    if (colorRenderbuffer) {
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }
    if (depthRenderbuffer) {
        glDeleteRenderbuffers(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
    // Free up all gpu resources in case that we get squares when rendering texts.
    _context->freeGpuResources();
    [EAGLContext setCurrentContext:nil];
}

- (void)createSurface {
    if (_eaglContext == nil) return;
    if (self.bounds.size.width == 0 || self.bounds.size.height == 0) return;
    if (_context != NULL && _canvas != NULL) return;
    [EAGLContext setCurrentContext:_eaglContext];
    
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    glGenRenderbuffers(1, &colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
    [_eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    
    GLint width = self.bounds.size.width;
    GLint height = self.bounds.size.height;
    
    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    glViewport(0, 0, width, height);
    glClearStencil(0);
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glStencilMask(0xffffffff);
    glClear(GL_STENCIL_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        printf("无法使完整的framebuffer对象");
        exit(1);
    }
    const GrGLInterface * interface = GrGLCreateNativeInterface();
    _context = GrContext::Create(kOpenGL_GrBackend, (GrBackendContext)interface);
    if (NULL == interface || NULL == _context) {
        printf("Failed to initialize GL.");
        exit(1);
    }
    
    GrGLint buffer;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &buffer);
    
    GrBackendRenderTargetDesc desc;
    desc.fWidth = SkScalarRoundToInt(width);
    desc.fHeight = SkScalarRoundToInt(height);
    desc.fConfig = kSkia8888_GrPixelConfig;
    desc.fOrigin = kBottomLeft_GrSurfaceOrigin;
    desc.fSampleCnt = 0;
    desc.fStencilBits = 8;
    desc.fRenderTargetHandle = buffer;
    
    SkSurface * surface = SkSurface::MakeFromBackendRenderTarget(_context, desc, nullptr).release();
    _canvas = surface->getCanvas();
    
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    [EAGLContext setCurrentContext:nil];
}

void ConvertRoundRectToPath(SkPath* path, float centerX, float centerY,
                                  float width, float height, float radius) {
  auto hw = width * 0.5f;
  auto hh = height * 0.5f;
  auto x = centerX - hw;
  auto y = centerY - hh;
  if (radius > hw) {
    radius = hw;
  }
  if (radius > hh) {
    radius = hh;
  }

  //    A-----B
  //  H         C
  //  G         D
  //    F-----E
  // begins at the G point
  auto right = x + width;
  auto bottom = y + height;
  auto xlw = x + radius;
  auto xrw = right - radius;
  auto ytw = y + radius;
  auto ybw = bottom - radius;
  const SkScalar weight = SK_ScalarRoot2Over2;
  path->moveTo(x, ybw);

  path->lineTo(x, ytw);
  path->conicTo(x, y, xlw, y, weight);
  path->lineTo(xrw, y);
  path->conicTo(right, y, right, ytw, weight);
  path->lineTo(right, ybw);
  path->conicTo(right, bottom, xrw, bottom, weight);
  path->lineTo(xlw, bottom);
  path->conicTo(x, bottom, x, ybw, weight);
    
  path->close();
}

- (void)draw {
    [self createSurface];
    if (_canvas == NULL) return;
    [EAGLContext setCurrentContext:_eaglContext];
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    
    _canvas->drawColor(SK_ColorCYAN);
    
    SkPaint paint{};
    paint.setAntiAlias(true);
    
    // when style is kFill_Style, the result that drawing path2 will be wrong on iOS 14.
    // other style is ok.
    paint.setStyle(SkPaint::kFill_Style);
//    paint.setStyle(SkPaint::kStrokeAndFill_Style);
//    paint.setStyle(SkPaint::kStroke_Style);
//    paint.setStrokeWidth(2);
    
    // init path1
    SkPath path1{};
    SkRect rect = SkRect::MakeWH(90, 50);
    path1.addRoundRect(rect, 30, 30);
    
    // init path2
    SkPath path2{};
    ConvertRoundRectToPath(&path2, 45, 25, 90, 50, 30);
    
    // when style is kFill_Style, and set this property, the result will be ok.
//    path2.setConvexity(SkPath::Convexity::kConcave_Convexity);
    
    if (count % 2 == 0) {
        _canvas->drawPath(path2, paint);
        [self drawText:@"path2"];
    } else {
        _canvas->drawPath(path1, paint);
        [self drawText:@"path1"];
    }
    
    // path1 and path2 are equal.
    if (path1 == path2) {
        printf("90*50 path1 == path2\n");
    }
    ConvertRoundRectToPath(&path2, 45, 25, 92, 50, 30);
    if (path1 == path2) {
        printf("92*50 path1 == path2\n");
    }
    
    _context->flush();
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
    
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    [EAGLContext setCurrentContext:nil];
    count++;
}

- (void)drawText:(NSString *)text {
    SkPaint p;
    p.setTextSize(20);
    p.setStrokeWidth(2.0);
    p.setAntiAlias(false);
    _canvas->drawText([text UTF8String], text.length, 100, 100, p);
}

@end
