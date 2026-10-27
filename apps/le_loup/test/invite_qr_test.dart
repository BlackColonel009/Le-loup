import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:le_loup/joining/invite_qr_card.dart';
import 'package:le_loup/joining/scan_invitation_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(960, 500)]) {
    testWidgets('QR du MDJ lisible et changement d’interface à $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InviteQrCard(
                addresses: ['10.0.0.1:8080', '192.168.1.12:8080'],
                code: '001234',
              ),
            ),
          ),
        ),
      );
      var qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(
        LocalInvitation.parse((qr.key! as ValueKey<String>).value).address,
        '192.168.1.12:8080',
      );
      expect(qr.backgroundColor, Colors.white);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10.0.0.1:8080').last);
      await tester.pumpAndSettle();
      qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(
        LocalInvitation.parse((qr.key! as ValueKey<String>).value).address,
        '10.0.0.1:8080',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Pas de faux QR lorsque le MDJ n’a pas d’adresse Wi-Fi', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InviteQrCard(addresses: [], code: '123456'),
        ),
      ),
    );
    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.text('Connecte le MDJ au Wi-Fi pour afficher le QR code du salon.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'Windows : lien collé validé puis transmis une seule fois',
    (tester) async {
      String clipboard = 'https://example.com';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') return {'text': clipboard};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      LocalInvitation? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.push<LocalInvitation>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanInvitationScreen(),
                    ),
                  );
                },
                child: const Text('Scanner'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Scanner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coller le lien du salon'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ce QR code n’est pas une invitation Le Loup.'),
        findsOneWidget,
      );
      expect(result, isNull);
      clipboard = LocalInvitation(
        address: '192.168.1.12:8080',
        code: '001234',
      ).payload;
      await tester.tap(find.text('Coller le lien du salon'));
      await tester.pumpAndSettle();
      expect(result?.address, '192.168.1.12:8080');
      expect(result?.code, '001234');
      expect(find.byType(ScanInvitationScreen), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
