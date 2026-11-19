import 'package:beauty_salons/core/services/portfolio_store.dart';

/// Файлы портфолио без диска: размеры задаются в тесте, копии и удаления запоминаются
class FakeFiles implements PortfolioFiles {
  final Map<String, int> sizes = {'photo.jpg': 1024};
  final List<String> deleted = [];
  var cleared = false;
  var _n = 0;

  @override
  Future<int?> sizeOf(String path) async => sizes[path];

  @override
  Future<String> copyIn(String sourcePath) async {
    final target = '/app/portfolio/copy_${_n++}.jpg';
    sizes[target] = sizes[sourcePath]!;
    return target;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<void> deleteAll() async => cleared = true;
}
