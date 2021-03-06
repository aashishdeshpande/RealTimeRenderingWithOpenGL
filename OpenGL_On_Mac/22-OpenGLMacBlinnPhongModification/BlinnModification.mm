#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/CVDisplayLink.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>
#import "vmath.h"
#import "Sphere.h"

enum
{
	VDG_ATTRIBUTE_POSITION = 0,
	VDG_ATTRIBUTE_COLOR,
	VDG_ATTRIBUTE_NORMAL,
	VDG_ATTRIBUTE_TEXTURE0,
};

//'C' style global function declarations
CVReturn MyDisplayLinkCallback(CVDisplayLinkRef, const CVTimeStamp *, const CVTimeStamp *, CVOptionFlags, CVOptionFlags *, void *);

GLfloat lightAmbient[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
GLfloat lightDiffuse[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat lightSpecular[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat lightPosition[4] = { 100.0f, 100.0f, 100.0f, 1.0f };

GLfloat material_ambient[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
GLfloat material_diffuse[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat material_specular[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat material_shininess = 50.0f;

float sphere_textures[764];
float sphere_vertices[1146];
float sphere_normals[1146];
unsigned short sphere_elements[2280];


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

	[window setTitle:@"macOS PerFragment Lighting Blinn Modification"];
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

	GLuint vertexShaderObject;
	GLuint fragmentShaderObject;
	GLuint shaderProgramObject;

	GLuint vao_sphere;
	GLuint vbo_sphere_position;
	GLuint vbo_sphere_normal;
	GLuint vbo_sphere_element;

	GLuint modelMatrixUniform, viewMatrixUniform, projectionMatrixUniform;

	GLuint ldUniform, kdUniform, lightPositionUniform;

	GLuint laUniform, kaUniform, lsUniform, ksUniform, materialShininessUniform;

	GLuint lKeyPressedUniform;

	vmath::mat4 projectionMatrix;

	bool light;
    
    GLuint numVertices;
    GLuint numElements;


	/*GLfloat lightAmbient[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
	GLfloat lightDiffuse[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	GLfloat lightSpecular[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	GLfloat lightPosition[4] = { 100.0f, 100.0f, 100.0f, 1.0f };

	GLfloat material_ambient[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
	GLfloat material_diffuse[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	GLfloat material_specular[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	GLfloat material_shininess = 50.0f;*/


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
    int getNumberOfSphereVertices(void);
    int getNumberOfSphereElements(void);
    void getSphereVertexData(float spherePositionCoords[], float sphereNormalCoords[], float sphereTexCoords[], unsigned short sphereElements[]);
    
	fprintf(gpFile, "OpenGL Version : %s\n", glGetString(GL_VERSION));
	fprintf(gpFile, "GLSL Version   : %s\n", glGetString(GL_SHADING_LANGUAGE_VERSION));

	[[self openGLContext]makeCurrentContext];

	GLint swapInt = 1;
	[[self openGLContext]setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

	/*Vertex shader*/
	vertexShaderObject = glCreateShader(GL_VERTEX_SHADER);

	const GLchar *vertexShaderSourceCode =
   		"#version 410 core" \
		"\n" \
		"in vec4 vPosition;" \
		"in vec3 vNormal;" \
		"uniform mat4 u_model_matrix;" \
		"uniform mat4 u_view_matrix;" \
		"uniform mat4 u_projection_matrix;" \
		"uniform vec4 u_light_position;" \
		"uniform int u_lighting_enabled;" \
		"out vec3 transformed_normals;" \
		"out vec3 light_direction;" \
		"out vec3 viewer_vector;" \
		"void main(void)" \
		"{" \
		"if(u_lighting_enabled == 1)" \
		"{" \
		"vec4 eyeCoordinates = u_view_matrix * u_model_matrix * vPosition;" \
		"transformed_normals = normalize(mat3(u_view_matrix * u_model_matrix) * vNormal);" \
		"light_direction = normalize(vec3(u_light_position) - eyeCoordinates.xyz);" \
		"viewer_vector = normalize(-eyeCoordinates.xyz);"
		"}" \
		"gl_Position = u_projection_matrix * u_view_matrix * u_model_matrix * vPosition;" \
		"}";
	glShaderSource(vertexShaderObject, 1, (const GLchar **)&vertexShaderSourceCode, NULL);
	glCompileShader(vertexShaderObject);
	GLint iInfoLength = 0;
	GLint iShaderCompiledStatus = 0;
	char *szInfoLog = NULL;
	glGetShaderiv(vertexShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(vertexShaderObject, GL_INFO_LOG_LENGTH, &iInfoLength);
			if (iInfoLength > 0)
			{
				szInfoLog = (char *)malloc(iInfoLength);
				if (szInfoLog != NULL)
				{
					GLsizei written;
					glGetShaderInfoLog(vertexShaderObject, iInfoLength, &written, szInfoLog);
					fprintf(gpFile, "Vertex Shader Compilation Log : %s", szInfoLog);
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

	fragmentShaderObject = glCreateShader(GL_FRAGMENT_SHADER);

	const GLchar *fragmentShaderSourceCode =
    	"#version 410 core" \
		"\n" \
		"in vec3 transformed_normals;" \
		"in vec3 light_direction;" \
		"in vec3 viewer_vector;" \
		"out vec4 FragColor;" \
		"uniform vec3 u_La;" \
		"uniform vec3 u_Ka;" \
		"uniform vec3 u_Ld;" \
		"uniform vec3 u_Kd;" \
		"uniform vec3 u_Ls;" \
		"uniform vec3 u_Ks;" \
		"uniform float u_material_shininess;" \
		"uniform int u_lighting_enabled;" \
		"void main(void)" \
		"{" \
		"vec3 phong_ads_color;" \
		"if(u_lighting_enabled == 1)" \
		"{" \
		"vec3 normalized_transformed_normals = normalize(transformed_normals);" \
		"vec3 normalized_light_direction = normalize(light_direction);" \
		"vec3 ambient = u_La * u_Ka;" \
		"float tn_dot_ld = max(dot(normalized_transformed_normals, normalized_light_direction), 0.0);" \
		"vec3 diffuse = u_Ld * u_Kd * tn_dot_ld;" \
		"vec3 normalized_viewer_vector = normalize(viewer_vector);" \
		//"float mag = abs(length(normalized_light_direction) + length(normalized_viewer_vector));"
		"vec3 halfVector = normalize((normalized_light_direction + normalized_viewer_vector));"\
		"vec3 specular = u_Ls * u_Ks * pow(max(dot(halfVector, normalized_transformed_normals), 0.0), u_material_shininess);" \
		"phong_ads_color = ambient + diffuse + specular;" \
		"}"
		"else" \
		"{" \
		"phong_ads_color = vec3(1.0, 1.0, 1.0);" \
		"}"\
		"FragColor = vec4(phong_ads_color, 1.0);" \
		"}";
	glShaderSource(fragmentShaderObject, 1, (const GLchar **)&fragmentShaderSourceCode, NULL);
	glCompileShader(fragmentShaderObject);
	glGetShaderiv(fragmentShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(fragmentShaderObject, GL_INFO_LOG_LENGTH, &iInfoLength);
		if (iInfoLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetShaderInfoLog(fragmentShaderObject, iInfoLength, &written, szInfoLog);
				fprintf(gpFile, "Fragment Shader Compilation Log : %s\n",szInfoLog);
				free(szInfoLog);
				[self release];
				[NSApp terminate:self];
			}
		}
	}

	//SHADER PROGRAM
	shaderProgramObject = glCreateProgram();
	glAttachShader(shaderProgramObject, vertexShaderObject);
	glAttachShader(shaderProgramObject, fragmentShaderObject);
	glBindAttribLocation(shaderProgramObject, VDG_ATTRIBUTE_POSITION, "vPosition");
	glBindAttribLocation(shaderProgramObject, VDG_ATTRIBUTE_NORMAL, "vNormal");

	glLinkProgram(shaderProgramObject);
	
	GLint iShaderProgramLinkStatus = 0;
	glGetProgramiv(shaderProgramObject, GL_LINK_STATUS, &iShaderProgramLinkStatus);
	if (iShaderProgramLinkStatus == GL_FALSE)
	{
		glGetProgramiv(shaderProgramObject, GL_INFO_LOG_LENGTH, &iInfoLength);
		if (iInfoLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetProgramInfoLog(shaderProgramObject, iInfoLength, &written, szInfoLog);
				fprintf(gpFile, "Shader Program Link Log : %s\n", szInfoLog);
				free(szInfoLog);
				[self release];
				[NSApp terminate:self];
			}
		}
	}
	modelMatrixUniform = glGetUniformLocation(shaderProgramObject, "u_model_matrix");
	viewMatrixUniform = glGetUniformLocation(shaderProgramObject, "u_view_matrix");
	projectionMatrixUniform = glGetUniformLocation(shaderProgramObject, "u_projection_matrix");

	lKeyPressedUniform = glGetUniformLocation(shaderProgramObject, "u_lighting_enabled");


	laUniform = glGetUniformLocation(shaderProgramObject, "u_La");
	kaUniform = glGetUniformLocation(shaderProgramObject, "u_Ka");

	ldUniform = glGetUniformLocation(shaderProgramObject, "u_Ld");
	kdUniform = glGetUniformLocation(shaderProgramObject, "u_Kd");

	lsUniform = glGetUniformLocation(shaderProgramObject, "u_Ls");
	ksUniform = glGetUniformLocation(shaderProgramObject, "u_Ks");

	lightPositionUniform = glGetUniformLocation(shaderProgramObject, "u_light_position");

	materialShininessUniform = glGetUniformLocation(shaderProgramObject, "u_material_shininess");
	
	Sphere *sphere = [[Sphere alloc] init];

	[sphere getSphereVertexData:sphere_vertices :sphere_normals :sphere_textures :sphere_elements];
	numVertices = [sphere getNumberOfSphereVertices];
	numElements = [sphere getNumberOfSphereElements];

		// vao
	glGenVertexArrays(1, &vao_sphere);
	glBindVertexArray(vao_sphere);

	// position vbo
	glGenBuffers(1, &vbo_sphere_position);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_sphere_position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(sphere_vertices), sphere_vertices, GL_STATIC_DRAW);

	glVertexAttribPointer(VDG_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(VDG_ATTRIBUTE_POSITION);

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	// normal vbo
	glGenBuffers(1, &vbo_sphere_normal);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_sphere_normal);
	glBufferData(GL_ARRAY_BUFFER, sizeof(sphere_normals), sphere_normals, GL_STATIC_DRAW);

	glVertexAttribPointer(VDG_ATTRIBUTE_NORMAL, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(VDG_ATTRIBUTE_NORMAL);

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	// element vbo
	glGenBuffers(1, &vbo_sphere_element);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_sphere_element);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(sphere_elements), sphere_elements, GL_STATIC_DRAW);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	// unbind vao
	glBindVertexArray(0);

	//glShadeModel(GL_SMOOTH);
	glClearDepth(1.0f);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	//glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
	//glEnable(GL_CULL_FACE);
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
//	MessageBox(NULL, TEXT("Exiting Init"), TEXT("Error"), MB_OK);
	projectionMatrix = vmath::mat4::identity();

	light = false;

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

	projectionMatrix = vmath::perspective(45.0f, (GLfloat)width/(GLfloat)height, 0.1f, 100.0f);
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

	glUseProgram(shaderProgramObject);

	if (light == true)
	{
		glUniform1i(lKeyPressedUniform, 1);

		glUniform3fv(laUniform, 1, lightAmbient);
		glUniform3fv(kaUniform, 1, material_ambient);

		glUniform3fv(ldUniform, 1, lightDiffuse);
		glUniform3fv(kdUniform, 1, material_diffuse);

		glUniform3fv(lsUniform, 1, lightSpecular);
		glUniform3fv(ksUniform, 1, material_specular);

		glUniform1f(materialShininessUniform, material_shininess);

		//float lightPosition[] = { 0.0f, 0.0f, 2.0f, 1.0f };
		glUniform4fv(lightPositionUniform, 1, (GLfloat *)lightPosition);
	}

	else
	{
		glUniform1i(lKeyPressedUniform, 0);
	}

	vmath::mat4 modelMatrix = vmath::mat4::identity();
	vmath::mat4 viewMatrix = vmath::mat4::identity();
	
	modelMatrix = vmath::translate(0.0f, 0.0f, -2.0f);

	glUniformMatrix4fv(modelMatrixUniform, 1, GL_FALSE, modelMatrix);
	glUniformMatrix4fv(viewMatrixUniform, 1, GL_FALSE, viewMatrix);

	glUniformMatrix4fv(projectionMatrixUniform, 1, GL_FALSE, projectionMatrix);

	glBindVertexArray(vao_sphere);

	// *** draw, either by glDrawTriangles() or glDrawArrays() or glDrawElements()
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_sphere_element);
	glDrawElements(GL_TRIANGLES, numElements, GL_UNSIGNED_SHORT, 0);

	// *** unbind vao ***
	glBindVertexArray(0);

	// stop using OpenGL program object
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
	static bool bIsLKeyPressed = false;
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

		case 'L':
		case 'l':
			if (bIsLKeyPressed == false)
			{
				light = true;
				bIsLKeyPressed = true;
			}
			else
			{
				light = false;
				bIsLKeyPressed = false;
			}
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
	if(vao_sphere)
	{
		glDeleteVertexArrays(1, &vao_sphere);
		vao_sphere = 0;
	}

	if(vbo_sphere_position)
	{
		glDeleteBuffers(1, &vbo_sphere_position);
		vbo_sphere_position = 0;
	}

	if(vbo_sphere_normal)
	{
		glDeleteBuffers(1, &vbo_sphere_normal);
		vbo_sphere_normal = 0;
	}

	if(vbo_sphere_element)
	{
		glDeleteBuffers(1, &vbo_sphere_element);
		vbo_sphere_element = 0;
	}
	glDetachShader(shaderProgramObject, vertexShaderObject);
	glDetachShader(shaderProgramObject, fragmentShaderObject);
	
	glDeleteShader(vertexShaderObject);
	vertexShaderObject = 0;
	
	glDeleteShader(fragmentShaderObject);
	fragmentShaderObject = 0;

	glDeleteProgram(shaderProgramObject);
	shaderProgramObject = 0;

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


