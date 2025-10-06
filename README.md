# FLEx XML Viewer

FLEx XML Viewer is a versatile tool for viewing and interacting with XML data, specifically designed for linguistic data from FieldWorks Language Explorer (FLEx). This application is available both as an online web page and as a standalone Windows application.

## Features
- **Web Version**: Accessible online via GitHub Pages at [FLEx XML Viewer](https://rulingAnts.github.io/flexml_display).
- **Standalone App**: Build and run as a native Windows application using Electron.
- **XML Parsing**: Upload or paste XML files to view their structure and content.
- **Interactive Viewer**: Toggle element names, expand/collapse nodes, and explore XML data in various modes (List, Phonology, Generic).
- **Export Options**: Save the rendered content as an HTML file or open it in a new window.

## Online Web Page
The online version of FLEx XML Viewer is hosted on GitHub Pages. You can access it directly at:

[https://rulingAnts.github.io/flexml_display](https://rulingAnts.github.io/flexml_display)

## Standalone Windows App
The standalone version is built using Electron, allowing you to run the app natively on Windows.

### Installation
1. Clone this repository:
   ```bash
   git clone https://github.com/rulingAnts/flexml_display.git
   ```
2. Navigate to the project directory:
   ```bash
   cd flexml_display
   ```
3. Install dependencies:
   ```bash
   npm install
   ```

### Running the App
To start the app in development mode:
```bash
npm start
```

### Building the App
To build the app as a standalone executable:
1. Install `electron-packager` globally if not already installed:
   ```bash
   npm install -g electron-packager
   ```
2. Run the following command to package the app:
   ```bash
   electron-packager . flexml_display --platform=win32 --arch=x64 --out=dist --overwrite
   ```
3. The packaged app will be available in the `dist` folder.

## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests to improve the app.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.