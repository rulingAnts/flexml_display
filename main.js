const { app, BrowserWindow, nativeImage, dialog } = require('electron');
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

// ===== Auto-updater (only in packaged apps) =====
try{
  const { autoUpdater } = require('electron-updater');
  // Use electron-log for updater logs if available
  try{
    const log = require('electron-log');
    autoUpdater.logger = log;
    if(log && log.transports && log.transports.file){
      log.transports.file.level = 'info';
    }
  }catch(_){ /* optional */ }
  function setupAutoUpdater(){
    // Guard: only run in packaged app context
    if(!app.isPackaged) return;
    // macOS/Windows cross-platform: default GitHub provider via electron-builder publish config
    autoUpdater.autoDownload = true;
    autoUpdater.on('error', (err)=>{
      // Non-fatal: log, optional dialog in debug builds
      // console.error('AutoUpdater error:', err);
    });
    autoUpdater.on('update-available', ()=>{
      // Optionally inform user; we keep silent and download automatically
    });
    autoUpdater.on('update-downloaded', async (info)=>{
      const res = await dialog.showMessageBox({
        type: 'question',
        buttons: ['Restart and Update', 'Later'],
        defaultId: 0,
        cancelId: 1,
        message: 'An update has been downloaded.',
        detail: 'Restart now to apply the update?'
      });
      if(res.response === 0){ autoUpdater.quitAndInstall(); }
    });
    // Check on startup, then optionally periodically (e.g., every 6 hours)
    autoUpdater.checkForUpdatesAndNotify().catch(()=>{});
    // setInterval(()=> autoUpdater.checkForUpdates().catch(()=>{}), 6 * 60 * 60 * 1000);
  }
  app.on('ready', setupAutoUpdater);
}catch(_){ /* electron-updater not installed in dev */ }

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