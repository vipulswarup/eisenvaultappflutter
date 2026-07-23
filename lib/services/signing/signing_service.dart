import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/models/signing/signing_session.dart';

abstract class SigningService {
  Future<SigningSession> startSigning({
    required BrowseItem document,
    required String repositoryBaseUrl,
    required String returnUrl,
  });

  Future<SigningSessionStatus> getStatus(String sessionId);

  Future<void> cancelSigning(String sessionId);
}
