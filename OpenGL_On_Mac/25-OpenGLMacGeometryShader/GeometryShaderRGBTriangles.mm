#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/CVDisplayLink.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>
#import "vmath.h"

enum
{
	VDG_ATTRIBUTE_POSITION = 0,
	VDG_ATTRIBUTE_COLOR,
	VDG_ATTRIBUTE_NORMAL,
	VDG_ATTRIBUTE_TEXTURE0,
};

//'C' style global function declarations
CVReturn MyDisplayLinkCallback(CVDisplayLinkRef, const CVTimeStamp *, const CVTimeStamp *, CVOptionFlags, CVOptionFlags *, void *);

FILE *gpFile = NULL;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@end

@interface GLView : NSOpenGLView
@end

int main(int argc, const char* argv[])
{
	NSAutoreleasePool *pPool = [[NSAutoreleasePool alloc]init];

	NSApp = [NSApplication sharedApplication];

	[NSApp setDelegate : [[AppDelegate alloc] init]];

	[NSApp run];

	[pPool release];

	return(0);
}

@implementation AppDelegate
{
	@private
		NSWindow *window;
		GLView *glView;	
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//log file
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *appDirName = [mainBundle bundlePath];
	NSString *parentDirPath = [appDirName stringByDeletingLastPathComponent];
	NSString *logFileNameWithPath = [NSString stringWithFormat:@"%@/Log.txt", parentDirPath];
	const char *pszLogFileNameWithPath = [logFileNameWithPath cStringUsingEncoding:NSASCIIStringEncoding];
	gpFile = fopen(pszLogFileNameWithPath, "w");
	if(gpFile == NULL)
	{
		printf("Can not Create Log File.\nExiting....\n");
		[self release];
		[NSApp terminate:self];
	}

	fprintf(gpFile, "Program Is Started Successfully\n");

	//window
	NSRect win_rect;
	win_rect = NSMakeRect(0.0, 0.0, 800.0, 600.0);

	window = [[NSWindow alloc]initWithContentRect:win_rect
	 			styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
	 			backing:NSBackingStoreBuffered
	 			defer:NO];

	[window setTitle:@"macOS Geometry Shader RGB Triangles"];
	[window center];

	glView = [[GLView alloc]initWithFrame:win_rect];

	[window setContentView:glView];
	[window setDelegate:self];
	[window makeKeyAndOrderFront:self];
}

-(void)applicationWillTerminate:(NSNotification *)aNotification
{
	fprintf(gpFile, "Program Is Terminated Successfully\n");

	if(gpFile)
	{
		fclose(gpFile);
		gpFile = NULL;
	}
}

-(void)windowWillClose:(NSNotification *)notification
{
	[NSApp terminate:self];
}

-(void)dealloc
{
	[glView release];

	[window release];

	[super dealloc];
}
@end

@implementation GLView
{
@private
	CVDisplayLinkRef displayLink;

	GLuint gVertexShaderObject;
    GLuint gGeometryShaderObject;
	GLuint gFragmentShaderObject;
	GLuint gShaderProgramObject;

	GLuint gVao;
	GLuint gVbo_Position;
    GLuint gVbo_Color;
	GLuint gMvpUniform;

	vmath::mat4 gPerspectiveProjectionMatrix;

}

-(id)initWithFrame:(NSRect)frame;
{
	self = [super initWithFrame:frame];

	if(self)
	{
		[[self window]setContentView:self];

		NSOpenGLPixelFormatAttribute attrs[] =
		{
			NSOpenGLPFAOpenGLProfile,
			NSOpenGLProfileVersion4_1Core,

			NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
			NSOpenGLPFANoRecovery,
			NSOpenGLPFAAccelerated,
			NSOpenGLPFAColorSize,24,
			NSOpenGLPFADepthSize,24,
			NSOpenGLPFAAlphaSize,8,
			NSOpenGLPFADoubleBuffer,
			0};

			NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc]initWithAttributes:attrs]autorelease];

			if(pixelFormat == nil)
			{
				fprintf(gpFile, "No Valid OpenGL Pixel Format Is Available. Exiting....");
				[self release];
				[NSApp terminate:self];
			}

			NSOpenGLContext *glContext = [[[NSOpenGLContext alloc]initWithFormat:pixelFormat shareContext:nil]autorelease];

			[self setPixelFormat:pixelFormat];

			[self setOpenGLContext:glContext];
	}

	return(self);
}

-(CVReturn)getFrameForTime:(const CVTimeStamp *)pOutputTime
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];

	[self drawView];

	[pool release];

	return(kCVReturnSuccess);
}

-(void)prepareOpenGL
{
	fprintf(gpFile, "OpenGL Version : %s\n", glGetString(GL_VERSION));
	fprintf(gpFile, "GLSL Version   : %s\n", glGetString(GL_SHADING_LANGUAGE_VERSION));

	[[self openGLContext]makeCurrentContext];

	GLint swapInt = 1;
	[[self openGLContext]setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

	/*Vertex shader*/
	gVertexShaderObject = glCreateShader(GL_VERTEX_SHADER);

	const GLchar *vertexShaderSourceCode =
		"#version 410 core" \
		"\n" \
		"in vec4 vPosition;" \
        "in vec4 vColor;" \
        "out vec4 out_Color;" \
        "uniform mat4 u_mvp_matrix;" \
		"void main(void)" \
		"{" \
		"gl_Position = u_mvp_matrix * vPosition;" \
        "out_Color = vColor;" \
		"}";
	glShaderSource(gVertexShaderObject, 1, (const GLchar **)&vertexShaderSourceCode, NULL);
	glCompileShader(gVertexShaderObject);
	GLint iInfoLength = 0;
	GLint iShaderCompiledStatus = 0;
	char *szInfoLog = NULL;
	glGetShaderiv(gVertexShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(gVertexShaderObject, GL_INFO_LOG_LENGTH, &iInfoLength);
			if (iInfoLength > 0)
			{
				szInfoLog = (char *)malloc(iInfoLength);
				if (szInfoLog != NULL)
				{
					GLsizei written;
					glGetShaderInfoLog(gVertexShaderObject, iInfoLength, &written, szInfoLog);
					fprintf(gpFile, "Vertex Shader Compilation Log : %s", szInfoLog);
					free(szInfoLog);
					[self release];
					[NSApp terminate:self];
				}
			}
		}
    
    
    //**GEOMETRY SHADER **
    //create shader
    gGeometryShaderObject = glCreateShader(GL_GEOMETRY_SHADER);
    
    //provide source code
    
    const GLchar *geometryShaderSourceCode =
    "#version 410" \
    "\n" \
    "layout(triangles)in;" \
    "layout(triangle_strip, max_vertices = 9)out;" \
    "uniform mat4 u_mvp_matrix;" \
    "in vec4 out_Color[];" \
    "out vec4 fColor;" \
    "void main(void)" \
    "{" \
    "for(int vertex = 0; vertex < 3; vertex++)" \
    "{" \
    "fColor = out_Color[vertex];" \
    "gl_Position = u_mvp_matrix * (gl_in[vertex].gl_Position + vec4(0.0, 1.0, 0.0, 0.0));" \
    "EmitVertex();" \
    "fColor = out_Color[vertex];" \
    "gl_Position = u_mvp_matrix * (gl_in[vertex].gl_Position + vec4(-1.0, -1.0, 0.0, 0.0));" \
    "EmitVertex();" \
    "fColor = out_Color[vertex];" \
    "gl_Position = u_mvp_matrix * (gl_in[vertex].gl_Position + vec4(1.0, -1.0, 0.0, 0.0));" \
    "EmitVertex();" \
    "EndPrimitive();" \
    "}" \
    "}";
    
    glShaderSource(gGeometryShaderObject, 1, (const GLchar**)&geometryShaderSourceCode, NULL);
    
    glCompileShader(gGeometryShaderObject);
    
    GLint iInfoLogLength = 0;
    iShaderCompiledStatus = 0;
    szInfoLog = NULL;
    glGetShaderiv(gGeometryShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
    if (iShaderCompiledStatus == GL_FALSE)
    {
        glGetShaderiv(gGeometryShaderObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength > 0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetShaderInfoLog(gGeometryShaderObject, iInfoLogLength, &written, szInfoLog);
                fprintf(gpFile, "Geometry Shader Compilation Log : %s\n", szInfoLog);
                free(szInfoLog);
                [self release];
                [NSApp terminate:self];
            }
        }
    }



	//FRAGMENT SHADER
	iInfoLength = 0;
	iShaderCompiledStatus = 0;
	szInfoLog = 0;

	gFragmentShaderObject = glCreateShader(GL_FRAGMENT_SHADER);

	const GLchar *fragmentShaderSourceCode =
    "#version 410" \
    "\n" \
    "in vec4 fColor;" \
    "out vec4 FragColor;" \
    "void main(void)" \
    "{" \
    "FragColor = fColor;" \
    "}";
	glShaderSource(gFragmentShaderObject, 1, (const GLchar **)&fragmentShaderSourceCode, NULL);
	glCompileShader(gFragmentShaderObject);
	glGetShaderiv(gFragmentShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(gFragmentShaderObject, GL_INFO_LOG_LENGTH, &iInfoLength);
		if (iInfoLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetShaderInfoLog(gFragmentShaderObject, iInfoLength, &written, szInfoLog);
				fprintf(gpFile, "Fragment Shader Compilation Log : %s\n",szInfoLog);
				free(szInfoLog);
				[self release];
				[NSApp terminate:self];
			}
		}
	}

	//SHADER PROGRAM
	gShaderProgramObject = glCreateProgram();
	glAttachShader(gShaderProgramObject, gVertexShaderObject);
    glAttachShader(gShaderProgramObject, gGeometryShaderObject);
	glAttachShader(gShaderProgramObject, gFragmentShaderObject);
	glBindAttribLocation(gShaderProgramObject, VDG_ATTRIBUTE_POSITION, "vPosition");
    glBindAttribLocation(gShaderProgramObject, VDG_ATTRIBUTE_COLOR, "vColor");
	glLinkProgram(gShaderProgramObject);
	
	GLint iShaderProgramLinkStatus = 0;
	glGetProgramiv(gShaderProgramObject, GL_LINK_STATUS, &iShaderProgramLinkStatus);
	if (iShaderProgramLinkStatus == GL_FALSE)
	{
		glGetProgramiv(gShaderProgramObject, GL_INFO_LOG_LENGTH, &iInfoLength);
		if (iInfoLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetProgramInfoLog(gShaderProgramObject, iInfoLength, &written, szInfoLog);
				fprintf(gpFile, "Shader Program Link Log : %s\n", szInfoLog);
				free(szInfoLog);
				[self release];
				[NSApp terminate:self];
			}
		}
	}
	gMvpUniform = glGetUniformLocation(gShaderProgramObject, "u_mvp_matrix");

	const GLfloat triangleVertices[] =
	{
		0.0f, 1.0f, 0.0f,
		-1.0f, -1.0f, 0.0f,
		1.0f, -1.0f, 0.0f
	};
    
    const GLfloat colorVertices[] =
    {
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f
    };

	glGenVertexArrays(1, &gVao);
	glBindVertexArray(gVao);

	glGenBuffers(1, &gVbo_Position);
	glBindBuffer(GL_ARRAY_BUFFER, gVbo_Position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(triangleVertices),triangleVertices, GL_STATIC_DRAW);
	glVertexAttribPointer(VDG_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(VDG_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glGenBuffers(1, &gVbo_Color);
    glBindBuffer(GL_ARRAY_BUFFER, gVbo_Color);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colorVertices),colorVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(VDG_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(VDG_ATTRIBUTE_COLOR);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    
	glBindVertexArray(0);
	//glShadeModel(GL_SMOOTH);
	glClearDepth(1.0f);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	//glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
	//glEnable(GL_CULL_FACE);
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
//	MessageBox(NULL, TEXT("Exiting Init"), TEXT("Error"), MB_OK);
	gPerspectiveProjectionMatrix = vmath::mat4::identity();

	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, self);
	CGLContextObj cglContext = (CGLContextObj)[[self openGLContext]CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[self pixelFormat]CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
	CVDisplayLinkStart(displayLink);

}

-(void)reshape
{
	CGLLockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);

	NSRect rect = [self bounds];

	GLfloat width = rect.size.width;
	GLfloat height = rect.size.height;

	if(height == 0)
		height = 1;

	glViewport(0, 0, (GLsizei)width, (GLsizei)height);

	gPerspectiveProjectionMatrix = vmath::perspective(45.0f, (GLfloat)width/(GLfloat)height, 0.1f, 100.0f);
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);	

}

-(void)drawRect:(NSRect)dirtyRect
{
	[self drawView];
}

-(void)drawView
{
	[[self openGLContext]makeCurrentContext];

	CGLLockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);

	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glUseProgram(gShaderProgramObject);

	vmath::mat4 modelViewMatrix = vmath::mat4::identity();

	vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

	vmath::mat4 translateMatrix = vmath::translate(0.0f, 0.0f, -5.0f);

	modelViewMatrix = modelViewMatrix * translateMatrix;

	modelViewProjectionMatrix = gPerspectiveProjectionMatrix * modelViewMatrix;

	glUniformMatrix4fv(gMvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

	glBindVertexArray(gVao);

	glDrawArrays(GL_TRIANGLES, 0, 3);

	glBindVertexArray(0);

	glUseProgram(0);

	CGLFlushDrawable((CGLContextObj)[[self openGLContext]CGLContextObj]);
	CGLUnlockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);
}

-(BOOL)acceptsFirstResponder
{
	[[self window]makeFirstResponder:self];
	return(YES);
}

-(void)keyDown:(NSEvent *)theEvent
{
	int key = (int)[[theEvent characters]characterAtIndex:0];

	switch(key)
	{
		case 27:
			[self release];
			[NSApp terminate:self];
			break;

		case 'F':
		case 'f':
			[[self window]toggleFullScreen:self];
			break;

		default:
			break;
	}
}

-(void)mouseDown:(NSEvent *)theEvent
{

}

-(void)mouseDragged:(NSEvent *)theEvent
{

}

-(void)rightMouseDown:(NSEvent *)theEvent
{

}

-(void)dealloc
{
	if(gVao)
	{
		glDeleteVertexArrays(1, &gVao);
		gVao = 0;
	}

	if(gVbo_Position)
	{
		glDeleteBuffers(1, &gVbo_Position);
		gVbo_Position = 0;
	}
    
    if(gVbo_Color)
    {
        glDeleteBuffers(1, &gVbo_Color);
        gVbo_Color = 0;
    }

	glDetachShader(gShaderProgramObject, gVertexShaderObject);
    glDetachShader(gShaderProgramObject, gGeometryShaderObject);
	glDetachShader(gShaderProgramObject, gFragmentShaderObject);
	
	glDeleteShader(gVertexShaderObject);
	gVertexShaderObject = 0;
    
    glDeleteShader(gGeometryShaderObject);
    gGeometryShaderObject = 0;
	
	glDeleteShader(gFragmentShaderObject);
	gFragmentShaderObject = 0;

	glDeleteProgram(gShaderProgramObject);
	gShaderProgramObject = 0;

	CVDisplayLinkStop(displayLink);
	CVDisplayLinkRelease(displayLink);

	[super dealloc];

}
@end

CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *pNow, const CVTimeStamp *pOutputTime, CVOptionFlags flagsIn, CVOptionFlags *pFlagsOut, void *pDisplayLinkContext)
{
	CVReturn result = [(GLView *)pDisplayLinkContext getFrameForTime:pOutputTime];
	return(result);
}
