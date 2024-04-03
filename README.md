# ClipboardManager

ClipboardManager is a macOS clipboard manager that helps users track and manage their clipboard history. Built with SwiftUI and CoreData, it offers a simple interface for macOS that allows users to quickly access previous clipboard items with persistent storage for long-term access.

## Features

- **Clipboard Monitoring**: Keeps a running history of items copied to the clipboard, with the main clipboard menu limited to the most recent 20 items for quick access.
- **Favorites**: Users can mark items as favourites for unlimited, quick access. Favourites are not limited in number and persist across app restarts thanks to CoreData integration.
- **Status Bar Integration**: Easily accessible from the macOS status bar with an intuitive interface.

## How to Use

Once the app is running, it sits in the status bar. Click the icon to view your clipboard history and manage your items.

### Marking and Unmarking Favorites

- To add an item to favourites or remove an item from favourites, hold the Option key while clicking on the item. This allows you to quickly manage your favourite items without navigating through menus.

### Copy Item to Clipboard

- Simply click on an item to copy it back to the clipboard.

## Requirements

- macOS (version 10.15 or later)

## Installation

- Clone the repository or download the app directly from GitHub.

## Development

This app was developed using SwiftUI for the interface and CoreData for persistent storage, ensuring that your clipboard history and favourite items are retained across app launches. The core functionalities include:

- Monitoring clipboard changes and automatically updating the menu.
- Using CoreData for persistent storage of clipboard items and favourites.
- Status bar menu for immediate access, with special functions activated by the Option key.

## Contributing

Feel free to fork the project, submit issues, and send pull requests to contribute to the development of ClipboardManager.

## License

This project is available under the MIT License. See the LICENSE file for more info.
