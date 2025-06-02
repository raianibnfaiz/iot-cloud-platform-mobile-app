import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return PopupMenuButton<String>(
          icon: Icon(
            themeProvider.useSystemTheme
                ? Icons.brightness_auto
                : themeProvider.isDarkMode
                ? Icons.dark_mode
                : Icons.light_mode,
          ),
          onSelected: (String value) {
            switch (value) {
              case 'system':
                themeProvider.setUseSystemTheme(true);
                break;
              case 'light':
                themeProvider.setUseSystemTheme(false);
                themeProvider.setThemeMode(false);
                break;
              case 'dark':
                themeProvider.setUseSystemTheme(false);
                themeProvider.setThemeMode(true);
                break;
            }
          },
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'system',
                  child: ListTile(
                    leading: const Icon(Icons.brightness_auto),
                    title: const Text('System'),
                    selected: themeProvider.useSystemTheme,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'light',
                  child: ListTile(
                    leading: const Icon(Icons.light_mode),
                    title: const Text('Light'),
                    selected:
                        !themeProvider.useSystemTheme &&
                        !themeProvider.isDarkMode,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'dark',
                  child: ListTile(
                    leading: const Icon(Icons.dark_mode),
                    title: const Text('Dark'),
                    selected:
                        !themeProvider.useSystemTheme &&
                        themeProvider.isDarkMode,
                  ),
                ),
              ],
        );
      },
    );
  }
}
