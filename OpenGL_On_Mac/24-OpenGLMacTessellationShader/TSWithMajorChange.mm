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

	[window setTitle:@"macOS Tessellation Shader With Major Change"];
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
	GLuint gFragmentShaderObject;
    GLuint gTessellationControlShaderObject;
    GLuint gTessellationEvaluationShaderObject;
	GLuint gShaderProgramObject;

	GLuint gVao;
	GLuint gVbo;
    GLuint gNumberOfSegmentsUniform;
    GLuint gNumberOfStripsUniform;
    GLuint gLineColorUniform;
	GLuint gMvpUniform;
    
    unsigned int gNumberOfLineSegments;

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
		"in vec2 vPosition;" \
		"void main(void)" \
		"{" \
		"gl_Position = vec4(vPosition, 0.0, 1.0);" \
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
    
    // ***TESSELLATION CONTROL SHADER ***
    //create shader
    gTessellationControlShaderObject = glCreateShader(GL_TESS_CONTROL_SHADER);
    
    //provide source code to shader
    const GLchar *tessellationControlShaderSourceCode =
    "#version 410" \
    "\n" \
    "layout(vertices=4)out;" \
    "uniform int numberOfSegments;" \
    "uniform int numberOfStrips;" \
    "void main(void)" \
    "{" \
    "gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;" \
    "gl_TessLevelOuter[0] = float(numberOfStrips);" \
    "gl_TessLevelOuter[1] = float(numberOfSegments);" \
    "}";
    
    glShaderSource(gTessellationControlShaderObject, 1, (const GLchar **)&tessellationControlShaderSourceCode, NULL);
    
    //compile shader
    glCompileShader(gTessellationControlShaderObject);
    
    GLint iInfoLogLength = 0;
    iShaderCompiledStatus = 0;
    szInfoLog = NULL;
    
    glGetShaderiv(gTessellationControlShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
    if (iShaderCompiledStatus == GL_FALSE)
    {
        glGetShaderiv(gTessellationControlShaderObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength > 0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetShaderInfoLog(gTessellationControlShaderObject, iInfoLogLength, &written, szInfoLog);
                fprintf(gpFile, "Tessellation Control Shader Compilation Log : %s\n", szInfoLog);
                free(szInfoLog);
                [self release];
                [NSApp terminate:self];
            }
        }
    }
    
    // *** TESSELLATION EVALUATION SHADER ***
    //create shader
    gTessellationEvaluationShaderObject = glCreateShader(GL_TESS_EVALUATION_SHADER);
    
    //provide source code to shader
    const GLchar *tessellationEvaluationShaderSourceCode =
    "#version 410" \
    "\n" \
    "layout(isolines)in;" \
    "uniform mat4 u_mvp_matrix;" \
    "void main(void)" \
    "{" \
    "float u = gl_TessCoord.x;" \
    "vec3 p0 = gl_in[0].gl_Position.xyz;" \
    "vec3 p1 = gl_in[1].gl_Position.xyz;" \
    "vec3 p2 = gl_in[2].gl_Position.xyz;" \
    "vec3 p3 = gl_in[3].gl_Position.xyz;" \
    "float u1 = (1.0 - u);" \
    "float u2 = u * u;" \
    "float b3 = u2 * u;" \
    "float b2 = 3.0 * u2 * u1;" \
    "float b1 = u1 * u1 * u1;" \
    "float b0 = u1 * u1 * u1;" \
    "vec3 p = p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3;" \
    "gl_Position = u_mvp_matrix * vec4(p, 1.0);" \
    "}";
    
    glShaderSource(gTessellationEvaluationShaderObject, 1, (const GLchar **)&tessellationEvaluationShaderSourceCode, NULL);
    
    //compile shader
    glCompileShader(gTessellationEvaluationShaderObject);
    
    iInfoLogLength = 0;
    iShaderCompiledStatus = 0;
    szInfoLog = NULL;
    
    glGetShaderiv(gTessellationEvaluationShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
    if (iShaderCompiledStatus == GL_FALSE)
    {
        glGetShaderiv(gTessellationEvaluationShaderObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength > 0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetShaderInfoLog(gTessellationEvaluationShaderObject, iInfoLogLength, &written, szInfoLog);
                fprintf(gpFile, "Tessellation Evaluation Shader Compilation Log : %s\n", szInfoLog);
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
    "#version 410 core" \
    "\n" \
    "uniform vec4 lineColor;" \
    "out vec4 FragColor;" \
    "void main(void)" \
    "{" \
    "FragColor = lineColor;" \
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
    // attach tessellation control shader to shader program
    glAttachShader(gShaderProgramObject, gTessellationControlShaderObject);
    
    // attach tessellation evaluation shader to shader program
    glAttachShader(gShaderProgramObject, gTessellationEvaluationShaderObject);

	glAttachShader(gShaderProgramObject, gFragmentShaderObject);
	glBindAttribLocation(gShaderProgramObject, VDG_ATTRIBUTE_POSITION, "vPosition");
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
    // get MVP uniform location
    gMvpUniform = glGetUniformLocation(gShaderProgramObject, "u_mvp_matrix");
    
    //get number of segments uniform location
    gNumberOfSegmentsUniform = glGetUniformLocation(gShaderProgramObject, "numberOfSegments");
    
    //get number of strips uniform location
    gNumberOfStripsUniform = glGetUniformLocation(gShaderProgramObject, "numberOfStrips");
    
    //get line color uniform location
    gLineColorUniform = glGetUniformLocation(gShaderProgramObject, "lineColor");

    float vertices[] = { -1.0f, -1.0f, -0.5f, 1.0f, 0.5f, -1.0f, 1.0f, 1.0f };

	glGenVertexArrays(1, &gVao);
	glBindVertexArray(gVao);

	glGenBuffers(1, &gVbo);
	glBindBuffer(GL_ARRAY_BUFFER, gVbo);
	glBufferData(GL_ARRAY_BUFFER, 8 * sizeof(float),vertices, GL_STATIC_DRAW);
	glVertexAttribPointer(VDG_ATTRIBUTE_POSITION, 2, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(VDG_ATTRIBUTE_POSITION);
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

    gNumberOfLineSegments = 1;

    
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

	vmath::mat4 translateMatrix = vmath::translate(0.0f, 0.0f, -4.0f);

	modelViewMatrix = modelViewMatrix * translateMatrix;

	modelViewProjectionMatrix = gPerspectiveProjectionMatrix * modelViewMatrix;

	glUniformMatrix4fv(gMvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

    glUniform1i(gNumberOfSegmentsUniform, gNumberOfLineSegments);
    
    glUniform1i(gNumberOfStripsUniform, 1);
    glUniform4fv(gLineColorUniform, 1, vmath::vec4(1.0f, 1.0f, 0.0f, 1.0f));
    
	glBindVertexArray(gVao);

    glPatchParameteri(GL_PATCH_VERTICES, 4);
	glDrawArrays(GL_PATCHES, 0, 4); //

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
            
        case 'I':
        case 'i':
            gNumberOfLineSegments++;
            if (gNumberOfLineSegments >= 50)
                gNumberOfLineSegments = 50;
            break;
            
        case 'D':
        case 'd':
            gNumberOfLineSegments--;
            if (gNumberOfLineSegments <= 0)
                gNumberOfLineSegments = 1;
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

	if(gVbo)
	{
		glDeleteBuffers(1, &gVbo);
		gVbo = 0;
	}

	glDetachShader(gShaderProgramObject, gVertexShaderObject);
	glDetachShader(gShaderProgramObject, gFragmentShaderObject);
	
	glDeleteShader(gVertexShaderObject);
	gVertexShaderObject = 0;
    
    //delete tessellation control shader object
    glDeleteShader(gTessellationControlShaderObject);
    gTessellationControlShaderObject = 0;
    
    //delete tessellation evaluation shader object
    glDeleteShader(gTessellationEvaluationShaderObject);
    gTessellationEvaluationShaderObject = 0;
	
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
