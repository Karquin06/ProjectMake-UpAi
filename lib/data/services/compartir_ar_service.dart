import 'package:share_plus/share_plus.dart';
import '../../models/captura_ar.dart';

class CompartirArService {
  Future<void> compartir(CapturaAr captura) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(captura.ruta, mimeType: 'image/png')],
        text: captura.producto,
      ),
    );
  }
}
