#include <iostream>
#include <stdio.h>
#include <stdlib.h> 
#include <memory.h> 

#include <X11/Xlib.h>
#include <X11/Xutil.h> 
#include <X11/XKBlib.h>
#include <X11/keysym.h> 

#include <GL/gl.h>
#include <GL/glu.h>
#include <GL/glx.h>

//namespaces
using namespace std;

//global variable declarations
bool bFullscreen=false;
Display *gpDisplay=NULL;
XVisualInfo *gpXVisualInfo=NULL;
Colormap gColormap;
Window gWindow;
int giWindowWidth=800;
int giWindowHeight=600;

float spinCube=0.0f;
float spinPyramid=0.0f;

FILE *gpFile=NULL;

GLXContext gGLXContext;

//entry-point function
int main(void)
{
	//function prototypes
	void CreateWindow(void);
	void ToggleFullscreen(void);
	void initialize(void);
	void display(void);
	void resize(int,int);
	void uninitialize();
	void spin(void);
	
	//variable declarations
	int winWidth=giWindowWidth;
	int winHeight=giWindowHeight;
	
	bool bDone=false;
	
	gpFile=fopen("OGLLog.txt","w");
	if(gpFile==NULL)
	{
	printf("Error Message");
	exit(0);	
	}
	//code

	fprintf(gpFile,"\nIn Main()\n");
	CreateWindow();

	//initialize
	initialize();
	
	//Message Loop
	XEvent event;
	KeySym keysym;
	
	while(bDone==false)
	{
		while(XPending(gpDisplay))
		{
			XNextEvent(gpDisplay,&event);
			switch(event.type)
			{
				case MapNotify:
					break;
				case KeyPress:
					keysym=XkbKeycodeToKeysym(gpDisplay,event.xkey.keycode,0,0);
				switch(keysym)
					{
						case XK_Escape:
							uninitialize();
							exit(0);
						case XK_F:
						case XK_f:
							if(bFullscreen==false)
							{
								ToggleFullscreen();
								bFullscreen=true;
							}
							else
							{
								ToggleFullscreen();
								bFullscreen=false;
							}
							break;
						default:
							break;
					}
					break;
				case ButtonPress: 
					switch(event.xbutton.button)
					{
						case 1: 
						    break;
						case 2: 
						    break;
						case 3: 
						    break;
						default:
						    break;
					}
					break;
				case MotionNotify: 
					break;
				case ConfigureNotify: 
					winWidth=event.xconfigure.width;
					winHeight=event.xconfigure.height;
					resize(winWidth,winHeight);
					break;
				case Expose: 
					break;
				case DestroyNotify:
					break;
				case 33:
					bDone=true;
					break;
				default:
					break;
			}
		
		}

		display();
		spin();
	}
	return(0);
}

void CreateWindow(void)
{
	fprintf(gpFile,"\nIn CreateWindow()\n");
	//function prorttypes
	void uninitialize(void);

	//variable declarations
	XSetWindowAttributes winAttribs;
	int defaultScreen;
	int defaultDepth;
	int styleMask;

	static int frameBufferAttributes[]=
	{
		GLX_RGBA,
		GLX_RED_SIZE,8,
		GLX_GREEN_SIZE,8,
		GLX_BLUE_SIZE,8,
		GLX_ALPHA_SIZE,8,
		GLX_DEPTH_SIZE,24,
		GLX_DOUBLEBUFFER,True,
		None 
	}; 
	
	//code
	gpDisplay=XOpenDisplay(NULL);
	if(gpDisplay==NULL)
	{
		printf("ERROR : Unable To Open X Display.\nExitting Now...\n");
		uninitialize();
		exit(1);
	}
	
	defaultScreen=XDefaultScreen(gpDisplay);
	
	gpXVisualInfo=glXChooseVisual(gpDisplay,defaultScreen,frameBufferAttributes);
		
	winAttribs.border_pixel=0;
	winAttribs.background_pixmap=0;
	winAttribs.colormap=XCreateColormap(gpDisplay, 
					    RootWindow(gpDisplay, gpXVisualInfo->screen), 
					    gpXVisualInfo->visual,
 					    AllocNone);
	gColormap=winAttribs.colormap;

	winAttribs.background_pixel=BlackPixel(gpDisplay,defaultScreen);

	winAttribs.event_mask= ExposureMask | VisibilityChangeMask | ButtonPressMask | KeyPressMask | PointerMotionMask |
			       StructureNotifyMask;
	
	styleMask=CWBorderPixel | CWBackPixel | CWEventMask | CWColormap;
	
	gWindow=XCreateWindow(gpDisplay,
			      RootWindow(gpDisplay,gpXVisualInfo->screen),
			      0,
			      0,
			      giWindowWidth,
			      giWindowHeight,
			      0,
			      gpXVisualInfo->depth,
			      InputOutput,
			      gpXVisualInfo->visual,
			      styleMask,
			      &winAttribs);
	if(!gWindow)
	{
		printf("ERROR : Failed To Create Main Window.\nExitting Now...\n");
		uninitialize();
		exit(1);
	}
	
	XStoreName(gpDisplay,gWindow,"X_OpenGL Window:3D Rotating Shapes");
	
	Atom windowManagerDelete=XInternAtom(gpDisplay,"WM_DELETE_WINDOW",True);
	XSetWMProtocols(gpDisplay,gWindow,&windowManagerDelete,1);
	
	XMapWindow(gpDisplay,gWindow);
	fprintf(gpFile,"\nExiting CreateWindow()\n");
}

void ToggleFullscreen(void)
{
	fprintf(gpFile,"\nIn ToggleFullscreen()\n");
	//variable declarations
	Atom wm_state;
	Atom fullscreen;
	XEvent xev={0};
	
	//code
	wm_state=XInternAtom(gpDisplay,"_NET_WM_STATE",False);
	memset(&xev,0,sizeof(xev));
	
	xev.type=ClientMessage;
	xev.xclient.window=gWindow;
	xev.xclient.message_type=wm_state;
	xev.xclient.format=32;
	xev.xclient.data.l[0]=bFullscreen ? 0 : 1;
	
	fullscreen=XInternAtom(gpDisplay,"_NET_WM_STATE_FULLSCREEN",False);
	xev.xclient.data.l[1]=fullscreen;
	
	XSendEvent(gpDisplay,
	           RootWindow(gpDisplay,gpXVisualInfo->screen),
	           False,
	           StructureNotifyMask,
	           &xev);
	fprintf(gpFile,"\nExiting ToggleFullscreen()\n");
}

void initialize(void)
{
	fprintf(gpFile,"\nIn initialize()\n");
	//function prototype
	void resize(int, int);
	
	//code
	gGLXContext=glXCreateContext(gpDisplay,gpXVisualInfo,NULL,GL_TRUE);
	
	glXMakeCurrent(gpDisplay,gWindow,gGLXContext);
	
	glClearColor(0.0f,0.0f,0.0f,0.0f);
	glShadeModel(GL_SMOOTH);
	glClearDepth(1.0f);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	glHint(GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST);
	resize(giWindowWidth,giWindowHeight);
	fprintf(gpFile,"\nIn uninitialize()\n");
}

void display(void)
{
	//code
	fprintf(gpFile,"\nIn display()\n");
	void drawCube(void);
	void drawPyramid(void);
	glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glTranslatef(-1.5f,0.0f,-5.0f);
	glScalef(0.75f,0.75f,0.75f);
	glRotatef(spinCube,1.0f,1.0f,1.0f);
	drawCube();
	glLoadIdentity();
	glTranslatef(1.5f,0.0f,-5.0f);
	glRotatef(spinPyramid,0.0f,1.0f,0.0f);
	drawPyramid();
	glXSwapBuffers(gpDisplay,gWindow);
	fprintf(gpFile,"\nExiting display()\n");
}

void drawCube(void)
{
	fprintf(gpFile,"\nIn drawCube()\n");
	glBegin(GL_QUADS);

	//TOP FACE
	glColor3f(1.0f, 0.0f, 1.0f);
	glVertex3f(1.0f, 1.0f, -1.0f);
	glVertex3f(-1.0f, 1.0f, -1.0f);
	glVertex3f(-1.0f, 1.0f, 1.0f);
	glVertex3f(1.0f, 1.0f, 1.0f);

	//BOTTOM FACE
	glColor3f(1.0f, 0.0f, 0.0f);
	glVertex3f(1.0f, -1.0f, -1.0f);
	glVertex3f(-1.0f, -1.0f, -1.0f);
	glVertex3f(-1.0f, -1.0f, 1.0f);
	glVertex3f(1.0f, -1.0f, 1.0f);

	//FRONT FACE
	glColor3f(0.0f, 1.0f, 0.0f); 
	glVertex3f(1.0f, 1.0f, 1.0f);
	glVertex3f(-1.0f, 1.0f, 1.0f);
	glVertex3f(-1.0f, -1.0f, 1.0f);
	glVertex3f(1.0f, -1.0f, 1.0f);

	//BACK FACE
	glColor3f(0.5f, 0.0f, 1.0f);
	glVertex3f(1.0f, 1.0f, -1.0f);
	glVertex3f(-1.0f, 1.0f, -1.0f);
	glVertex3f(-1.0f, -1.0f, -1.0f);
	glVertex3f(1.0f, -1.0f, -1.0f);

	//RIGHT FACE
	glColor3f(0.0f, 1.0f, 0.5f); 
	glVertex3f(1.0f,1.0f, -1.0f);
	glVertex3f(1.0f, 1.0f, 1.0f);
	glVertex3f(1.0f, -1.0f, 1.0f);
	glVertex3f(1.0f, -1.0f, -1.0f);


	//LEFT FACE
	glColor3f(0.5f, 1.0f, 0.0f); 
	glVertex3f(-1.0f, 1.0f, 1.0f);
	glVertex3f(-1.0f, 1.0f, -1.0f);
	glVertex3f(-1.0f, -1.0f, -1.0f);
	glVertex3f(-1.0f, -1.0f, 1.0f);
	
	
	glEnd();
	fprintf(gpFile,"\nExiting drawCube()\n");

}

void drawPyramid(void)
{

	fprintf(gpFile,"\nIn drawPyramid()\n");
	glBegin(GL_TRIANGLES);

	//FRONT FACE
	glColor3f(1.0f, 0.0f,0.0f); //red
	glVertex3f(0.0f, 1.0f, 0.0f);//apex
	glColor3f(0.0f, 1.0f, 0.0f);//green
	glVertex3f(-1.0f, -1.0f, 1.0f);//left corner 
	glColor3f(0.0f, 0.0f, 1.0f);//blue
	glVertex3f(1.0f, -1.0f, 1.0f);//right corne
								  
	//RIGHT FACE
	glColor3f(1.0f, 0.0f, 0.0f); //red
	glVertex3f(0.0f, 1.0f, 0.0f);//apex
	glColor3f(0.0f, 0.0f, 1.0f);//blue
	glVertex3f(1.0f, -1.0f, 1.0f);//left corner of right face
	glColor3f(0.0f, 1.0f, 0.0f);//green
	glVertex3f(1.0f, -1.0f, -1.0f);//right corner of right face

     //BACK FACE
	glColor3f(1.0f, 0.0f, 0.0f);//red
	glVertex3f(0.0f, 1.0f, 0.0f);//apex
	glColor3f(0.0f, 1.0f, 0.0f);//green
	glVertex3f(1.0f, -1.0f, -1.0f);//left corner of back face
	glColor3f(0.0f, 0.0f, 1.0f);//blue
	glVertex3f(-1.0f, -1.0f, -1.0f);//right coner of back face

	//LEFT FACE
	glColor3f(1.0f, 0.0f, 0.0f); //red
	glVertex3f(0.0f, 1.0f, 0.0f);//apex
	glColor3f(0.0f, 0.0f, 1.0f);//blue
	glVertex3f(-1.0f, -1.0f, -1.0f);//left corner of left face 
	glColor3f(0.0f, 1.0f, 0.0f);//green
	glVertex3f(-1.0f, -1.0f, 1.0f);//right corner of left face

	glEnd();
	fprintf(gpFile,"\nExiting drawPyramid\n");

}

void resize(int width,int height)
{
	fprintf(gpFile,"\nIn resize()\n");
	if (height == 0)
		height = 1;
	glViewport(0, 0, (GLsizei)width, (GLsizei)height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(45.0f, (GLfloat)width / (GLfloat)height, 0.1f, 100.0f);
	fprintf(gpFile,"\nExiting resize()\n");
}

void uninitialize(void)
{
	fprintf(gpFile,"\nIn uninitialize()\n");
	GLXContext currentGLXContext;
	currentGLXContext=glXGetCurrentContext();

	if(currentGLXContext!=NULL && currentGLXContext==gGLXContext)
	{
		glXMakeCurrent(gpDisplay,0,0);
	}
	
	if(gGLXContext)
	{
		glXDestroyContext(gpDisplay,gGLXContext);
	}
	
	if(gWindow)
	{
		XDestroyWindow(gpDisplay,gWindow);
	}
	
	if(gColormap)
	{
		XFreeColormap(gpDisplay,gColormap);
	}
	
	if(gpXVisualInfo)
	{
		free(gpXVisualInfo);
		gpXVisualInfo=NULL;	
	}

	if(gpDisplay)
	{
		XCloseDisplay(gpDisplay);
		gpDisplay=NULL;
	}

	fprintf(gpFile,"\nExiting uninitialize()\n");
	if(gpFile)
	{
	fclose(gpFile);
	gpFile=NULL;
	}
	
}

void spin(void)
{
	fprintf(gpFile,"\nIn spin()\n");
	spinCube+=0.1f;

	if(spinCube>=360.0f)
	{
	spinCube=0.0f;
	}

	spinPyramid+=0.1f;
	if(spinPyramid>=360.0f)
	{
	spinPyramid=0.0f;
	}
	fprintf(gpFile,"\nExiting spin()\n");

}
