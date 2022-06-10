import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:ur_registry_flutter/native_object.dart';
import 'package:ur_registry_flutter/ur_decoder.dart';

abstract class _State {}

class _InitialState extends _State {}

typedef SuccessCallback = void Function(NativeObject);
typedef FailureCallback = void Function(String);

class _Cubit extends Cubit<_State> {
  late final String target;
  final SuccessCallback onSuccess;
  final FailureCallback onFailed;
  URDecoder urDecoder = URDecoder();

  _Cubit(this.target, this.onSuccess, this.onFailed) : super(_InitialState());

  void receiveQRCode(String? code) {
    try {
      if (code != null) {
        urDecoder.receive(code);
        if (urDecoder.isComplete()) {
          final result = urDecoder.resolve(target);
          onSuccess(result);
        }
      }
    } catch (e) {
      onFailed("Error when receiving UR $e");
      reset();
    }
  }

  void reset() {
    urDecoder = URDecoder();
  }
}

class AnimatedQRScanner extends StatelessWidget {
  final String target;
  final SuccessCallback onSuccess;
  final FailureCallback onFailed;

  const AnimatedQRScanner({Key? key,
    required this.target,
    required this.onSuccess,
    required this.onFailed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => _Cubit(target, onSuccess, onFailed),
      child: _AnimatedQRScanner(),
    );
  }
}

class _AnimatedQRScanner extends StatefulWidget {
  @override
  _AnimatedQRScannerState createState() => _AnimatedQRScannerState();
}

class _AnimatedQRScannerState extends State<_AnimatedQRScanner> {
  final GlobalKey<State<StatefulWidget>> keyQr = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  late final _Cubit _cubit;

  @override
  void initState() {
    _cubit = BlocProvider.of(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return QRView(key: keyQr, onQRViewCreated: onQRViewCreated);
  }

  Future<void> onQRViewCreated(QRViewController controller) async {
    setState(() => this.controller = controller);
    // The reassemble function call is needed because of the black screen error
    // https://github.com/juliuscanute/qr_code_scanner/issues/538#issuecomment-1133883828
    // https://github.com/juliuscanute/qr_code_scanner/issues/548
    reassemble();
    try {
      final Barcode code = await controller.scannedDataStream.first;
      _cubit.receiveQRCode(code.code);
      await this.controller!.pauseCamera();
      Navigator.pop(context, code.code);
    } catch (e) {
      _cubit.onFailed("Error when receiving UR: $e");
      _cubit.reset();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
