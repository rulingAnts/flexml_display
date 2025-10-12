const { app, BrowserWindow, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow;

function resolveIconPath(){
  const base = path.join(__dirname, 'assets');
  const icns = path.join(base, 'icon.icns');
  const ico = path.join(base, 'icon.ico');
  const png = path.join(base, 'icon.png');
  if(process.platform === 'darwin'){
    // BrowserWindow.icon is ignored on macOS; set the Dock icon instead
    if(fs.existsSync(icns)) return icns;
    if(fs.existsSync(png)) return png;
  } else if(process.platform === 'win32'){
    if(fs.existsSync(ico)) return ico;
    if(fs.existsSync(png)) return png;
  } else {
    // Linux prefers PNG
    if(fs.existsSync(png)) return png;
    if(fs.existsSync(ico)) return ico;
  }
  return null;
}

function createWindow() {
  // Set app/dock icon in development so we don't see the default Electron icon
  const iconPath = resolveIconPath();
  if(process.platform === 'darwin' && iconPath && app.dock && typeof app.dock.setIcon === 'function'){
    try{
      const img = nativeImage.createFromPath(iconPath);
      if(!img.isEmpty()) app.dock.setIcon(img);
    }catch(_){ /* non-fatal */ }
  }
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    icon: (process.platform === 'darwin') ? undefined : iconPath,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'docs', 'index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.on('ready', createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});