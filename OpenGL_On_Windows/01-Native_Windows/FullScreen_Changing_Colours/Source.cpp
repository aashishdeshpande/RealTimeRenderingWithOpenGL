
#include<windows.h>

// global function declarations
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
DWORD dwStyle;
bool gbFullscreen=false;
HWND hwnd;
int giPaintFlag = -1;

WINDOWPLACEMENT wpPrev = { sizeof(WINDOWPLACEMENT) };
// WinMain()
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszCmdLine, int nCmdShow)
{
	// variable declarations
	WNDCLASSEX wndclass;
	
	MSG msg;
	TCHAR szAppName[] = TEXT("MyApp");

	
	
	wndclass.cbSize = sizeof(WNDCLASSEX);
	wndclass.style = CS_HREDRAW | CS_VREDRAW;
	wndclass.cbClsExtra = 0;
	wndclass.cbWndExtra = 0;
	wndclass.lpfnWndProc = WndProc;
	wndclass.hInstance = hInstance;
	wndclass.hIcon = LoadIcon(NULL, IDI_APPLICATION);
	wndclass.hCursor = LoadCursor(NULL, IDC_ARROW);
	wndclass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
	wndclass.lpszClassName = szAppName;
	wndclass.lpszMenuName = NULL;
	wndclass.hIconSm = LoadIcon(NULL, IDI_APPLICATION);

	// register above class
	RegisterClassEx(&wndclass);
	int width = 800;
	int height = 600;
	int x = GetSystemMetrics(SM_CXSCREEN);
	int y = GetSystemMetrics(SM_CYSCREEN);
	
	hwnd = CreateWindow(szAppName,
		TEXT("My Application"),
		WS_OVERLAPPEDWINDOW,
		(x/2)-(width/2),
		(y/2)-(height/2),//CW_USEDEFAULT,
		//CW_USEDEFAULT,
		width,//CW_USEDEFAULT,
		height,//CW_USEDEFAULT,
		NULL,
		NULL,
		hInstance,
		NULL);

	ShowWindow(hwnd, nCmdShow);
	UpdateWindow(hwnd);

	
	while (GetMessage(&msg, NULL, 0, 0))
	{
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	return((int)msg.wParam);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT iMsg, WPARAM wParam, LPARAM lParam)
{
	void ToggleFullscreen(void);
	
	
	switch (iMsg)
	{

	case WM_CREATE:

		MessageBox(hwnd, TEXT("str"), TEXT("Hello!"), MB_OK);
		break;

	case WM_LBUTTONDOWN:
		MessageBox(hwnd, TEXT("L"), TEXT("B"), MB_OK);

		break;

	case WM_KEYDOWN:
		switch (LOWORD(wParam))
		{
		case VK_ESCAPE:
			MessageBox(hwnd, TEXT("ES"), TEXT("ESCAPE_KEY"), MB_OK);
			break;

		case 0X41:
			MessageBox(hwnd, TEXT("A"), TEXT("KEY_A"), MB_OK);
			break;

		/*case 0x42:
			MessageBox(hwnd, TEXT("B"), TEXT("KEY_B"), MB_OK);
			break;*/

		case 0x42:
			giPaintFlag = 2;
			InvalidateRect(hwnd, NULL, TRUE);
             break;


		case 0x43:
			giPaintFlag = 3;
			InvalidateRect(hwnd, NULL, TRUE);
			break;

		case 0x46:
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

		case 0X47:

			giPaintFlag = 4;
			InvalidateRect(hwnd, NULL, TRUE);
			//MessageBox(hwnd, TEXT("C"), TEXT("KEY_C"), MB_OK);
			break;


		case 0x4D:
			giPaintFlag = 5;
			InvalidateRect(hwnd, NULL, TRUE);
			break;


		case 0x52:
			giPaintFlag = 6;
			InvalidateRect(hwnd, NULL, TRUE);
			break;


		case 0x59:
			giPaintFlag = 7;
			InvalidateRect(hwnd, NULL, TRUE);
			break;

		

		
		}
         
		break;

	case WM_PAINT:

		HDC hdc;
		PAINTSTRUCT ps;
		RECT rc;
		HBRUSH hBrush;
		hdc = BeginPaint(hwnd, &ps);
		GetClientRect(hwnd, &rc);
		COLORREF color;

		if (giPaintFlag == 2)
		{
			color = RGB(0, 0, 255);
		}

		 if(giPaintFlag == 3)
		{
			
			color = RGB(0, 255, 255);
			
		}


		 if (giPaintFlag == 4)
		 {

			 color = RGB(0, 255, 0);

		 }

		 if (giPaintFlag == 5)
		 {

			 color = RGB(255, 0, 255);
		 }

		 if (giPaintFlag == 6)
		 {

			 color = RGB(255, 0, 0);
		 }

		 if (giPaintFlag == 7)
		 {
			 color = RGB(255, 255, 0);
		 }

		 hBrush = CreateSolidBrush(color);
		FillRect(hdc, &rc, hBrush);
		DeleteObject(hBrush);
		EndPaint(hwnd, &ps);
		break;


	
		

	case WM_DESTROY:
		PostQuitMessage(0);
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
		dwStyle = GetWindowLong(hwnd, GWL_STYLE);
		if (dwStyle & WS_OVERLAPPEDWINDOW)
		{
			mi = { sizeof(MONITORINFO) };
			if (GetWindowPlacement(hwnd, &wpPrev) && GetMonitorInfo(MonitorFromWindow(hwnd, MONITORINFOF_PRIMARY), &mi))
			{
				SetWindowLong(hwnd, GWL_STYLE, dwStyle & ~WS_OVERLAPPEDWINDOW);
				SetWindowPos(hwnd, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top, SWP_NOZORDER | SWP_FRAMECHANGED);
			}
		}
		ShowCursor(FALSE);
	}

	else
	{
		//code
		SetWindowLong(hwnd, GWL_STYLE, dwStyle | WS_OVERLAPPEDWINDOW);
		SetWindowPlacement(hwnd, &wpPrev);
		SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_FRAMECHANGED);

		ShowCursor(TRUE);
	}
}
