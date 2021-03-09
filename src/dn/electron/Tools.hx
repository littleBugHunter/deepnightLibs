package dn.electron;

#if !electron
#error "HaxeLib \"electron\" is required";
#end

import electron.main.IpcMain;
import electron.renderer.IpcRenderer;
import electron.main.App;

import js.Node.__dirname;
import js.Node.process;


typedef SubMenuItem = {
	var label : String;
	var click : Void->Void;
	var ?accelerator : String;
}


class Tools {
	static var mainWindow : electron.main.BrowserWindow;

	/**
		This MUST be called after the creation of the BrowserWindow instance in "Main" process.
	**/
	public static function initMain(win:electron.main.BrowserWindow) {
		mainWindow = win;

		// Invoke()/handle()
		IpcMain.handle("exitApp", exitApp);
		IpcMain.handle("reloadWindow", reloadWindow);
		IpcMain.handle("setFullScreen", (ev,flag)->setFullScreen(flag));
		IpcMain.handle("setWindowTitle", (ev,str)->setWindowTitle(str));
		IpcMain.handle("fatalError", (ev,str)->fatalError(str));

		// SendSync()/on()
		IpcMain.on("getScreenWidth", ev->ev.returnValue = getScreenWidth());
		IpcMain.on("getScreenHeight", ev->ev.returnValue = getScreenHeight());
		IpcMain.on("getRawArgs", ev->ev.returnValue = getRawArgs());
		IpcMain.on("getAppResourceDir", ev->ev.returnValue = getAppResourceDir());
		IpcMain.on("getExeDir", ev->ev.returnValue = getExeDir());
		IpcMain.on("getUserDataDir", ev->ev.returnValue = getUserDataDir());
		IpcMain.on("isFullScreen", ev->ev.returnValue = isFullScreen());
	}

	/** Return TRUE in electron "renderer" process **/
	public static inline function isRenderer() {
		return electron.main.App==null;
	}


	/** Close app **/
	public static function exitApp()
		isRenderer() ? IpcRenderer.invoke("exitApp") : App.exit();

	/** Reload current window **/
	public static function reloadWindow()
		isRenderer() ? IpcRenderer.invoke("reloadWindow") : mainWindow.reload();

	/** Set fullscreen mode **/
	public static function setFullScreen(full:Bool)
		isRenderer() ? IpcRenderer.invoke("setFullScreen",full) : mainWindow.setFullScreen(full);

	/** Change window title **/
	public static function setWindowTitle(str:String)
		isRenderer() ? IpcRenderer.invoke("setWindowTitle",str) : mainWindow.setTitle(str);

	/** Return fullscreen mode **/
	public static function isFullScreen() : Bool
		return isRenderer() ? IpcRenderer.sendSync("isFullScreen") : mainWindow.isFullScreen();

	/** Get primary display width in pixels **/
	public static function getScreenWidth() : Float
		return isRenderer()
			? IpcRenderer.sendSync("getScreenWidth")
			: electron.main.Screen.getPrimaryDisplay().size.width;

	/** Get primary display height in pixels **/
	public static function getScreenHeight() : Float
		return isRenderer()
			? IpcRenderer.sendSync("getScreenHeight")
			: electron.main.Screen.getPrimaryDisplay().size.height;

	/** Get the root of the app resources (where `package.json` is) **/
	public static function getAppResourceDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getAppResourceDir") : App.getAppPath();

	/** Get the path to the app EXE (Electron itself in debug, or the app executable in packaged versions) **/
	public static function getExeDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getExeDir") : App.getPath("exe");

	/** Get OS user data folder **/
	public static function getUserDataDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getUserDataDir") : App.getPath("userData");

	/** Get args as an array of Strings **/
	public static function getRawArgs() : Array<String> {
		return isRenderer()
			? try electron.renderer.IpcRenderer.sendSync("getRawArgs") catch(_) []
			: process.argv;
	}

	/** Get typed args **/
	public static function getArgs() : dn.Args {
		var raw : Array<String> = getRawArgs();
		raw.shift();
		return new dn.Args( raw.join(" ") );
	}

	/** Get zoom factor need to fit provided width/height **/
	public static function getZoomToFit(targetWid:Float, targetHei:Float) : Float {
		return dn.M.fmax(0, dn.M.fmin( getScreenWidth()/targetWid, getScreenHeight()/targetHei) );
	}


	/** Stop with an error message then close **/
	public static function fatalError(err:String) {
		if( isRenderer() )
			IpcRenderer.invoke("fatalError", err);
		else {
			electron.main.Dialog.showErrorBox("Fatal error", err);
			App.quit();
		}
	}



	/* ELECTRON MAIN ONLY ************************************************/

	/** Clear current window menu **/
	public static function m_clearMenu() {
		mainWindow.setMenu(null);
	}

	/** Replace current window menu with a debug menu **/
	public static function m_createDebugMenu(?items:Array<SubMenuItem>) : electron.main.Menu {
		if( items==null )
			items = [];

		// Base
		var menu = electron.main.Menu.buildFromTemplate([{
			label: "Debug tools",
			submenu: cast [
				{
					label: "Reload",
					click: reloadWindow,
					accelerator: "CmdOrCtrl+R",
				},
				{
					label: "Dev tools",
					click: function() mainWindow.webContents.toggleDevTools(),
					accelerator: "CmdOrCtrl+Shift+I",
				},
				{
					label: "Toggle full screen",
					click: function() setFullScreen( !isFullScreen() ),
					accelerator: "Alt+Enter",
				},
				{
					label: "Exit",
					click: exitApp,
					accelerator: "CmdOrCtrl+Q",
				},
			].concat(items)
		}]);

		mainWindow.setMenu(menu);

		return menu;
	}
}