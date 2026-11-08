import 'dart:io';

import 'package:flutter/widgets.dart';

/// Картинка аватара: встроенный ресурс (`assets/...`) или файл, выбранный пользователем.
ImageProvider avatarProvider(String path) => path.startsWith('assets/') ? AssetImage(path) : FileImage(File(path));

/// Аватар, загруженный пользователем (файл на телефоне), а не встроенный ресурс
bool isCustomAvatar(String path) => !path.startsWith('assets/');
