#include <windows.h>
#include <stdio.h> // for FILE I/O

#include <gl\glew.h> // for GLSL extensions IMPORTANT : This Line Should Be Before #include<gl\gl.h> And #include<gl\glu.h>

#include <gl/GL.h>

#include "vmath.h"

#include "Sphere.h"

#pragma comment(lib,"glew32.lib")
#pragma comment(lib,"opengl32.lib")
#pragma comment(lib,"Sphere.lib")

#define WIN_WIDTH 800
#define WIN_HEIGHT 600

using namespace vmath;

enum
{
	ARD_ATTRIBUTE_POSITION = 0,
	ARD_ATTRIBUTE_COLOR,
	ARD_ATTRIBUTE_NORMAL,
	ARD_ATTRIBUTE_TEXTURE0,
};

float sphere_vertices[1146];
float sphere_normals[1146];
float sphere_textures[764];
unsigned short sphere_elements[2280];

//Prototype Of WndProc() declared Globally
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

//Global variable declarations
FILE *gpFile = NULL;

HWND ghwnd = NULL;
HDC ghdc = NULL;
HGLRC ghrc = NULL;

DWORD dwStyle;
WINDOWPLACEMENT wpPrev = { sizeof(WINDOWPLACEMENT) };

bool gbActiveWindow = false;
bool gbEscapeKeyIsPressed = false;
bool gbFullscreen = false;

GLuint gVertexShaderObjectPhongFragment;
GLuint gFragmentShaderObjectPhongFragment;

GLuint gVertexShaderObjectPhongVertex;
GLuint gFragmentShaderObjectPhongVertex;

GLuint gShaderProgramObjectPhongVertex;
GLuint gShaderProgramObjectPhongFragment;

GLuint gVao_sphere;

GLuint gVbo_sphere_position;
GLuint gVbo_sphere_normal;
GLuint gVbo_sphere_element;

GLuint gNumVertices;
GLuint gNumElements;

GLuint gModelMatrixUniform, gViewMatrixUniform, gProjectionMatrixUniform;

GLuint gLdUniform;
GLuint gLaUniform;
GLuint gLsUniform;

GLuint gKaUniform;
GLuint gKdUniform;
GLuint gKsUniform;
GLuint gmaterial_shininess_uniform;

GLuint glight_position_uniform;

GLuint gLKeyPressedUniform;

mat4 gPerspectiveProjectionMatrix;

bool gbLight;

bool gbPerVertex = true;
bool gbPerFragment = false;

GLfloat lightAmbient[] = { 0.0f, 0.0f, 0.0f, 1.0f };
GLfloat lightDiffuse[] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat lightSpecular[] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat lightPosition[] = { 100.0f, 100.0f, 100.0f, 1.0f };

GLfloat material_ambient[] = { 0.0f, 0.0f, 0.0f, 1.0f };
GLfloat material_diffuse[] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat material_specular[] = { 1.0f, 1.0f, 1.0f, 1.0f };
GLfloat material_shininess = 50.0f;
//main()
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszCmdLine, int iCmdShow)
{
	//function prototype
	void initialize(void);
	void uninitialize(void);
	void display(void);
	void spin(void);

	//variable declaration
	WNDCLASSEX wndclass;
	HWND hwnd;
	MSG msg;
	TCHAR szClassName[] = TEXT("OpenGLPP");
	bool bDone = false;

	//code
	// create log file
	if (fopen_s(&gpFile, "Log.txt", "w") != 0)
	{
		MessageBox(NULL, TEXT("Log File Can Not Be Created\nExitting ..."), TEXT("Error"), MB_OK | MB_TOPMOST | MB_ICONSTOP);
		exit(0);
	}
	else
	{
		fprintf(gpFile, "Log File Is Successfully Opened.\n");
	}

	//initializing members of struct WNDCLASSEX
	wndclass.cbSize = sizeof(WNDCLASSEX);
	wndclass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
	wndclass.cbClsExtra = 0;
	wndclass.cbWndExtra = 0;
	wndclass.hInstance = hInstance;
	wndclass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
	wndclass.hIcon = LoadIcon(NULL, IDI_APPLICATION);
	wndclass.hCursor = LoadCursor(NULL, IDC_ARROW);
	wndclass.hIconSm = LoadIcon(NULL, IDI_APPLICATION);
	wndclass.lpfnWndProc = WndProc;
	wndclass.lpszClassName = szClassName;
	wndclass.lpszMenuName = NULL;
	//Registering Class
	RegisterClassEx(&wndclass);

	int x = GetSystemMetrics(SM_CXSCREEN);
	int y = GetSystemMetrics(SM_CYSCREEN);

	//Create Window
	//Parallel to glutInitWindowSize(), glutInitWindowPosition() and glutCreateWindow() all three together
	hwnd = CreateWindow(szClassName,
		TEXT("OpenGL Programmable Pipeline Window : Phong Lighting(PerFragment & Per Vertex)"),
		WS_OVERLAPPEDWINDOW,
		(x / 2) - (WIN_WIDTH / 2),
		(y / 2) - (WIN_HEIGHT / 2),
		WIN_WIDTH,
		WIN_HEIGHT,
		NULL,
		NULL,
		hInstance,
		NULL);

	ghwnd = hwnd;

	ShowWindow(hwnd, iCmdShow);
	SetForegroundWindow(hwnd);
	SetFocus(hwnd);

	//initialize
	initialize();

	//Message Loop
	while (bDone == false)
	{
		if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
		{
			if (msg.message == WM_QUIT)
				bDone = true;
			else
			{
				TranslateMessage(&msg);
				DispatchMessage(&msg);
			}
		}
		else
		{
			// rendring function
			display();

			if (gbActiveWindow == true)
			{
				if (gbEscapeKeyIsPressed == true) //Continuation to glutLeaveMainLoop();
					bDone = true;
			}
		}
	}

	uninitialize();

	return((int)msg.wParam);
}

//WndProc()
LRESULT CALLBACK WndProc(HWND hwnd, UINT iMsg, WPARAM wParam, LPARAM lParam)
{
	//function prototype
	void resize(int, int);
	void ToggleFullscreen(void);
	void uninitialize(void);

	//variable declarations
	//static bool bIsAKeyPressed = false;
	static bool bIsLKeyPressed = false;

	//code
	switch (iMsg)
	{
	case WM_ACTIVATE:
		if (HIWORD(wParam) == 0) //if 0, the window is active
			gbActiveWindow = true;
		else //if non-zero, the window is not active
			gbActiveWindow = false;
		break;
	case WM_ERASEBKGND:
		return(0);
	case WM_SIZE:
		resize(LOWORD(lParam), HIWORD(lParam));
		break;
	case WM_KEYDOWN:
		switch (wParam)
		{
		case VK_ESCAPE: //case 27
			if (gbFullscreen == false)
			{
				ToggleFullscreen();
				gbFullscreen = true;
			}
			else
			{
				ToggleFullscreen();
				gbFullscreen = false;
			}
			break;

		case 0x51: 
			if (gbEscapeKeyIsPressed == false)
				gbEscapeKeyIsPressed = true;
			break;

		case 0x56:
			if (gbPerVertex == false)
			{
				gbPerVertex = true;
				gbPerFragment = false;
			}
			break;

		case 0x46:
			if (gbPerFragment == false)
			{
				gbPerFragment = true;
				gbPerVertex = false;
			}
			break;

		case 0x4C:
			if (bIsLKeyPressed == false)
			{
				gbLight = true;
				bIsLKeyPressed = true;
			}
			else
			{
				gbLight = false;
				bIsLKeyPressed = false;
			}
			break;

		default:
			break;
		}
		break;
	case WM_LBUTTONDOWN:
		break;
	case WM_CLOSE:
		uninitialize();
		break;
	case WM_DESTROY:
		PostQuitMessage(0);
		break;
	default:
		break;
	}
	return(DefWindowProc(hwnd, iMsg, wParam, lParam));
}

void ToggleFullscreen(void)
{
	//variable declarations
	MONITORINFO mi;

	//code
	if (gbFullscreen == false)
	{
		dwStyle = GetWindowLong(ghwnd, GWL_STYLE);
		if (dwStyle & WS_OVERLAPPEDWINDOW)
		{
			mi = { sizeof(MONITORINFO) };
			if (GetWindowPlacement(ghwnd, &wpPrev) && GetMonitorInfo(MonitorFromWindow(ghwnd, MONITORINFOF_PRIMARY), &mi))
			{
				SetWindowLong(ghwnd, GWL_STYLE, dwStyle & ~WS_OVERLAPPEDWINDOW);
				SetWindowPos(ghwnd, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top, SWP_NOZORDER | SWP_FRAMECHANGED);
			}
		}
		ShowCursor(FALSE);
	}

	else
	{
		//code
		SetWindowLong(ghwnd, GWL_STYLE, dwStyle | WS_OVERLAPPEDWINDOW);
		SetWindowPlacement(ghwnd, &wpPrev);
		SetWindowPos(ghwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_FRAMECHANGED);

		ShowCursor(TRUE);
	}
}

//FUNCTION DEFINITIONS
void initialize(void)
{
	//MessageBox(NULL, TEXT("Error"), TEXT("In intit"), MB_OK);
	fprintf(gpFile, "Renderer : %s\n", glGetString(GL_RENDERER));
	//function prototypes
	void uninitialize(void);
	void resize(int, int);

	//variable declarations
	PIXELFORMATDESCRIPTOR pfd;
	int iPixelFormatIndex;

	//code
	ZeroMemory(&pfd, sizeof(PIXELFORMATDESCRIPTOR));

	//Initialization of structure 'PIXELFORMATDESCRIPTOR'
	//Parallel to glutInitDisplayMode()
	pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR);
	pfd.nVersion = 1;
	pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
	pfd.iPixelType = PFD_TYPE_RGBA;
	pfd.cColorBits = 32;
	pfd.cRedBits = 8;
	pfd.cGreenBits = 8;
	pfd.cBlueBits = 8;
	pfd.cAlphaBits = 8;
	pfd.cDepthBits = 32;

	ghdc = GetDC(ghwnd);

	//choose a pixel format which best matches with that of 'pfd'
	iPixelFormatIndex = ChoosePixelFormat(ghdc, &pfd);
	if (iPixelFormatIndex == 0)
	{
		ReleaseDC(ghwnd, ghdc);
		ghdc = NULL;
	}

	//set the pixel format chosen above
	if (SetPixelFormat(ghdc, iPixelFormatIndex, &pfd) == false)
	{
		ReleaseDC(ghwnd, ghdc);
		ghdc = NULL;
	}

	//create OpenGL rendering context
	ghrc = wglCreateContext(ghdc);
	if (ghrc == NULL)
	{
		ReleaseDC(ghwnd, ghdc);
		ghdc = NULL;
	}

	//make the rendering context created above as current n the current hdc
	if (wglMakeCurrent(ghdc, ghrc) == false)
	{
		wglDeleteContext(ghrc);
		ghrc = NULL;
		ReleaseDC(ghwnd, ghdc);
		ghdc = NULL;
	}

	// GLEW Initialization Code For GLSL ( IMPORTANT : It Must Be Here. Means After Creating OpenGL Context But Before Using Any OpenGL Function )
	GLenum glew_error = glewInit();
	if (glew_error != GLEW_OK)
	{
		wglDeleteContext(ghrc);
		ghrc = NULL;
		ReleaseDC(ghwnd, ghdc);
		ghdc = NULL;
	}

	gVertexShaderObjectPhongVertex = glCreateShader(GL_VERTEX_SHADER);

	// provide source code to shader
	const GLchar *vertexShaderSourceCodePerVertex =
		"#version 450 core" \
		"\n" \
		"in vec4 vPosition;" \
		"in vec3 vNormal;" \
		"uniform mat4 u_model_matrix;" \
		"uniform mat4 u_view_matrix;" \
		"uniform mat4 u_projection_matrix;" \
		"uniform int u_lighting_enabled;" \
		"uniform vec3 u_La;" \
		"uniform vec3 u_Ka;" \
		"uniform vec3 u_Ld;" \
		"uniform vec3 u_Kd;" \
		"uniform vec3 u_Ls;" \
		"uniform vec3 u_Ks;" \
		"uniform vec4 u_light_position;" \
		"uniform float u_material_shininess;" \
		"out vec3 phong_ads_color;;" \
		"void main(void)" \
		"{" \
		"if(u_lighting_enabled == 1)" \
		"{" \
		"vec4 eyeCoordinates = u_view_matrix * u_model_matrix * vPosition;" \
		"vec3 transformed_normals = normalize(mat3(u_view_matrix * u_model_matrix) * vNormal);" \
		"vec3 light_direction = normalize(vec3(u_light_position) - eyeCoordinates.xyz);" \
		"float tn_dot_ld = max(dot(transformed_normals, light_direction), 0.0);" \
		"vec3 ambient = u_La * u_Ka;" \
		"vec3 diffuse = u_Ld * u_Kd * tn_dot_ld;" \
		"vec3 reflection_vector = reflect(-light_direction, transformed_normals);" \
		"vec3 viewer_vector = normalize(-eyeCoordinates.xyz);"
		"vec3 specular = u_Ls * u_Ks * pow(max(dot(reflection_vector, viewer_vector), 0.0), u_material_shininess);" \
		"phong_ads_color = ambient + diffuse + specular;" \
		"}" \
		"else" \
		"{" \
		"phong_ads_color = vec3(1.0, 1.0, 1.0);" \
		"}" \
		"gl_Position = u_projection_matrix * u_view_matrix * u_model_matrix * vPosition;" \
		"}";
	glShaderSource(gVertexShaderObjectPhongVertex, 1, (const GLchar **)&vertexShaderSourceCodePerVertex, NULL);

	// compile shader
	glCompileShader(gVertexShaderObjectPhongVertex);
	GLint iInfoLogLength = 0;
	GLint iShaderCompiledStatus = 0;
	char *szInfoLog = NULL;
	glGetShaderiv(gVertexShaderObjectPhongVertex, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(gVertexShaderObjectPhongVertex, GL_INFO_LOG_LENGTH, &iInfoLogLength);
		if (iInfoLogLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLogLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetShaderInfoLog(gVertexShaderObjectPhongVertex, iInfoLogLength, &written, szInfoLog);
				fprintf(gpFile, "Vertex Shader Compilation Log : %s\n", szInfoLog);
				free(szInfoLog);
				uninitialize();
				exit(0);
			}
		}
	}

	// *** FRAGMENT SHADER ***
	// create shader
	gFragmentShaderObjectPhongVertex = glCreateShader(GL_FRAGMENT_SHADER);

	// provide source code to shader
	const GLchar *fragmentShaderSourceCodePerVertex =
		"#version 450 core" \
		"\n" \
		"in vec3 phong_ads_color;" \
		"out vec4 FragColor;" \
		"uniform int u_lighting_enabled;" \
		"void main(void)" \
		"{" \
		"if(u_lighting_enabled == 1)" \
		"{" \
		"FragColor = vec4(phong_ads_color, 1.0);" \
		"}" \
		"else" \
		"{" \
		"FragColor = vec4(1.0,1.0,1.0,1.0);" \
		"}" \
		"}";
	glShaderSource(gFragmentShaderObjectPhongVertex, 1, (const GLchar **)&fragmentShaderSourceCodePerVertex, NULL);

	// compile shader
	glCompileShader(gFragmentShaderObjectPhongVertex);
	glGetShaderiv(gFragmentShaderObjectPhongVertex, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(gFragmentShaderObjectPhongVertex, GL_INFO_LOG_LENGTH, &iInfoLogLength);
		if (iInfoLogLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLogLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetShaderInfoLog(gFragmentShaderObjectPhongVertex, iInfoLogLength, &written, szInfoLog);
				fprintf(gpFile, "Fragment Shader Compilation Log : %s\n", szInfoLog);
				free(szInfoLog);
				uninitialize();
				exit(0);
			}
		}
	}

	// *** SHADER PROGRAM ***
	// create
	gShaderProgramObjectPhongVertex = glCreateProgram();

	// attach vertex shader to shader program
	glAttachShader(gShaderProgramObjectPhongVertex, gVertexShaderObjectPhongVertex);

	// attach fragment shader to shader program
	glAttachShader(gShaderProgramObjectPhongVertex, gFragmentShaderObjectPhongVertex);

	// pre-link binding of shader program object with vertex shader position attribute
	glBindAttribLocation(gShaderProgramObjectPhongVertex, ARD_ATTRIBUTE_POSITION, "vPosition");
	glBindAttribLocation(gShaderProgramObjectPhongVertex, ARD_ATTRIBUTE_NORMAL, "vNormal");

	// link shader
	glLinkProgram(gShaderProgramObjectPhongVertex);
	GLint iShaderProgramLinkStatus = 0;
	glGetProgramiv(gShaderProgramObjectPhongVertex, GL_LINK_STATUS, &iShaderProgramLinkStatus);
	if (iShaderProgramLinkStatus == GL_FALSE)
	{
		glGetProgramiv(gShaderProgramObjectPhongVertex, GL_INFO_LOG_LENGTH, &iInfoLogLength);
		if (iInfoLogLength>0)
		{
			szInfoLog = (char *)malloc(iInfoLogLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetProgramInfoLog(gShaderProgramObjectPhongVertex, iInfoLogLength, &written, szInfoLog);
				fprintf(gpFile, "Shader Program Link Log : %s\n", szInfoLog);
				free(szInfoLog);
				uninitialize();
				exit(0);
			}
		}
	}


	//Fragment Shader//

	// *** VERTEX SHADER ***
	// create shader
	gVertexShaderObjectPhongFragment = glCreateShader(GL_VERTEX_SHADER);

	// provide source code to shader
	const GLchar *vertexShaderSourceCode =
		"#version 450 core" \
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
	glShaderSource(gVertexShaderObjectPhongFragment, 1, (const GLchar **)&vertexShaderSourceCode, NULL);

	// compile shader
	glCompileShader(gVertexShaderObjectPhongFragment);
	iInfoLogLength = 0;
	iShaderCompiledStatus = 0;
	szInfoLog = NULL;
	glGetShaderiv(gVertexShaderObjectPhongFragment, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(gVertexShaderObjectPhongFragment, GL_INFO_LOG_LENGTH, &iInfoLogLength);
		if (iInfoLogLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLogLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetShaderInfoLog(gVertexShaderObjectPhongFragment, iInfoLogLength, &written, szInfoLog);
				fprintf(gpFile, "Vertex Shader Compilation Log : %s\n", szInfoLog);
				free(szInfoLog);
				uninitialize();
				exit(0);
			}
		}
	}

	// *** FRAGMENT SHADER ***
	// create shader
	gFragmentShaderObjectPhongFragment = glCreateShader(GL_FRAGMENT_SHADER);

	// provide source code to shader
	const GLchar *fragmentShaderSourceCode =
		"#version 450 core" \
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
		"vec3 normalized_viewer_vector = normalize(viewer_vector);" \
		"vec3 ambient = u_La * u_Ka;" \
		"float tn_dot_ld = max(dot(normalized_transformed_normals, normalized_light_direction), 0.0);" \
		"vec3 diffuse = u_Ld * u_Kd * tn_dot_ld;" \
		"vec3 reflection_vector = reflect(-normalized_light_direction, normalized_transformed_normals);" \
		"vec3 specular = u_Ls * u_Ks * pow(max(dot(reflection_vector, normalized_viewer_vector), 0.0), u_material_shininess);" \
		"phong_ads_color = ambient + diffuse + specular;" \
		"}"
		"else" \
		"{" \
		"phong_ads_color = vec3(1.0, 1.0, 1.0);" \
		"}"\
		"FragColor = vec4(phong_ads_color, 1.0);" \
		"}";
	glShaderSource(gFragmentShaderObjectPhongFragment, 1, (const GLchar **)&fragmentShaderSourceCode, NULL);

	// compile shader
	glCompileShader(gFragmentShaderObjectPhongFragment);
	glGetShaderiv(gFragmentShaderObjectPhongFragment, GL_COMPILE_STATUS, &iShaderCompiledStatus);
	if (iShaderCompiledStatus == GL_FALSE)
	{
		glGetShaderiv(gFragmentShaderObjectPhongFragment, GL_INFO_LOG_LENGTH, &iInfoLogLength);
		if (iInfoLogLength > 0)
		{
			szInfoLog = (char *)malloc(iInfoLogLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetShaderInfoLog(gFragmentShaderObjectPhongFragment, iInfoLogLength, &written, szInfoLog);
				fprintf(gpFile, "Fragment Shader Compilation Log : %s\n", szInfoLog);
				free(szInfoLog);
				uninitialize();
				exit(0);
			}
		}
	}



	// *** SHADER PROGRAM ***
	// create
	gShaderProgramObjectPhongFragment = glCreateProgram();

	// attach vertex shader to shader program
	glAttachShader(gShaderProgramObjectPhongFragment, gVertexShaderObjectPhongFragment);

	// attach fragment shader to shader program
	glAttachShader(gShaderProgramObjectPhongFragment, gFragmentShaderObjectPhongFragment);

	// pre-link binding of shader program object with vertex shader position attribute
	//glBindAttribLocation(gShaderProgramObjectPhongVertex, ARD_ATTRIBUTE_POSITION, "vPosition");
	//glBindAttribLocation(gShaderProgramObjectPhongVertex, ARD_ATTRIBUTE_NORMAL, "vNormal");

	glBindAttribLocation(gShaderProgramObjectPhongFragment, ARD_ATTRIBUTE_POSITION, "vPosition");
	glBindAttribLocation(gShaderProgramObjectPhongFragment, ARD_ATTRIBUTE_NORMAL, "vNormal");

	// link shader
	glLinkProgram(gShaderProgramObjectPhongFragment);
	iShaderProgramLinkStatus = 0;
	glGetProgramiv(gShaderProgramObjectPhongFragment, GL_LINK_STATUS, &iShaderProgramLinkStatus);
	if (iShaderProgramLinkStatus == GL_FALSE)
	{
		glGetProgramiv(gShaderProgramObjectPhongFragment, GL_INFO_LOG_LENGTH, &iInfoLogLength);
		if (iInfoLogLength>0)
		{
			szInfoLog = (char *)malloc(iInfoLogLength);
			if (szInfoLog != NULL)
			{
				GLsizei written;
				glGetProgramInfoLog(gShaderProgramObjectPhongFragment, iInfoLogLength, &written, szInfoLog);
				fprintf(gpFile, "Shader Program Link Log : %s\n", szInfoLog);
				free(szInfoLog);
				uninitialize();
				exit(0);
			}
		}
	}


	gModelMatrixUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_model_matrix");
	gViewMatrixUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_view_matrix");
	gProjectionMatrixUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_projection_matrix");

	gLKeyPressedUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_lighting_enabled");


	gLaUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_La");
	gKaUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_Ka");

	gLdUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_Ld");
	gKdUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_Kd");

	gLsUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_Ls");
	gKsUniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_Ks");

	glight_position_uniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_light_position");

	gmaterial_shininess_uniform = glGetUniformLocation(gShaderProgramObjectPhongVertex, "u_material_shininess");


	gModelMatrixUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_model_matrix");
	gViewMatrixUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_view_matrix");
	gProjectionMatrixUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_projection_matrix");

	gLKeyPressedUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_lighting_enabled");


	gLaUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_La");
	gKaUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_Ka");

	gLdUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_Ld");
	gKdUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_Kd");

	gLsUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_Ls");
	gKsUniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_Ks");

	glight_position_uniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_light_position");

	gmaterial_shininess_uniform = glGetUniformLocation(gShaderProgramObjectPhongFragment, "u_material_shininess");


	getSphereVertexData(sphere_vertices, sphere_normals, sphere_textures, sphere_elements);
	gNumVertices = getNumberOfSphereVertices();
	gNumElements = getNumberOfSphereElements();

	// vao
	glGenVertexArrays(1, &gVao_sphere);
	glBindVertexArray(gVao_sphere);

	// position vbo
	glGenBuffers(1, &gVbo_sphere_position);
	glBindBuffer(GL_ARRAY_BUFFER, gVbo_sphere_position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(sphere_vertices), sphere_vertices, GL_STATIC_DRAW);

	glVertexAttribPointer(ARD_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(ARD_ATTRIBUTE_POSITION);

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	// normal vbo
	glGenBuffers(1, &gVbo_sphere_normal);
	glBindBuffer(GL_ARRAY_BUFFER, gVbo_sphere_normal);
	glBufferData(GL_ARRAY_BUFFER, sizeof(sphere_normals), sphere_normals, GL_STATIC_DRAW);

	glVertexAttribPointer(ARD_ATTRIBUTE_NORMAL, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(ARD_ATTRIBUTE_NORMAL);

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	// element vbo
	glGenBuffers(1, &gVbo_sphere_element);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(sphere_elements), sphere_elements, GL_STATIC_DRAW);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	// unbind vao
	glBindVertexArray(0);

	//MessageBox(NULL, TEXT("After Sqaure final"), TEXT("In Init"), MB_OK);

	//glShadeModel(GL_SMOOTH);
	// set-up depth buffer
	glClearDepth(1.0f);
	// enable depth testing
	glEnable(GL_DEPTH_TEST);
	// depth test to do
	glDepthFunc(GL_LEQUAL);
	// We will always cull back faces for better performance
	//glEnable(GL_CULL_FACE);

	// set background color to which it will display even if it will empty. THIS LINE CAN BE IN drawRect().
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f); // black

	gPerspectiveProjectionMatrix = mat4::identity();

	gbLight = false;
	// resize
	resize(WIN_WIDTH, WIN_HEIGHT);
}

void display(void)
{
	//code
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

/*	if (gbPerFragment == true)
	{
		// start using OpenGL program object
		glUseProgram(gShaderProgramObjectPhongFragment);
	
		if (gbLight == true)
		{
			glUniform1i(gLKeyPressedUniform, 1);

			glUniform3fv(gLaUniform, 1, lightAmbient);
			glUniform3fv(gKaUniform, 1, material_ambient);

			glUniform3fv(gLdUniform, 1, lightDiffuse);
			glUniform3fv(gKdUniform, 1, material_diffuse);

			glUniform3fv(gLsUniform, 1, lightSpecular);
			glUniform3fv(gKsUniform, 1, material_specular);

			glUniform1f(gmaterial_shininess_uniform, material_shininess);

			//float lightPosition[] = { 0.0f, 0.0f, 2.0f, 1.0f };
			glUniform4fv(glight_position_uniform, 1, (GLfloat *)lightPosition);
		}

		else
		{
			glUniform1i(gLKeyPressedUniform, 0);
		}

		mat4 modelMatrix = mat4::identity();
		mat4 viewMatrix = mat4::identity();

		modelMatrix = translate(0.0f, 0.0f, -2.0f);

		glUniformMatrix4fv(gModelMatrixUniform, 1, GL_FALSE, modelMatrix);
		glUniformMatrix4fv(gViewMatrixUniform, 1, GL_FALSE, viewMatrix);

		glUniformMatrix4fv(gProjectionMatrixUniform, 1, GL_FALSE, gPerspectiveProjectionMatrix);

		glBindVertexArray(gVao_sphere);

		// *** draw, either by glDrawTriangles() or glDrawArrays() or glDrawElements()
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
		glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);

		// *** unbind vao ***
		glBindVertexArray(0);

		// stop using OpenGL program object
		glUseProgram(0);

	}

	if (gbPerVertex == true)
	{
		glUseProgram(gShaderProgramObjectPhongVertex);

		if (gbLight == true)
		{
			glUniform1i(gLKeyPressedUniform, 1);

			glUniform3fv(gLaUniform, 1, lightAmbient);
			glUniform3fv(gKaUniform, 1, material_ambient);

			glUniform3fv(gLdUniform, 1, lightDiffuse);
			glUniform3fv(gKdUniform, 1, material_diffuse);

			glUniform3fv(gLsUniform, 1, lightSpecular);
			glUniform3fv(gKsUniform, 1, material_specular);

			glUniform1f(gmaterial_shininess_uniform, material_shininess);

			//float lightPosition[] = { 0.0f, 0.0f, 2.0f, 1.0f };
			glUniform4fv(glight_position_uniform, 1, (GLfloat *)lightPosition);
		}

		else
		{
			glUniform1i(gLKeyPressedUniform, 0);
		}

		mat4 modelMatrix = mat4::identity();
		mat4 viewMatrix = mat4::identity();

		modelMatrix = translate(0.0f, 0.0f, -2.0f);

		glUniformMatrix4fv(gModelMatrixUniform, 1, GL_FALSE, modelMatrix);
		glUniformMatrix4fv(gViewMatrixUniform, 1, GL_FALSE, viewMatrix);

		glUniformMatrix4fv(gProjectionMatrixUniform, 1, GL_FALSE, gPerspectiveProjectionMatrix);

		glBindVertexArray(gVao_sphere);

		// *** draw, either by glDrawTriangles() or glDrawArrays() or glDrawElements()
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
		glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);

		// *** unbind vao ***
		glBindVertexArray(0);

		// stop using OpenGL program object
		glUseProgram(0);

	}*/

	if (gbPerVertex == true)
	{
		glUseProgram(gShaderProgramObjectPhongVertex);

	}

	else
	{
		glUseProgram(gShaderProgramObjectPhongFragment);
	}

	if (gbLight == true)
	{
		glUniform1i(gLKeyPressedUniform, 1);

		glUniform3fv(gLaUniform, 1, lightAmbient);
		glUniform3fv(gKaUniform, 1, material_ambient);

		glUniform3fv(gLdUniform, 1, lightDiffuse);
		glUniform3fv(gKdUniform, 1, material_diffuse);

		glUniform3fv(gLsUniform, 1, lightSpecular);
		glUniform3fv(gKsUniform, 1, material_specular);

		glUniform1f(gmaterial_shininess_uniform, material_shininess);

		//float lightPosition[] = { 0.0f, 0.0f, 2.0f, 1.0f };
		glUniform4fv(glight_position_uniform, 1, (GLfloat *)lightPosition);
	}

	else
	{
		glUniform1i(gLKeyPressedUniform, 0);
	}

	mat4 modelMatrix = mat4::identity();
	mat4 viewMatrix = mat4::identity();

	modelMatrix = translate(0.0f, 0.0f, -2.0f);

	glUniformMatrix4fv(gModelMatrixUniform, 1, GL_FALSE, modelMatrix);
	glUniformMatrix4fv(gViewMatrixUniform, 1, GL_FALSE, viewMatrix);

	glUniformMatrix4fv(gProjectionMatrixUniform, 1, GL_FALSE, gPerspectiveProjectionMatrix);

	glBindVertexArray(gVao_sphere);

	// *** draw, either by glDrawTriangles() or glDrawArrays() or glDrawElements()
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
	glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);

	// *** unbind vao ***
	glBindVertexArray(0);

	// stop using OpenGL program object
	glUseProgram(0);

	SwapBuffers(ghdc);
}

void resize(int width, int height)
{
	//code
	if (height == 0)
		height = 1;
	glViewport(0, 0, (GLsizei)width, (GLsizei)height);
	gPerspectiveProjectionMatrix = vmath::perspective(45.0f, (GLfloat)width / (GLfloat)height, 0.1f, 100.0f);
}

void uninitialize(void)
{
	//UNINITIALIZATION CODE
	if (gbFullscreen == true)
	{
		dwStyle = GetWindowLong(ghwnd, GWL_STYLE);
		SetWindowLong(ghwnd, GWL_STYLE, dwStyle | WS_OVERLAPPEDWINDOW);
		SetWindowPlacement(ghwnd, &wpPrev);
		SetWindowPos(ghwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_FRAMECHANGED);

		ShowCursor(TRUE);

	}

	if (gVao_sphere)
	{
		glDeleteVertexArrays(1, &gVao_sphere);
		gVao_sphere = 0;
	}

	// destroy vbo
	if (gVbo_sphere_element)
	{
		glDeleteBuffers(1, &gVbo_sphere_element);
		gVbo_sphere_element = 0;
	}

	if (gVbo_sphere_normal)
	{
		glDeleteBuffers(1, &gVbo_sphere_normal);
		gVbo_sphere_normal = 0;
	}

	if (gVbo_sphere_position)
	{
		glDeleteBuffers(1, &gVbo_sphere_position);
		gVbo_sphere_position = 0;
	}

	// detach vertex shader from shader program object
	glDetachShader(gShaderProgramObjectPhongFragment, gVertexShaderObjectPhongFragment);
	// detach fragment  shader from shader program object
	glDetachShader(gShaderProgramObjectPhongFragment, gFragmentShaderObjectPhongFragment);

	glDetachShader(gShaderProgramObjectPhongVertex, gVertexShaderObjectPhongVertex);
	// detach fragment  shader from shader program object
	glDetachShader(gShaderProgramObjectPhongVertex, gFragmentShaderObjectPhongVertex);

	// delete vertex shader object
	glDeleteShader(gVertexShaderObjectPhongFragment);
	gVertexShaderObjectPhongFragment = 0;
	// delete fragment shader object
	glDeleteShader(gFragmentShaderObjectPhongFragment);
	gFragmentShaderObjectPhongFragment = 0;

	// delete shader program object
	glDeleteProgram(gShaderProgramObjectPhongFragment);
	gShaderProgramObjectPhongFragment = 0;

	glDeleteShader(gVertexShaderObjectPhongVertex);
	gVertexShaderObjectPhongVertex = 0;
	// delete fragment shader object
	glDeleteShader(gFragmentShaderObjectPhongVertex);
	gFragmentShaderObjectPhongVertex = 0;

	// delete shader program object
	glDeleteProgram(gShaderProgramObjectPhongVertex);
	gShaderProgramObjectPhongVertex = 0;

	// unlink shader program
	//glUseProgram(0);

	//Deselect the rendering context
	wglMakeCurrent(NULL, NULL);

	//Delete the rendering context
	wglDeleteContext(ghrc);
	ghrc = NULL;

	//Delete the device context
	ReleaseDC(ghwnd, ghdc);
	ghdc = NULL;

	if (gpFile)
	{
		fprintf(gpFile, "Log File Is Successfully Closed.\n");
		fclose(gpFile);
		gpFile = NULL;
	}
}


